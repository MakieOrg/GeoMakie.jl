#=
# Layout

What the axis tells the layout, per side:

    reach[side]      = tick reach (the dest-space bound, or the measured reach
                       `tight_ticklabel_spacing!` fixed) + the axis label on that side
    protrusion[side] = reach[side] + title and subtitle (top only)

The tick reach is the band, the tick stubs, and every frame label's box pushed
out along its normal (`protrusion_bound`).  An axis label sits on the side its
axis position names, outside the tick reach by its padding; its extent is
measured from the drawn text so rich text and LaTeX measure right.  The
title sits above the top reach.  Nothing here reads the viewport except the
axis-label positions, so the bound never feeds back into the layout.
=#

"""
    AxisLabel

One axis label as the layout sees it: the `side` it sits on, its `padding`
from the tick reach, and its `extent` along that side's normal in pixels (`0`
when hidden or blank).
"""
struct AxisLabel
    side::Symbol
    padding::Float64
    extent::Float64
end

"The space an axis label adds to its side: padding plus extent, nothing when it is not drawn."
label_space(l::AxisLabel) = l.extent > 0 ? l.padding + l.extent : 0.0

"The side an axis label sits on: the one its axis position names, the `Axis` default for `:both`."
function axis_label_side(family::Symbol, xaxisposition::Symbol, yaxisposition::Symbol)
    family === :lon && return xaxisposition === :top ? :top : :bottom
    return yaxisposition === :right ? :right : :left
end

"The rotation of an axis label: `automatic` is upright below or above the map and reading upward beside it."
axis_label_rotation(family::Symbol, rotation) = rotation isa Makie.Automatic ? (family === :lon ? 0.0 : pi / 2) : float(rotation)

"The value of `r` on `side`."
function side_value(r::GridLayoutBase.RectSides, side::Symbol)
    side === :left && return r.left
    side === :right && return r.right
    side === :bottom && return r.bottom
    return r.top
end

"""
    reach_sides(tick, fixed, labels) -> RectSides{Float32}

Per side, the tick reach (`fixed` when `tight_ticklabel_spacing!` measured
one, else the bound `tick`) plus the axis labels on that side.
"""
function reach_sides(tick::GridLayoutBase.RectSides, fixed, labels)
    base = fixed === nothing ? tick : fixed
    add(side) = sum((label_space(l) for l in labels if l.side === side); init = 0.0)
    return GridLayoutBase.RectSides{Float32}(base.left + add(:left), base.right + add(:right),
        base.bottom + add(:bottom), base.top + add(:top))
end

"The protrusions: the reach with the title and subtitle stacked on top."
with_title(reach::GridLayoutBase.RectSides, titlespace::Real, subtitlespace::Real) =
    GridLayoutBase.RectSides{Float32}(reach.left, reach.right, reach.bottom, reach.top + titlespace + subtitlespace)

"""
    axis_label_position(viewport, base, label) -> Point2d

The centre of an axis label in pixels: the middle of its side of the
viewport, pushed out by the tick reach `base` on that side, the padding and
half the label's extent.
"""
function axis_label_position(viewport, base::GridLayoutBase.RectSides, l::AxisLabel)
    x0, y0 = minimum(viewport); x1, y1 = maximum(viewport)
    d = side_value(base, l.side) + l.padding + l.extent / 2
    cx, cy = 0.5 * (x0 + x1), 0.5 * (y0 + y1)
    l.side === :bottom && return Point2d(cx, y0 - d)
    l.side === :top && return Point2d(cx, y1 + d)
    l.side === :left && return Point2d(x0 - d, cy)
    return Point2d(x1 + d, cy)
end

"""
    measured_reach(px::Pixels, labels, bands, viewport; visible) -> RectSides{Float32}

How far the drawn decorations on the frame reach past each side of the
viewport, in pixels.  `labels` are the `TickLabel`s `px` was placed from
and `visible` maps family to label visibility, so a hidden family's boxes
do not count (its stubs are already absent from `px`).  As in the bound, a
label or tick stub counts toward the sides its normal points to: a bottom
label's overhang past the corner is the bottom side's business, as on
`Axis`.  The band goes all the way round, so it counts toward every side
it crosses.
"""
function measured_reach(px::Pixels, labels::Vector{TickLabel}, bands::Vector{Vector{Point2d}}, viewport;
                        visible = (; lon = true, lat = true))
    x0, y0 = minimum(viewport); x1, y1 = maximum(viewport)
    left = right = bottom = top = 0.0
    consider(p, n) = begin
        _finite2(p) || return
        n[1] < -0.1 && (left = max(left, x0 - p[1]))
        n[1] > 0.1 && (right = max(right, p[1] - x1))
        n[2] < -0.1 && (bottom = max(bottom, y0 - p[2]))
        n[2] > 0.1 && (top = max(top, p[2] - y1))
    end
    for (k, b) in enumerate(px.boxes)
        visible[labels[px.kept[k]].exit.family] || continue
        for c in corners(b)
            consider(c, px.normals[k])
        end
    end
    for pts in values(px.stubs), i in 1:2:(length(pts) - 1)
        d = pts[i + 1] - pts[i]
        len = norm(d)
        len > 1e-300 && consider(pts[i + 1], d / len)
    end
    everywhere = Vec2d(1, 1)
    for poly in bands, p in poly
        consider(p, everywhere)
        consider(p, -everywhere)
    end
    # pixel arithmetic leaves 1e-5 px of noise, which would keep the pass loop from seeing a settled reach
    snap(x) = round(x; digits = 3)
    return GridLayoutBase.RectSides{Float32}(snap(left), snap(right), snap(bottom), snap(top))
end

"Extent of a drawn text along dimension `dim` in pixels; `0` when hidden or blank."
function text_extent(plot, label, visible::Bool, dim::Int)
    (visible && !Makie.iswhitespace(label)) || return 0.0
    w = Makie.boundingbox(plot, :data).widths[dim]
    return isfinite(w) ? Float64(w) : 0.0
end
