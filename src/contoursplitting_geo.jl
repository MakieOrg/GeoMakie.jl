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

# Split each band polygon at the clip's discontinuity, replicating its colour onto every
# resulting piece. `polys`/`colors` are parallel vectors from the `contourf` recipe.
function _split_polys_colors(polys, colors, clip::SphereClip)
    newpolys = GeometryBasics.Polygon{2,Float32}[]
    newcolors = eltype(colors)[]
    for (poly, col) in zip(polys, colors)
        clipped = clip_fill(clip, _poly_rings(poly))
        densified = [_densify_ring_sphere(r, 1.0) for r in clipped]
        for np in _rings_to_polygons(densified)
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
        return _split_polys_colors(polys, colors, clip)
    end

    child = _find_child(plot, Makie.Poly)
    if child !== nothing
        _drop_child!(axis.scene, plot, child)
        Makie.poly!(
            plot, plot.split_polys;
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
