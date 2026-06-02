#=
# Antimeridian-aware `contour` / `contourf` on a `GeoAxis`

`contour!`/`contourf!` compute their geometry in lon/lat (data) space and
then the `GeoAxis` applies the `Proj` transform *per vertex*.  When a
contour ring or line crosses the antimeridian of the destination
projection (the meridian at `lon_0 ± 180`), an edge whose two endpoints
sit on opposite sides of the globe is projected into a horizontal smear
across the whole canvas.

The fix splits the contour *output* geometry at the seam, still in lon/lat
space, before the per-vertex projection runs.  Pipeline:

    contour in lon/lat  ->  split at lon_0 ± 180 (lon/lat)  ->  project last

## How the hook works (no method overwriting)

Makie's `contourf`/`contour` recipes build a child `Poly`/`Lines` plot whose
data-space input is fed from the recipe's `:polys` / `:masked_lines`
compute node.  We must not re-define Makie's `plot!(::Contourf)` recipe —
on Julia ≥ 1.12 redefining a method another module owns is a fatal
"method overwriting during precompilation" error (which is exactly what
the original prototype of this file hit).

Instead we add a *new, more specific* method to a dispatch GeoMakie
already owns — `Makie.plot!(::GeoAxis, ::Contourf)` / `::Contour`.  After
the standard recipe has built its child plot, we

  1. register a split computation on the parent plot's graph
     (`[:polys, :computed_colors, :transform_func] -> [:split_polys, :split_colors]`,
     and the line analogue), which is a no-op unless `transform_func` is a
     `Proj.Transformation`; and
  2. replace the recipe's child plot with one reading the split node.

Because the split node depends on the recipe's own `:polys`/`:masked_lines`
and on `:transform_func`, it stays fully reactive to `levels`/projection
changes.  On a plain `Axis` (or any non-`Proj` transform) the split is a
pass-through, so behaviour is identical to upstream Makie.
=#

import Proj

# Pull `+lon_0` out of a `Proj.Transformation`'s definition string.
# Returns `nothing` for anything that isn't a `Proj.Transformation` — the
# split nodes use that as the "don't split" signal.
function _antimeridian_lon0(t::Proj.Transformation)
    info = Proj.proj_pj_info(t.pj)
    info.definition == C_NULL && return 0.0
    return parse_lon0(unsafe_string(info.definition))
end
_antimeridian_lon0(_) = nothing

# First child plot of `plot` that is a `T` (the atomic plot built by the recipe).
function _find_child(plot, ::Type{T}) where {T}
    i = findfirst(p -> p isa T, plot.plots)
    return i === nothing ? nothing : plot.plots[i]
end

# Remove `child` (a recipe-built atomic plot) and drop it from `plot.plots`.
function _drop_child!(scene, plot, child)
    delete!(scene, child)
    i = findfirst(==(child), plot.plots)
    i === nothing || deleteat!(plot.plots, i)
    return
end

# ---------------------------------------------------------------------------
# Filled contours
# ---------------------------------------------------------------------------
function Makie.plot!(axis::GeoAxis, plot::Makie.Contourf)
    _geoaxis_plot!(axis, plot)

    Makie.register_computation!(
        plot.attributes,
        [:polys, :computed_colors, :transform_func],
        [:split_polys, :split_colors],
    ) do (polys, colors, tfunc), changed, cached
        lon0 = _antimeridian_lon0(tfunc)
        lon0 === nothing && return (polys, colors)
        return split_polys_and_colors(polys, colors, lon0)
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

    return plot
end

# ---------------------------------------------------------------------------
# Line contours
# ---------------------------------------------------------------------------
function Makie.plot!(axis::GeoAxis, plot::Makie.Contour)
    _geoaxis_plot!(axis, plot)

    # `:masked_lines` is the NaN-separated point vector actually drawn by the
    # recipe's `lines!` child (== `:contour_points` when labels are off, with
    # extra NaNs punched where labels sit).  `:contour_colors` is parallel to it.
    Makie.register_computation!(
        plot.attributes,
        [:masked_lines, :contour_colors, :transform_func],
        [:split_lines, :split_line_colors],
    ) do (lines, colors, tfunc), changed, cached
        lon0 = _antimeridian_lon0(tfunc)
        lon0 === nothing && return (lines, colors)
        return split_linestring_points(lines, colors, lon0)
    end

    child = _find_child(plot, Makie.Lines)
    if child !== nothing
        _drop_child!(axis.scene, plot, child)
        Makie.lines!(
            plot, plot.split_lines;
            color = plot.split_line_colors,
            linewidth = plot.linewidth,
            linestyle = plot.linestyle,
            linecap = plot.linecap,
            joinstyle = plot.joinstyle,
            miter_limit = plot.miter_limit,
            visible = plot.visible,
            transparency = plot.transparency,
            overdraw = plot.overdraw,
            inspectable = plot.inspectable,
            depth_shift = plot.depth_shift,
            space = plot.space,
        )
    end

    return plot
end
