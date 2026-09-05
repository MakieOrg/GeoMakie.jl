#=
# Placement

A label is an upright word pushed out from its exit along the frame's outward
normal: the glyph box clears the frame by the tick length plus the pad, and its
centre lies on the normal.  Boxes are measured once, in pixels, with
`Makie.text_bb`, so labels exist in dest space at level 3 and the protrusion
bound can be taken from them before any viewport is known.  Level 4 only
translates anchors to pixels.

This phase places every exit; the family rule and collisions are Phase 4.
=#

"An oriented box: `centre`, half extents `half` along its own axes, rotated by `θ`."
struct OBox
    centre::Point2d
    half::Vec2d
    θ::Float64
end

"Half extent of the box along the unit direction `u`."
function half_extent(b::OBox, u)
    c, s = cos(b.θ), sin(b.θ)
    return abs(c * u[1] + s * u[2]) * b.half[1] + abs(-s * u[1] + c * u[2]) * b.half[2]
end

"The four corners, counter-clockwise."
function corners(b::OBox)
    c, s = cos(b.θ), sin(b.θ)
    ex = Vec2d(c, s) * b.half[1]
    ey = Vec2d(-s, c) * b.half[2]
    return (Point2d(b.centre - ex - ey), Point2d(b.centre + ex - ey), Point2d(b.centre + ex + ey), Point2d(b.centre - ex + ey))
end

"Separating-axis overlap of two oriented boxes, with `gap` of clearance required."
function collides(a::OBox, b::OBox; gap::Real = 0.0)
    for (box, θ) in ((a, a.θ), (b, b.θ)), ax in (Vec2d(cos(θ), sin(θ)), Vec2d(-sin(θ), cos(θ)))
        pa = a.centre[1] * ax[1] + a.centre[2] * ax[2]
        pb = b.centre[1] * ax[1] + b.centre[2] * ax[2]
        abs(pa - pb) > half_extent(a, ax) + half_extent(b, ax) + gap && return false
    end
    return true
end

"""
    TickLabel

A tick label: its exit, text, dest-space `anchor` and outward `normal`, the
`offset` (tick length + pad) from anchor to glyph box, the box's half extents
and rotation, alignment, and the family's font attributes.  `priority` orders
labels for the collision pass (Phase 4).
"""
struct TickLabel
    exit::Exit
    text::String
    anchor::Point2d
    normal::Vec2d
    offset::Float64
    half::Vec2d
    rotation::Float64
    align::Tuple{Symbol, Symbol}
    auto_align::Bool
    kind::Symbol
    priority::Tuple{Float64, Float64, Int}
end

"Roundness rank of a tick value for the priority: 0°, ±90°, 180° first, then coarser ladder steps."
function roundness(v::Real)
    x = abs(round(float(v); digits = 9))
    (x == 0 || x == 90 || x == 180) && return 0.0
    for (i, s) in enumerate(GEOGRAPHIC_LADDER)
        abs(x / s - round(x / s)) < 1e-9 && return float(i)
    end
    return float(length(GEOGRAPHIC_LADDER) + 1)
end

"Half extents of `text` in pixels."
function text_half_extents(text::AbstractString, font, fontsize::Real)
    bb = Makie.text_bb(text, font, fontsize)
    w = widths(bb)
    return Vec2d(0.5 * w[1], 0.5 * w[2])
end

"""
    place(exits, frame, rect, attrs) -> Vector{TickLabel}

One label per exit.  `attrs` carries per-family `(format, finder, labels, size,
font, pad, ticksize, ticksvisible, rotation, align)` under `:lon` and `:lat`,
and `fonts`.
"""
function place(exits::Vector{Exit}, fr::Frame, rect::Rect2d, attrs)
    labels = TickLabel[]
    extent = max(maximum(widths(rect)), 1e-300)
    for (k, e) in enumerate(exits)
        fa = attrs[e.family]
        text = fa.labels[e.value]
        font = Makie.to_font(attrs.fonts, fa.font)
        half = text_half_extents(text, font, fa.size)
        offset = (fa.ticksvisible ? fa.ticksize : 0.0) + fa.pad
        auto = fa.align isa Makie.Automatic
        align = auto ? (:center, :center) : fa.align
        # distance from the middle of the edge, in units of the extent
        mid = _edge_middle_distance(fr, e, extent)
        push!(labels, TickLabel(e, text, e.p, e.normal, offset, half, float(fa.rotation), align, auto, :frame,
            (roundness(e.value), mid, k)))
    end
    return labels
end

function _edge_middle_distance(fr::Frame, e::Exit, extent)
    lp = fr.loops[e.loop]
    a = lp[e.edge]; b = lp[mod1(e.edge + 1, length(lp))]
    return norm(e.p - 0.5 * (a + b)) / extent
end

"""
    protrusion_bound(labels, visible) -> RectSides{Float32}

Per side, the most any label pushes past its exit toward that side (tick, pad
and glyph box), taking the exit to sit on that side of the limits rectangle.
`visible` maps family to label visibility.
"""
function protrusion_bound(labels::Vector{TickLabel}, visible)
    left = right = bottom = top = 0.0
    for l in labels
        visible[l.exit.family] || continue
        b = OBox(Point2d(0, 0), l.half, l.rotation)
        n = l.normal
        hn = half_extent(b, n)
        d = l.offset + hn
        for (comp, u) in ((-n[1], Vec2d(-1, 0)), (n[1], Vec2d(1, 0)), (-n[2], Vec2d(0, -1)), (n[2], Vec2d(0, 1)))
            comp > 0.1 || continue
            reach = comp * d + half_extent(b, u)
            if u[1] < 0
                left = max(left, reach)
            elseif u[1] > 0
                right = max(right, reach)
            elseif u[2] < 0
                bottom = max(bottom, reach)
            else
                top = max(top, reach)
            end
        end
    end
    return GridLayoutBase.RectSides{Float32}(left, right, bottom, top)
end

# ---- pixels ----------------------------------------------------------------------

"""
    PixelMap

Dest → pixel (figure) coordinates from a camera's projection-view matrix and
the scene viewport.
"""
struct PixelMap
    pv::Makie.Mat4d
    origin::Vec2d
    size::Vec2d
end
PixelMap(pv, vp) = PixelMap(Makie.Mat4d(pv), Vec2d(minimum(vp)), Vec2d(widths(vp)))

function (m::PixelMap)(p)
    c = m.pv * Makie.Vec4d(p[1], p[2], 0.0, 1.0)
    w = c[4] == 0 ? 1.0 : c[4]
    return Point2d(m.origin .+ (Vec2d(c[1], c[2]) ./ w .+ 1.0) .* 0.5 .* m.size)
end

"A dest direction as a pixel direction (unit length)."
function pixel_direction(m::PixelMap, p, d)
    q = m(p + d) - m(p)
    n = norm(q)
    n <= 1e-300 && return Vec2d(0, 0)
    return Vec2d(q / n)
end

"""
    Pixels

Level 4: everything in pixel space.  `frame` loops, `graticule` polylines per
family, per label the pixel `position` handed to `text!`, the glyph `box`, and
the tick `stub` segments per family.
"""
struct Pixels
    frame::Vector{Vector{Point2d}}
    graticule::Dict{Symbol, Vector{Vector{Point2d}}}
    positions::Dict{Symbol, Vector{Point2d}}
    strings::Dict{Symbol, Vector{String}}
    boxes::Vector{OBox}
    exits::Vector{Point2d}
    normals::Vector{Vec2d}
    kept::Vector{Int}                       # indices into the level-3 labels that are drawn
    suppressed::Vector{Tuple{Int, Symbol}}  # (label index, reason)
    stubs::Dict{Symbol, Vector{Point2d}}
end

"Even-odd point-in-polygon over every loop (holes are loops too)."
function inside_loops(loops::Vector{Vector{Point2d}}, q)
    inside = false
    for pts in loops
        n = length(pts)
        for i in 1:n
            a, b = pts[i], pts[mod1(i + 1, n)]
            if (a[2] > q[2]) != (b[2] > q[2])
                x = a[1] + (q[2] - a[2]) / (b[2] - a[2]) * (b[1] - a[1])
                x > q[1] && (inside = !inside)
            end
        end
    end
    return inside
end

"Does the box reach into the map body (its centre or a corner lies inside the frame)?"
function box_inside_map(b::OBox, loops::Vector{Vector{Point2d}})
    inside_loops(loops, b.centre) && return true
    for c in corners(b)
        inside_loops(loops, c) && return true
    end
    return false
end

"""
    pixels(frame, lines, labels, pv, viewport, ticks) -> Pixels

`ticks` maps family to `(size, align, visible)`.
"""
function pixels(fr::Frame, lines::Vector{GraticuleLine}, labels::Vector{TickLabel}, pv, viewport, ticks)
    m = PixelMap(pv, viewport)
    fpx = [Point2d[m(p) for p in lp] for lp in fr.loops]
    gpx = Dict{Symbol, Vector{Vector{Point2d}}}(:lon => Vector{Point2d}[], :lat => Vector{Point2d}[])
    for l in lines, pc in l.pieces
        push!(gpx[l.family], Point2d[m(p) for p in pc])
    end
    positions = Dict{Symbol, Vector{Point2d}}(:lon => Point2d[], :lat => Point2d[])
    strings = Dict{Symbol, Vector{String}}(:lon => String[], :lat => String[])
    stubs = Dict{Symbol, Vector{Point2d}}(:lon => Point2d[], :lat => Point2d[])
    boxes = OBox[]; epx = Point2d[]; npx = Vec2d[]
    kept = Int[]; suppressed = Tuple{Int, Symbol}[]
    scale = 1e-3 * max(maximum(widths(viewport)), 1.0)
    done = Set{Tuple{Symbol, Float64, Int, Int}}()
    for (k, l) in enumerate(labels)
        e = l.exit
        p = m(e.p)
        n = pixel_direction(m, e.p, e.normal * (scale / max(norm(e.normal), 1e-300)))
        box0 = OBox(Point2d(0, 0), l.half, l.rotation)
        d = l.offset + half_extent(box0, n)
        centre = Point2d(p + n * d)
        box = OBox(centre, l.half, l.rotation)
        # a cut's outward side is the neighbouring lobe: a label that would sit on the map is not drawn
        if box_inside_map(box, fpx)
            push!(suppressed, (k, :inside))
            continue
        end
        push!(kept, k)
        push!(boxes, box)
        push!(epx, p); push!(npx, n)
        push!(positions[e.family], l.auto_align ? centre : Point2d(p + n * l.offset))
        push!(strings[e.family], l.text)
        key = (e.family, e.value, e.loop, e.edge)
        key in done && continue
        push!(done, key)
        tk = ticks[e.family]
        tk.visible || continue
        start = Point2d(p - n * (tk.align * tk.size))
        push!(stubs[e.family], start, Point2d(start + n * tk.size))
    end
    return Pixels(fpx, gpx, positions, strings, boxes, epx, npx, kept, suppressed, stubs)
end
