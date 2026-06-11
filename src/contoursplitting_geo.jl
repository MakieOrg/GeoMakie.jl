#=
# Seam-aware filled contours on a `GeoAxis`

`contourf` builds filled-band polygons in lon/lat; on a projection with a discontinuity
those bands smear across the tear. We intercept the recipe: split each band polygon on the
sphere via [`clip_fill`](@ref) (chosen by [`clip_strategy`](@ref)), then swap the child
`Poly` to draw the split polygons. Output stays in lon/lat, so the child still projects
per-vertex through the GeoAxis transform.
=#

# First child plot of `plot` that is a `T` (the atomic plot the recipe built).
function _find_child(plot, ::Type{T}) where {T}
    i = findfirst(p -> p isa T, plot.plots)
    return i === nothing ? nothing : plot.plots[i]
end

function _drop_child!(scene, plot, child)
    delete!(scene, child)
    i = findfirst(==(child), plot.plots)
    i === nothing || deleteat!(plot.plots, i)
    return
end

# Split each band polygon at the clip's discontinuity (full d3 pipeline: rotate → clip →
# resample), replicating its colour onto every resulting piece. `polys`/`colors` are parallel
# vectors from the `contourf` recipe; `project`/`scale` drive the adaptive resampler.
function _split_polys_colors(polys, colors, clip::SphereClip, project, scale; rotated::Bool = false)
    newpolys = GeometryBasics.Polygon{2,Float32}[]
    newcolors = eltype(colors)[]
    for (poly, col) in zip(polys, colors)
        for np in _split_polygon(clip, _poly_rings(poly), project, scale; rotated = rotated)
            push!(newpolys, np); push!(newcolors, col)
        end
    end
    return (newpolys, newcolors)
end

function Makie.plot!(axis::GeoAxis, plot::Makie.Contourf)
    # mirror the generic GeoAxis transform injection (geoaxis.jl `plot!(::GeoAxis, ::AbstractPlot)`)
    source = pop!(plot.kw, :source, axis.source)
    transformfunc = lift(create_transform, axis.dest, source)
    if !Makie.not_in_data_space(plot)
        plot.kw[:transformation] = Makie.Transformation(transformfunc; get(plot.kw, :transformation, Attributes())...)
    end
    reset_limits = to_value(pop!(plot.kw, :reset_limits, true))

    Makie.plot!(axis.scene, plot)   # run the contourf recipe → builds the child Poly

    Makie.register_computation!(
        plot.attributes,
        [:polys, :computed_colors, :transform_func],
        [:split_polys, :split_colors],
    ) do (polys, colors, tfunc), changed, cached
        clip = clip_strategy(tfunc)
        clip isa NoClip && return (polys, colors)
        if clip isa AntimeridianClip
            # Option B: clip/resample in the rotated canonical frame and draw with the
            # centred projector (lon_0=0); avoids PROJ's half-open longitude-wrap collapsing
            # the seam onto one map edge (the moll +lon_0=180 bug).
            ctf = create_transform(_centred_dest(to_value(axis.dest)), to_value(source))
            project = _projector(ctf); scale = resample_scale(project)
            return _split_polys_colors(polys, colors, clip, project, scale; rotated = true)
        else
            project = _projector(tfunc); scale = resample_scale(project)
            return _split_polys_colors(polys, colors, clip, project, scale; rotated = false)
        end
    end

    # the split child must draw in the SAME frame the split polys were emitted in: centred
    # transform for the antimeridian (rotated frame), full transform otherwise. Decide inside
    # one lift so the geometry frame and the transform switch atomically when `dest` changes.
    childfunc = lift(axis.dest, source) do dest, src
        ftf = create_transform(dest, src)
        clip_strategy(ftf) isa AntimeridianClip ? create_transform(_centred_dest(dest), src) : ftf
    end

    child = _find_child(plot, Makie.Poly)
    if child !== nothing
        _drop_child!(axis.scene, plot, child)
        Makie.poly!(
            plot, plot.split_polys;
            transformation = Makie.Transformation(childfunc),
            colormap = plot.computed_colormap,
            colorrange = plot.computed_colorrange,
            highclip = plot.computed_highcolor,
            lowclip = plot.computed_lowcolor,
            nan_color = plot.nan_color,
            color = plot.split_colors,
            strokewidth = 0,
            strokecolor = :transparent,
            shading = Makie.NoShading,
            inspectable = plot.inspectable,
            transparency = plot.transparency,
        )
    end

    if reset_limits
        Makie.needs_tight_limits(plot) && Makie.tightlimits!(axis)
        Makie.is_open_or_any_parent(axis.scene) && Makie.reset_limits!(axis)
    end
    return plot
end

# The transform the split child must draw with: centred (lon_0=0) for the antimeridian seam
# (Option B — geometry is emitted in the rotated frame), the full transform otherwise.
function _child_transformfunc(axis, source)
    lift(axis.dest, source) do dest, src
        ftf = create_transform(dest, src)
        clip_strategy(ftf) isa AntimeridianClip ? create_transform(_centred_dest(dest), src) : ftf
    end
end

# Split a vector of polygons at the destination discontinuity in the correct frame, returning
# the split polygons and a `group` vector mapping each output piece back to its input polygon
# (so per-polygon colours can be replicated). Mirrors the contourf path for `poly!`/`land`.
function _split_geom(geom, dest, source)
    ftf = create_transform(dest, source); clip = clip_strategy(ftf)
    polys = GeometryBasics.Polygon{2,Float32}[]; group = Int[]
    clip isa NoClip && (for (k, p) in enumerate(_collect_polys(geom)); push!(polys, p); push!(group, k); end; return (polys, group))
    rotated = clip isa AntimeridianClip
    project = _projector(rotated ? create_transform(_centred_dest(dest), source) : ftf)
    scale = resample_scale(project)
    for (k, p) in enumerate(_collect_polys(geom))
        pieces = _split_polygon(clip, _poly_rings(p), project, scale; rotated = rotated)
        append!(polys, pieces); append!(group, fill(k, length(pieces)))
    end
    return (polys, group)
end

# Seam-aware polygon fills: `poly!(ga, geometry)` clips/splits the geometry on the sphere and
# draws it in the matching frame, so land/coastline fills don't smear across the tear (and stay
# correct at lon_0 = 180 via Option B). Per-polygon colour vectors are replicated onto pieces.
function Makie.plot!(axis::GeoAxis, plot::Makie.Poly{<:Tuple{<:AbstractVector{<:GeometryBasics.Polygon}}})
    source = pop!(plot.kw, :source, axis.source)
    reset_limits = to_value(pop!(plot.kw, :reset_limits, true))
    # Connect the original plot so its cycle colour / palette resolves from the scene (e.g.
    # `poly!(ga, geom)` with no explicit colour), but hide its unsplit drawing — the split
    # geometry is rendered separately below.
    Makie.plot!(axis.scene, plot); plot.visible = false
    split = lift(_split_geom, plot[1], axis.dest, source)
    splitpolys = lift(first, split)
    splitcolor = lift(plot.color, split) do col, s
        (col isa AbstractVector && length(col) == maximum(s[2]; init = 0)) ? col[s[2]] : col
    end
    # draw the split geometry straight into the axis scene with the matching (centred/full)
    # transform; the original `plot` stays an unrealised handle (returned to the caller).
    Makie.poly!(
        axis.scene, splitpolys;
        color = splitcolor,
        colormap = plot.colormap,
        colorrange = plot.colorrange,
        strokecolor = plot.strokecolor,
        strokewidth = plot.strokewidth,
        transparency = plot.transparency,
        transformation = Makie.Transformation(_child_transformfunc(axis, source)),
    )
    reset_limits && Makie.is_open_or_any_parent(axis.scene) && Makie.reset_limits!(axis)
    return plot
end

# Seam-aware line contours: run the `contour` recipe, then swap its `Lines` child for the
# clipped/resampled version (drawn in the matching centred/full frame).
function Makie.plot!(axis::GeoAxis, plot::Makie.Contour)
    source = pop!(plot.kw, :source, axis.source)
    reset_limits = to_value(pop!(plot.kw, :reset_limits, true))
    plot.kw[:transformation] = Makie.Transformation(lift(create_transform, axis.dest, source))
    Makie.plot!(axis.scene, plot)        # contour recipe → Text (labels) + Lines

    child = _find_child(plot, Makie.Lines)
    if child !== nothing
        splitpts = lift(child[1], axis.dest, source) do pts, dest, src
            ftf = create_transform(dest, src); clip = clip_strategy(ftf)
            rotated = clip isa AntimeridianClip
            project = _projector(rotated ? create_transform(_centred_dest(dest), src) : ftf)
            split_resample_line(pts, ftf; project = project, rotated = rotated)
        end
        col = lift(c -> c isa AbstractVector ? :black : c, child.color)   # per-vertex colour can't survive resampling
        _drop_child!(axis.scene, plot, child)
        Makie.lines!(
            plot, splitpts;
            color = col,
            linewidth = child.linewidth,
            linestyle = child.linestyle,
            transparency = plot.transparency,
            transformation = Makie.Transformation(_child_transformfunc(axis, source)),
        )
    end
    reset_limits && Makie.is_open_or_any_parent(axis.scene) && Makie.reset_limits!(axis)
    return plot
end

# Seam-aware polylines: `lines!(ga, points_or_geometry)` clips/resamples the line on the sphere
# and draws it in the matching frame, so coastlines/contour lines don't shoot across the tear
# (and stay correct at lon_0 = 180 via Option B).
function Makie.plot!(axis::GeoAxis, plot::Makie.Lines{<:Tuple{<:AbstractVector{<:Point2}}})
    source = pop!(plot.kw, :source, axis.source)
    reset_limits = to_value(pop!(plot.kw, :reset_limits, true))
    # connect so cycle colour/palette resolves from the scene, but hide the unsplit drawing
    Makie.plot!(axis.scene, plot); plot.visible = false
    splitpts = lift(plot[1], axis.dest, source) do pts, dest, src
        ftf = create_transform(dest, src); clip = clip_strategy(ftf)
        rotated = clip isa AntimeridianClip
        project = _projector(rotated ? create_transform(_centred_dest(dest), src) : ftf)
        split_resample_line(pts, ftf; project = project, rotated = rotated)
    end
    Makie.lines!(
        axis.scene, splitpts;
        color = plot.color,
        colormap = plot.colormap,
        colorrange = plot.colorrange,
        linewidth = plot.linewidth,
        linestyle = plot.linestyle,
        transparency = plot.transparency,
        transformation = Makie.Transformation(_child_transformfunc(axis, source)),
    )
    reset_limits && Makie.is_open_or_any_parent(axis.scene) && Makie.reset_limits!(axis)
    return plot
end

# Build a projected, discontinuity-clipped triangle mesh from a rectilinear lon/lat grid
# (`xs`, `ys` vectors) with per-vertex values `vals`. The grid is projected (Option B — rotated
# frame + centred projector — for the antimeridian, so lon_0=180 doesn't collapse), triangulated,
# and faces straddling the tear are dropped (`_visible_faces`). Returns (mesh, flat colour vector).
function _geo_grid_mesh(dest, source, xs, ys, vals)
    ftf = create_transform(dest, source); clip = clip_strategy(ftf)
    rotated = clip isa AntimeridianClip
    tf = rotated ? create_transform(_centred_dest(dest), source) : ftf
    lon0 = rotated ? clip.lon0 : 0.0
    # heatmap passes cell EDGES (n+1) with per-cell data (n); use centres so the vertex grid
    # matches `vals`. surface passes coordinate vectors matching `vals` already.
    nx = size(vals, 1); ny = size(vals, 2)
    xs = length(xs) == nx + 1 ? [(xs[i] + xs[i+1]) / 2 for i in 1:nx] : xs
    ys = length(ys) == ny + 1 ? [(ys[j] + ys[j+1]) / 2 for j in 1:ny] : ys
    points = Vector{Point3d}(undef, nx * ny)
    latlon = Vector{Point2d}(undef, nx * ny)
    cols = Vector{Float64}(undef, nx * ny)
    for (k, ci) in enumerate(CartesianIndices((nx, ny)))
        lo = Float64(xs[ci[1]]); la = Float64(ys[ci[2]])
        rotated && (lo = mod(lo - lon0 + 180.0, 360.0) - 180.0)   # canonical rotated frame
        latlon[k] = Point2d(lo, la)
        points[k] = Makie.to_ndim(Point3d, Makie.apply_transform(tf, Point3d(lo, la, 0.0)), 0.0)
        cols[k] = Float64(vals[ci[1], ci[2]])
    end
    rect = GeometryBasics.Tesselation(Rect2f(0, 0, 1, 1), (nx, ny))
    faces = GeometryBasics.decompose(Makie.GLTriangleFace, rect)
    # clip faces at the discontinuity (subdivides toward the seam); interpolate colour onto the
    # inserted midpoint vertices so the mesh fills to the boundary instead of leaving a sliver.
    pts, _, faces2, parents = _clip_faces(points, latlon, faces, _mesh_projector(tf, 0.0))
    for k in (nx*ny+1):length(pts)
        a, b = parents[k]; push!(cols, (cols[a] + cols[b]) / 2)
    end
    return (GeometryBasics.Mesh(pts, faces2), cols)
end

# `surface!`/`heatmap!` on a GeoAxis: project the rectilinear lon/lat grid to a seam-clipped mesh
# (Option B for the antimeridian) and draw it with the data as per-vertex colour. Heatmap can't
# render curvilinear cells natively; surface projects but smears/collapses without this.
function _geo_grid_plot!(axis, plot, vals_node)
    source = pop!(plot.kw, :source, axis.source)
    reset_limits = to_value(pop!(plot.kw, :reset_limits, true))
    mc = lift(plot[1], plot[2], vals_node, axis.dest, source) do xs, ys, vals, dest, src
        _geo_grid_mesh(dest, src, xs, ys, vals)
    end
    Makie.mesh!(
        axis.scene, lift(first, mc);
        color = lift(last, mc),
        colormap = plot.colormap,
        colorrange = plot.colorrange,
        nan_color = plot.nan_color,
        shading = Makie.NoShading,
        transparency = plot.transparency,
    )
    if reset_limits
        Makie.needs_tight_limits(plot) && (axis.xautolimitmargin = (0.01, 0.01); axis.yautolimitmargin = (0.01, 0.01))
        Makie.is_open_or_any_parent(axis.scene) && Makie.reset_limits!(axis)
    end
    return plot
end

function Makie.plot!(axis::GeoAxis, plot::Makie.Surface)
    vals = lift(plot[3], plot.color) do zs, col
        (col isa AbstractMatrix && size(col) == size(zs)) ? col : zs
    end
    return _geo_grid_plot!(axis, plot, vals)
end

Makie.plot!(axis::GeoAxis, plot::Makie.Heatmap) = _geo_grid_plot!(axis, plot, plot[3])
