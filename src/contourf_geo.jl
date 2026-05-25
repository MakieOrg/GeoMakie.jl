#=
# Antimeridian-aware `contourf` for `GeoAxis`

This file overrides Makie's `Contourf` recipe so that, when the plot's
`transform_func` is a `Proj.Transformation`, the iso-band polygons are
split at the antimeridian (`lon_0 ± 180`) before they reach `poly!`.

For plots without a Proj transform (i.e. anything not on a `GeoAxis`),
the splitter is a no-op and the behaviour is identical to upstream
Makie.

The override is a type-piracy of `Makie.plot!(::Contourf{...})` with
the exact same method signature as Makie's, so it replaces Makie's
definition for these argument types.  This is the same pattern used
elsewhere in GeoMakie (see [`makie_piracy.jl`](makie_piracy.jl)).

Note: `Makie.contour` (line contours) is *not* handled here.  Line
contour line-splitting would require either pirating the whole
~300-line `Contour` recipe or rebinding a child plot's input — both
significantly more invasive than the `Contourf` case.  Coastline
splitting is still available via [`linesplitting.jl`](linesplitting.jl).
=#

import Proj

const _ContourfArgs = Union{
    <:Tuple{<:AbstractVector{<:Real}, <:AbstractVector{<:Real}, <:AbstractMatrix{<:Real}},
    <:Tuple{<:AbstractMatrix{<:Real}, <:AbstractMatrix{<:Real}, <:AbstractMatrix{<:Real}},
}

# Pull `+lon_0` out of a `Proj.Transformation`'s definition string.
# Returns `nothing` for anything that isn't a `Proj.Transformation` —
# the recipe uses that as the "don't split" signal.
function _antimeridian_lon0(t::Proj.Transformation)
    info = Proj.proj_pj_info(t.pj)
    if info.definition == C_NULL
        return 0.0
    end
    def = unsafe_string(info.definition)
    return parse_lon0(def)
end
_antimeridian_lon0(_) = nothing

function Makie.plot!(c::Makie.Contourf{<:_ContourfArgs})
    graph = c.attributes

    Makie.register_contourf_computations!(graph, :z)

    Makie.register_computation!(
        graph,
        [:x, :y, :z, :computed_levels, :extendlow, :extendhigh],
        [:polys, :computed_colors],
    ) do (xs, ys, zs, levels, _low, _high), changed, cached
        is_extended_low = !isnothing(_low)
        is_extended_high = !isnothing(_high)
        if isnothing(cached)
            polys = GeometryBasics.Polygon{2, Float32}[]
            colors = Float64[]
        else
            polys, colors = empty!.(values(cached))
        end
        Makie._calculate_polys!(polys, colors, xs, ys, zs, levels, is_extended_low, is_extended_high)
        return (polys, colors)
    end

    # Downstream split: if `transform_func` is a `Proj.Transformation`,
    # cut every polygon at the antimeridian and inherit the parent
    # colour into each piece.  Otherwise pass through.
    Makie.register_computation!(
        graph,
        [:polys, :computed_colors, :transform_func],
        [:split_polys, :split_colors],
    ) do (polys, colors, tfunc), changed, cached
        lon0 = _antimeridian_lon0(tfunc)
        if lon0 === nothing
            return (polys, colors)
        end
        return split_polys_and_colors(polys, colors, lon0)
    end

    return Makie.poly!(
        c,
        c.split_polys,
        colormap = c.computed_colormap,
        colorrange = c.computed_colorrange,
        highclip = c.computed_highcolor,
        lowclip = c.computed_lowcolor,
        nan_color = c.nan_color,
        color = c.split_colors,
        strokewidth = 0,
        strokecolor = :transparent,
        shading = Makie.NoShading,
        inspectable = c.inspectable,
        transparency = c.transparency,
    )
end
