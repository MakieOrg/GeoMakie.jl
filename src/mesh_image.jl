#=
# MeshImage

This file contains the implementation of the `MeshImage` recipe.
=#

using Makie: GeometryBasics

"""
    meshimage([xs, ys,] img)
    meshimage!(ax, [xs, ys,] img)

Plots an image on a mesh.

Useful for nonlinear transforms where a large
image would take too long to transform usefully,
but a smaller mesh can still represent the inherent
nonlinearity of the space.

This basically plots a mesh with uv coordinates, and textures it by
the provided image.  Its conversion trait is `ImageLike`.

!!! tip
    You can control the density of the mesh by the `npoints` attribute.

"""
@recipe MeshImage (x, y, img) begin
    """
    The number of points the mesh should have per side.  
    Can be an Integer or a 2-tuple of integers representing number of points per side.
    """
    npoints = 100
    "The z-coordinate given to each mesh point.  Useful in 3D transformations."
    z_level = 0.0
    "Sets the lighting algorithm used. Options are `NoShading` (no lighting), `FastShading` (AmbientLight + PointLight) or `MultiLightShading` (Multiple lights, GLMakie only). Note that this does not affect RPRMakie."
    shading = NoShading
    """
    Sets a transform for uv coordinates, which controls how the image is mapped to its rectangular area. The attribute can be `I`,
    `scale::VecTypes{2}`, `(translation::VecTypes{2}, scale::VecTypes{2})`, any of `:rotr90`, `:rotl90`, `:rot180`, `:swapxy`/`:transpose`, `:flip_x`, `:flip_y`, `:flip_xy`, or
    most generally a `Makie.Mat{2, 3, Float32}` or `Makie.Mat3f` as returned by `Makie.uv_transform()`. They can also be changed by passing a tuple `(op3, op2,
    op1)`.
    """
    uv_transform = Makie.LinearAlgebra.I
    mixin_generic_plot_attributes()...
    mixin_colormap_attributes()...
end

# this inherits all conversions for `Image`,
# if no specialized conversion for `MeshImage` is found.
Makie.conversion_trait(::Type{<: MeshImage}) = Makie.ImageLike()
# There really is no difference between this and Image, 
# except the implementation under the hood.

# We also define that `meshimage` needs tight limits when plotted...
Makie.needs_tight_limits(::MeshImage) = true

# This is the recipe implementation.

# Great-circle midpoint of a lon/lat edge (degrees).
function _gc_midpoint(lo1, la1, lo2, la2)
    x1 = cosd(la1) * cosd(lo1); y1 = cosd(la1) * sind(lo1); z1 = sind(la1)
    x2 = cosd(la2) * cosd(lo2); y2 = cosd(la2) * sind(lo2); z2 = sind(la2)
    mx = x1 + x2; my = y1 + y2; mz = z1 + z2; n = sqrt(mx^2 + my^2 + mz^2)
    n < 1.0e-12 && return ((lo1 + lo2) / 2, (la1 + la2) / 2)
    return (atand(my, mx), asind(clamp(mz / n, -1.0, 1.0)))
end

# Clip mesh faces at the projection's discontinuity. An edge "crosses" a tear if projecting its
# great-circle midpoint lands far from the midpoint of the two projected endpoints — this tells a
# real tear (antimeridian / horizon / interrupted lobe / oblique seam) from mere projection
# distortion (which keeps them close), regardless of edge length. A straddling triangle is
# SUBDIVIDED toward the seam (keep the clean sub-triangles, recurse on the rest up to `depth`)
# rather than dropped, so only a sub-pixel remnant is lost instead of a whole-cell sliver.
#
# `points`/`latlon` are the projected points and their parallel lon/lat. Returns
# `(points′, latlon′, faces′, parents)`: `points′`/`latlon′` are the originals plus the inserted
# edge-midpoint vertices; `parents[k] = (a, b)` says new vertex `k` is the midpoint of `a, b`
# (originals have `(0, 0)`), so callers can interpolate UVs/colours for the new vertices.
function _clip_faces(points, latlon, faces, proj; factor = 0.3, depth = 4)
    _fin(p) = isfinite(p[1]) && isfinite(p[2])
    pts = collect(Point3d, points)
    ll = collect(Point2d, latlon)
    parents = Tuple{Int,Int}[(0, 0) for _ in eachindex(points)]
    midcache = Dict{Tuple{Int,Int},Int}()
    function mid(a, b)
        key = a < b ? (a, b) : (b, a)
        haskey(midcache, key) && return midcache[key]
        la = ll[a]; lb = ll[b]
        m = _gc_midpoint(la[1], la[2], lb[1], lb[2])
        pm = proj(m[1], m[2])
        push!(ll, Point2d(m[1], m[2])); push!(pts, Point3d(pm[1], pm[2], 0.0)); push!(parents, (a, b))
        idx = length(pts); midcache[key] = idx; return idx
    end
    # Projected extent, so most edges can be decided from the ALREADY-projected vertices and skip
    # an extra midpoint projection per edge — the cost that made npoints=1000 take 5 min + 56 GiB
    # (geos→natearth curvature subdividing every face). Mirrors cartopy: detect wraps from projected
    # coords; don't forward-project every face.
    xmin = ymin = Inf; xmax = ymax = -Inf
    @inbounds for p in points
        _fin(p) || continue
        xmin = min(xmin, p[1]); xmax = max(xmax, p[1]); ymin = min(ymin, p[2]); ymax = max(ymax, p[2])
    end
    ext = (isfinite(xmin) && xmax > xmin) ? hypot(xmax - xmin, ymax - ymin) : 0.0
    seam2 = (0.5 * ext)^2        # edge spanning ≳½ the map ⇒ wraps the seam (squared ⇒ no sqrt)
    skip2 = (0.005 * ext)^2      # edge ≲0.5% of the map ⇒ sub-pixel curvature, not worth subdividing
    function crosses(a, b)
        p1 = pts[a]; p2 = pts[b]
        (_fin(p1) && _fin(p2)) || return true
        dx = p1[1] - p2[1]; dy = p1[2] - p2[2]; e2 = dx * dx + dy * dy
        e2 > seam2 && return true            # wraps the seam — from projected vertices only, no proj
        e2 < skip2 && return false           # too short to show curvature — skip the projection
        la = ll[a]; lb = ll[b]
        m = _gc_midpoint(la[1], la[2], lb[1], lb[2]); pm = proj(m[1], m[2])
        _fin(pm) || return true
        ex = (p1[1] + p2[1]) / 2; ey = (p1[2] + p2[2]) / 2
        return hypot(pm[1] - ex, pm[2] - ey) > factor * sqrt(e2) + 1.0e-9
    end
    out = eltype(faces)[]
    function emit(a, b, c, d)
        # Fully off-map face (all three vertices non-finite — e.g. the entire back hemisphere of an
        # azimuthal/perspective projection like ortho/geos): drop in O(1). Without this, every such
        # cell subdivides to `depth` (up to 4^depth sub-triangles) only to be discarded, which made a
        # dense raster `heatmap`/`surface` on a GeoAxis take minutes (≈half the grid × 256). Genuine
        # limb-straddle faces have at least one finite vertex, so they still subdivide below.
        (_fin(pts[a]) || _fin(pts[b]) || _fin(pts[c])) || return
        (crosses(a, b) || crosses(b, c) || crosses(c, a)) || (push!(out, eltype(faces)(a, b, c)); return)
        d <= 0 && return                      # sub-pixel remnant at the seam: drop
        ab = mid(a, b); bc = mid(b, c); ca = mid(c, a)
        emit(a, ab, ca, d - 1); emit(ab, b, bc, d - 1); emit(ca, bc, c, d - 1); emit(ab, bc, ca, d - 1)
    end
    @inbounds for f in faces
        emit(f[1], f[2], f[3], depth)
    end
    return pts, ll, out, parents
end

# project closure (lon,lat)->(x,y) for a Makie transform_func, error-safe
function _mesh_projector(tfunc, z)
    return function (lo, la)
        try
            p = Makie.apply_transform(tfunc, Point3d(lo, la, z))
            return (Float64(p[1]), Float64(p[2]))
        catch
            return (NaN, NaN)
        end
    end
end

function Makie.plot!(plot::MeshImage)
    # Initialize some Ref's that can hold references
    # to pre-defined arrays.
    points_buffer = Ref{Vector{Point3d}}(Point3d[])
    faces_buffer = Ref{Vector{Makie.GLTriangleFace}}(Makie.GLTriangleFace[])#=GeometryBasics.QuadFace{Int}=#
    uv_buffer = Ref{Vector{Vec2f}}(Vec2f[])

    # A sentinel so we can see if `npoints` changed.  If it did, we have to
    # recreate the mesh, which is slightly time-consuming.  If not, though,
    # then we only have to change the texture (image) which is cheaper.
    old_npoints = Ref{Tuple{Int, Int}}((0, 0))

    Makie.map!(
        plot,
        [:x, :y, :transform_func, :npoints, :space, :z_level],
        [:mesh]
    ) do x_in, y_in, tfunc, npoints, space, z_level
        # If `npoints` changed, then re-construct the buffers.
        if (first(npoints), last(npoints)) != old_npoints[]
            # We need a new StructArray to hold all the points.
            # TODO: resize the old structarray instead!
            points_buffer[] = Vector{Point3d}(undef, first(npoints) * last(npoints))
            # This constructs an efficient triangulation of a rectangle (all images are rectangles).
            rect = GeometryBasics.Tesselation(Rect2f(0, 0, 1, 1), (first(npoints), last(npoints)))
            faces_buffer[] = GeometryBasics.decompose(Makie.GLTriangleFace, rect)
            uv_buffer[] = map(x -> Vec2f(x[1], 1f0 - x[2]), GeometryBasics.decompose_uv(rect))
            old_npoints[] = (first(npoints), last(npoints))
        end
        nx, ny = old_npoints[]

        # These are the ranges for the points.
        # `first` and `last` are used to get the number of points per side, if that's provided as a tuple.
        xs = LinRange(extrema(x_in)..., nx)
        ys = LinRange(extrema(y_in)..., ny)

        points = points_buffer[]
        faces = faces_buffer[]
        uvs = uv_buffer[]

        latlon = Vector{Point2d}(undef, nx * ny)   # lon/lat parallel to `points`, for the tear test
        for (linear_ind, cartesian_ind) in enumerate(CartesianIndices((nx, ny)))
            lo = xs[cartesian_ind[1]]; la = ys[cartesian_ind[2]]
            latlon[linear_ind] = Point2d(lo, la)
            points[linear_ind] = Makie.to_ndim(
                Point3d,
                Makie.apply_transform(
                    tfunc,
                    Point3d(lo, la, z_level),
                ),
                0.0
            )
        end

        # clip faces straddling the projection discontinuity (subdivides toward the seam)
        pts, _, faces2, parents = _clip_faces(points, latlon, faces, _mesh_projector(tfunc, z_level))
        uvs2 = collect(Vec2f, uvs)
        for k in (length(uvs)+1):length(pts)            # UV for each inserted midpoint vertex
            a, b = parents[k]; push!(uvs2, (uvs2[a] + uvs2[b]) / 2)
        end
        return (GeometryBasics.Mesh(pts, faces2; uv = uvs2),)
    end

    # Finally, we plot the mesh.
    # This auto forwards all shared attributes from the compute graph.
    mesh!(
        plot, 
        plot.attributes,
        plot.mesh; 
        color = plot.img, # pass on the color directly
        transformation = Makie.Transformation(
            plot.transformation;      # connect up the model matrix to the parent's model matrix
            transform_func = identity # do NOT connect the transform func, since we've already done that.  identity provides a custom transform func, while `nothing` signals that you don't care.
        ),
    )
end

# This is an efficient implementation for data_limits,
# so that we don't have to iterate through each point of the mesh!
function Makie.data_limits(plot::MeshImage)
    mini_maxi = Makie.extrema_nan.((plot[1][], plot[2][]))
    mini = Vec3f(first.(mini_maxi)..., 0)
    maxi = Vec3f(last.(mini_maxi)..., 0)
    return Rect3f(mini, maxi .- mini)
end
# Boundingbox needs to iterate though, so it's fine to not override that.
