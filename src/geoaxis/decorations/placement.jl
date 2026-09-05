#=
# Placement

A label is an upright word pushed out from its exit along the frame's outward
normal: the glyph box clears the frame by the tick length plus the pad, and its
centre lies on the normal.  Boxes are measured once, in pixels, with
`Makie.text_bb`, so labels exist in dest space at level 3 and the protrusion
bound can be taken from them before any viewport is known.  Level 4 only
translates anchors to pixels and runs the collision pass.

Which exits become candidates (level 3):

  * the family rule: a straight `:viewport` edge takes the `Axis` convention,
    longitudes on horizontal edges and latitudes on vertical ones, on the sides
    `x/yaxisposition` name; every other edge admits both families;
  * the convergence rule: where two or more lines of one family reach the
    frame at one point (a pole drawn as a point) none of them is labelled there;
  * the grazing rule: a line leaving the frame at less than `ticklabelminangle`
    is not labelled.

Which candidates are drawn (level 4): a box on the map body is not drawn, and
of two colliding boxes the one with the better priority (rounder value, nearer
the middle of its edge, earlier) wins.  Every drop is a `Suppressed` record.
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
labels for the collision pass: `(roundness, distance from the edge middle,
order)`, smaller first.
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

"""
    Suppressed

A tick that is not drawn: `index` into the level-3 labels (`0` when the exit
never became a label), its family and value, the `reason`, and for a collision
the index of the kept label it hit.

Reasons: `:family` (a viewport edge admits the other family, or is not an axis
position), `:convergent` (a pole point), `:grazing`, `:noexit` (the line never
reaches the frame), `:inside` (the box would lie on the map), `:collision`,
`:duplicate` (the same tick already drawn beside it, from the other side of a cut).
"""
struct Suppressed
    index::Int
    family::Symbol
    value::Float64
    reason::Symbol
    hit::Int
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
    edge_side(normal) -> :left | :right | :bottom | :top

The side of the limits rectangle a straight edge with outward `normal` is on.
"""
function edge_side(normal)
    if abs(normal[2]) >= abs(normal[1])
        return normal[2] < 0 ? :bottom : :top
    end
    return normal[1] < 0 ? :left : :right
end

"""
    admits(tag, family, normal, xaxisposition, yaxisposition) -> Bool

The family rule.  On a `:viewport` edge longitudes go on horizontal edges and
latitudes on vertical ones, and only on the sides the axis positions name
(`:bottom`, `:top`, `:both` / `:left`, `:right`, `:both`); every other edge
admits both families.
"""
function admits(tag::Symbol, family::Symbol, normal, xaxisposition::Symbol, yaxisposition::Symbol)
    tag === :viewport || return true
    side = edge_side(normal)
    if side === :bottom || side === :top
        family === :lon || return false
        return xaxisposition === :both || xaxisposition === side
    end
    family === :lat || return false
    return yaxisposition === :both || yaxisposition === side
end
admits(e::Exit, xaxisposition::Symbol, yaxisposition::Symbol) = admits(e.tag, e.family, e.normal, xaxisposition, yaxisposition)

"""
    convergent_exits(exits, tol) -> Set{Int}

Indices of exits where two or more lines of one family, with distinct values,
reach the frame within `tol` of each other.  Two meridians (or two parallels)
meet only at a pole, so such a point is a pole drawn as a point.
"""
function convergent_exits(exits::Vector{Exit}, tol::Real)
    out = Set{Int}()
    n = length(exits)
    for i in 1:n
        e = exits[i]
        vals = Set{Float64}((e.value,))
        for j in 1:n
            f = exits[j]
            (f.family === e.family && norm(f.p - e.p) <= tol) || continue
            push!(vals, f.value)
        end
        length(vals) >= 2 && push!(out, i)
    end
    return out
end

"""
    place(exits, frame, rect, attrs) -> (Vector{TickLabel}, Vector{Suppressed})

One label per admitted exit.  `attrs` carries per-family `(labels, size, font,
pad, ticksize, ticksvisible, rotation, align)` under `:lon` and `:lat`,
`fonts`, `xaxisposition`, `yaxisposition` and `minangle`.  The suppressed
list names every exit that was not admitted and every tick value with no exit.
"""
function place(exits::Vector{Exit}, fr::Frame, rect::Rect2d, attrs)
    labels = TickLabel[]
    suppressed = Suppressed[]
    extent = max(maximum(widths(rect)), 1e-300)
    convergent = convergent_exits(exits, ON_FRAME_FRAC * extent)
    seen = Dict{Symbol, Set{Float64}}(:lon => Set{Float64}(), :lat => Set{Float64}())
    for (k, e) in enumerate(exits)
        push!(seen[e.family], e.value)
        if !admits(e, attrs.xaxisposition, attrs.yaxisposition)
            push!(suppressed, Suppressed(0, e.family, e.value, :family, 0))
            continue
        end
        if k in convergent
            push!(suppressed, Suppressed(0, e.family, e.value, :convergent, 0))
            continue
        end
        if e.angle < attrs.minangle
            push!(suppressed, Suppressed(0, e.family, e.value, :grazing, 0))
            continue
        end
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
            (roundness(e.value), mid, length(labels) + 1)))
    end
    for family in (:lon, :lat)
        for v in sort!(collect(keys(attrs[family].labels)))
            v in seen[family] || push!(suppressed, Suppressed(0, family, v, :noexit, 0))
        end
    end
    return labels, suppressed
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
family, per drawn label the pixel `position` handed to `text!`, the glyph
`box`, exit and normal, `kept` (indices into the level-3 labels, in label
order), `suppressed` (the `:inside` and `:collision` drops), and the tick
`stub` segments per family.
"""
struct Pixels
    frame::Vector{Vector{Point2d}}
    graticule::Dict{Symbol, Vector{Vector{Point2d}}}
    positions::Dict{Symbol, Vector{Point2d}}
    strings::Dict{Symbol, Vector{String}}
    boxes::Vector{OBox}
    exits::Vector{Point2d}
    normals::Vector{Vec2d}
    kept::Vector{Int}
    suppressed::Vector{Suppressed}
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
    pixels(frame, lines, labels, pv, viewport, ticks; mingap = 2, collisions = true) -> Pixels

`ticks` maps family to `(size, align, visible)`.  Labels are placed in
priority order; a box on the map is not drawn, and with `collisions` on a box
within `mingap` pixels of an already placed one is dropped.
"""
function pixels(fr::Frame, lines::Vector{GraticuleLine}, labels::Vector{TickLabel}, pv, viewport, ticks;
                mingap::Real = 2.0, collisions::Bool = true)
    m = PixelMap(pv, viewport)
    fpx = [Point2d[m(p) for p in lp] for lp in fr.loops]
    gpx = Dict{Symbol, Vector{Vector{Point2d}}}(:lon => Vector{Point2d}[], :lat => Vector{Point2d}[])
    for l in lines, pc in l.pieces
        push!(gpx[l.family], Point2d[m(p) for p in pc])
    end
    scale = 1e-3 * max(maximum(widths(viewport)), 1.0)
    n = length(labels)
    boxes = Vector{OBox}(undef, n)
    epx = Vector{Point2d}(undef, n)
    npx = Vector{Vec2d}(undef, n)
    for (k, l) in enumerate(labels)
        e = l.exit
        p = m(e.p)
        nrm = pixel_direction(m, e.p, e.normal * (scale / max(norm(e.normal), 1e-300)))
        box0 = OBox(Point2d(0, 0), l.half, l.rotation)
        d = l.offset + half_extent(box0, nrm)
        boxes[k] = OBox(Point2d(p + nrm * d), l.half, l.rotation)
        epx[k] = p; npx[k] = nrm
    end
    # the greedy pass, in priority order: the record it leaves is order-free
    kept = Int[]; suppressed = Suppressed[]
    for k in sortperm(labels; by = l -> l.priority)
        l = labels[k]
        # a cut's outward side is the neighbouring lobe: a label that would sit on the map is not drawn
        if box_inside_map(boxes[k], fpx)
            push!(suppressed, Suppressed(k, l.exit.family, l.exit.value, :inside, 0))
            continue
        end
        if collisions
            hit = findfirst(j -> collides(boxes[j], boxes[k]; gap = mingap), kept)
            if hit !== nothing
                # the same tick on both sides of a cut is one label, not crowding
                h = labels[kept[hit]].exit
                reason = (h.family === l.exit.family && h.value == l.exit.value) ? :duplicate : :collision
                push!(suppressed, Suppressed(k, l.exit.family, l.exit.value, reason, kept[hit]))
                continue
            end
        end
        push!(kept, k)
    end
    sort!(kept)
    sort!(suppressed; by = s -> s.index)
    positions = Dict{Symbol, Vector{Point2d}}(:lon => Point2d[], :lat => Point2d[])
    strings = Dict{Symbol, Vector{String}}(:lon => String[], :lat => String[])
    for k in kept
        l = labels[k]
        push!(positions[l.exit.family], l.auto_align ? boxes[k].centre : Point2d(epx[k] + npx[k] * l.offset))
        push!(strings[l.exit.family], l.text)
    end
    # a tick marks every admitted exit that is not on the map, labelled or not
    stubs = Dict{Symbol, Vector{Point2d}}(:lon => Point2d[], :lat => Point2d[])
    done = Set{Tuple{Symbol, Float64, Int, Int}}()
    inside = Set{Int}(s.index for s in suppressed if s.reason === :inside)
    for k in 1:n
        k in inside && continue
        e = labels[k].exit
        key = (e.family, e.value, e.loop, e.edge)
        key in done && continue
        push!(done, key)
        tk = ticks[e.family]
        tk.visible || continue
        p = epx[k]; nrm = npx[k]
        start = Point2d(p - nrm * (tk.align * tk.size))
        push!(stubs[e.family], start, Point2d(start + nrm * tk.size))
    end
    return Pixels(fpx, gpx, positions, strings, boxes[kept], epx[kept], npx[kept], kept, suppressed, stubs)
end

# ---- the report -------------------------------------------------------------------

"""
    suppression_report(suppressed, mingap, minangle) -> Union{Nothing, String}

The crowding diagnostic: how many labels of each family were skipped for
collisions, and for grazing exits, naming the attribute that controls each.
`nothing` when nothing was skipped for either reason.
"""
function suppression_report(suppressed::Vector{Suppressed}, mingap::Real, minangle::Real)
    clon = count(s -> s.reason === :collision && s.family === :lon, suppressed)
    clat = count(s -> s.reason === :collision && s.family === :lat, suppressed)
    graze = count(s -> s.reason === :grazing, suppressed)
    parts = String[]
    (clon + clat) > 0 && push!(parts,
        "$clon longitude and $clat latitude labels skipped due to crowding; controlled by `ticklabelmingap`, currently $(float(mingap)) px")
    graze > 0 && push!(parts,
        "$graze labels skipped for leaving the frame at a grazing angle; controlled by `ticklabelminangle`, currently $(float(minangle))°")
    isempty(parts) && return nothing
    return join(parts, ". ")
end

"Log the report through `mode` (`:debug`, `:info`, or `:none`)."
function report_suppressions(suppressed::Vector{Suppressed}, mode::Symbol, mingap::Real, minangle::Real)
    mode === :none && return nothing
    msg = suppression_report(suppressed, mingap, minangle)
    msg === nothing && return nothing
    if mode === :info
        @info msg
    else
        @debug msg
    end
    return msg
end
