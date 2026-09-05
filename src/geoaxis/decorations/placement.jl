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

A line that never reaches the frame (a closed parallel, a meridian ending in a
pole point) or that lost every frame exit to geometry rather than to the family
rule alone gets one `:interior` candidate instead: on the line itself, turned
to read along it, just past its crossing with a carrier line of the other
family, inside the map, over a halo.  This is the one sanctioned exception to
"nothing inside the map": the box must lie within the map, clear the carrier
by the pad and cross no other graticule line but its own.

Which candidates are drawn (level 4): a frame box on the map body is not drawn,
an interior box off the map is not drawn, and of two colliding boxes the one
with the better priority (rounder value, nearer the middle of its edge,
earlier) wins.  Every drop is a `Suppressed` record.
=#

const POLE_CONVERGE_DEG = 1.0           # exits this close to a pole on the sphere ...
const POLE_CONVERGE_FRAC = 0.05         # ... and to each other (× extent) converge there

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

A tick label: its exit, text, dest-space `anchor`, the `offset` (tick length +
pad) from anchor to glyph box, the box's half extents and rotation, alignment,
and the family's font attributes.  A frame label's box is pushed from the
anchor along `normal` by `offset` plus its own half extent.  An interior
label's anchor is its crossing with the carrier, `centre` where its box ended
up on the line (`NaN` for a frame label), `normal` the line's direction there
(the way it was walked from the crossing) and `offset` the pad it clears the
carrier by; with `auto_rotation` its rotation follows that direction,
re-measured in pixels at level 4.  `carrier` is the carrier's value for an
interior label (`NaN` for a frame label).  `priority` orders labels for the
collision pass: `(roundness, distance from the edge middle, order)`, smaller
first.
"""
struct TickLabel
    exit::Exit
    text::String
    anchor::Point2d
    normal::Vec2d
    centre::Point2d
    offset::Float64
    half::Vec2d
    rotation::Float64
    auto_rotation::Bool
    align::Tuple{Symbol, Symbol}
    auto_align::Bool
    kind::Symbol
    carrier::Float64
    priority::Tuple{Float64, Float64, Int}
end

isinterior(l::TickLabel) = l.kind === :interior

"""
    Suppressed

A tick that is not drawn: `index` into the level-3 labels (`0` when the exit
never became a label), its family and value, the `reason`, for a collision the
index of the kept label it hit, and the `kind` of label it would have been
(`:frame` or `:interior`).

Frame reasons: `:family` (a viewport edge admits the other family, or is not an
axis position), `:convergent` (a pole point), `:grazing`, `:noexit` (the line
never reaches the frame), `:inside` (the box would lie on the map),
`:collision`, `:duplicate` (the same tick already drawn beside it, from the
other side of a cut).  Interior reasons: `:nocrossing` (the line does not meet
the carrier in view), `:outside` (no placement keeps the box on the map, or
the line is too short or too oblique to the carrier to hold one), `:crossed`
(every placement on the map crosses another graticule line, or comes within
the pad of the carrier), `:collision`.
"""
struct Suppressed
    index::Int
    family::Symbol
    value::Float64
    reason::Symbol
    hit::Int
    kind::Symbol
end
Suppressed(index, family, value, reason, hit) = Suppressed(index, family, value, reason, hit, :frame)

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
    convergent_exits(exits, tol; poletol) -> Set{Int}

Indices of exits where two or more lines of one family, with distinct values,
reach the frame at one point.  Two meridians (or two parallels) meet only at a
pole, so such a point is a pole drawn as a point.  Two exits count as one
point when they are within `tol` of each other in dest space, or when both
lie within `POLE_CONVERGE_DEG` of the same pole on the sphere and within
`poletol` of each other in dest space.  The second test is what catches a
pole on a probed rim: the rim's polygon cuts the corner at the pole by a
fraction of a degree, and a projection singular there spreads that fraction
over many pixels.  It does not apply on a `:pole` edge, where every exit is
at the pole on the sphere by construction and the pole is drawn as a line.
"""
function convergent_exits(exits::Vector{Exit}, tol::Real; poletol::Real = tol * POLE_CONVERGE_FRAC / ON_FRAME_FRAC)
    out = Set{Int}()
    n = length(exits)
    for i in 1:n
        e = exits[i]
        vals = Set{Float64}((e.value,))
        pole = e.tag === :pole ? 0 : near_pole(e.sphere)
        for j in 1:n
            f = exits[j]
            f.family === e.family || continue
            d = norm(f.p - e.p)
            (d <= tol || (pole != 0 && f.tag !== :pole && near_pole(f.sphere) == pole && d <= poletol)) || continue
            push!(vals, f.value)
        end
        length(vals) >= 2 && push!(out, i)
    end
    return out
end

"`±1` for a unit vector within `POLE_CONVERGE_DEG` of the north / south pole, `0` otherwise (or for `NaN`)."
near_pole(q) = (_finite3(q) && abs(q[3]) >= cosd(POLE_CONVERGE_DEG)) ? Int(sign(q[3])) : 0

# ---- boxes against polylines ---------------------------------------------------

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

"Axis-aligned bounds `(x0, x1, y0, y1)` of a point list."
function _aabb(pts)
    x0 = y0 = Inf; x1 = y1 = -Inf
    for p in pts
        _finite2(p) || continue
        x0 = min(x0, p[1]); x1 = max(x1, p[1]); y0 = min(y0, p[2]); y1 = max(y1, p[2])
    end
    return (x0, x1, y0, y1)
end
_aabb(b::OBox) = _aabb(corners(b))
_aabb_disjoint(a, b) = a[1] > b[2] || a[2] < b[1] || a[3] > b[4] || a[4] < b[3]

"`p` in the box's own frame (centre at the origin, axes along the box's)."
function _to_local(b::OBox, p)
    c, s = cos(b.θ), sin(b.θ)
    d = p - b.centre
    return Point2d(c * d[1] + s * d[2], -s * d[1] + c * d[2])
end

"Does the segment `a → q` touch the box?"
function segment_crosses_box(b::OBox, a, q)
    r = Rect2d(-b.half[1], -b.half[2], 2 * b.half[1], 2 * b.half[2])
    return _lb_range(_to_local(b, a), _to_local(b, q), r) !== nothing
end

"""
    polyline_crosses_box(box, pts, bb; closed = false) -> Bool

Does any segment of the polyline `pts` (bounds `bb`, `NaN` breaks allowed)
touch the box?  `closed` joins the last point to the first.
"""
function polyline_crosses_box(b::OBox, pts, bb; closed::Bool = false)
    bx = _aabb(b)
    _aabb_disjoint(bb, bx) && return false
    n = length(pts)
    for i in 1:(closed ? n : n - 1)
        a, q = pts[i], pts[mod1(i + 1, n)]
        (_finite2(a) && _finite2(q)) || continue
        (min(a[1], q[1]) > bx[2] || max(a[1], q[1]) < bx[1] || min(a[2], q[2]) > bx[4] || max(a[2], q[2]) < bx[3]) && continue
        segment_crosses_box(b, a, q) && return true
    end
    return false
end

"Is the box wholly on the map (every corner inside the loops and no loop edge across it)?  `bbs` are the loops' bounds."
function box_within_loops(b::OBox, loops::Vector{Vector{Point2d}}, bbs = [_aabb(lp) for lp in loops])
    for c in corners(b)
        inside_loops(loops, c) || return false
    end
    for (lp, bb) in zip(loops, bbs)
        polyline_crosses_box(b, lp, bb; closed = true) && return false
    end
    return true
end

"""
    graticule_crosses_box(box, lines, pieces_bb, own) -> Bool

Does a piece of any graticule line other than `own` (`(family, value)`) touch
the box?  `pieces_bb[i]` holds the bounds of `lines[i].pieces`.
"""
function graticule_crosses_box(b::OBox, lines::Vector{GraticuleLine}, pieces_bb, own)
    for (i, l) in enumerate(lines)
        (l.family, l.value) == own && continue
        for (k, pc) in enumerate(l.pieces)
            polyline_crosses_box(b, pc, pieces_bb[i][k]) && return true
        end
    end
    return false
end

_pieces_bounds(lines::Vector{GraticuleLine}) = [[_aabb(pc) for pc in l.pieces] for l in lines]

# ---- interior labels ------------------------------------------------------------

_right_normal(t::Vec2d) = Vec2d(t[2], -t[1])

"The two ways along a line from its carrier crossing: with the line's tangent and against it."
const INTERIOR_DIRECTIONS = (1, -1)
"""
The placements tried for an interior label, as `(reach, shift)`: on the line at
the distance that clears the carrier by the pad, then further along it when a
curved neighbour still touches; then flush against the line on either side,
for a line that lies on the frame or a circle too tight to hold the label.
"""
const INTERIOR_PLACEMENTS = ((1.0, 0), (1.25, 0), (1.5, 0), (2.0, 0), (1.0, 1), (1.0, -1), (1.5, 1), (1.5, -1))
"A box shifted off its line keeps this fraction of the pad between them, so a line on the frame stays outside the box."
const INTERIOR_SHIFT_GAP = 0.2
"""
Level 3 places interior labels in an isotropic dest space, but the viewport is
rounded to whole pixels per axis; the pad is widened by this fraction there so
the gap to the carrier is still the pad in pixels.
"""
const INTERIOR_PAD_SLACK = 0.03
"An interior label needs its line and carrier to cross at least this steeply (sine of the angle), or the walk would be unbounded."
const INTERIOR_MIN_CROSS = sind(15)
"A line within this of vertical reads bottom to top, whichever way it leans."
const VERTICAL_SNAP_DEG = 0.5

"""
    upright_rotation(θ) -> Float64

`θ` folded into `(-π/2, π/2]`, so the text reads upright; within
`VERTICAL_SNAP_DEG` of vertical it is `π/2`, so a meridian that is vertical
up to rounding always reads bottom to top.
"""
function upright_rotation(θ::Real)
    θ = mod(θ + π / 2, π) - π / 2        # [-π/2, π/2)
    abs(abs(θ) - π / 2) <= deg2rad(VERTICAL_SNAP_DEG) && (θ = π / 2)
    return float(θ)
end

"The upright rotation reading along the direction `t`."
tangent_rotation(t) = upright_rotation(atan(t[2], t[1]))

"""
    along_line(line, p, dir, s) -> Union{Nothing, Tuple{Point2d, Vec2d}}

The point at arc length `s` from `p` (a point on the line) along the line's
pieces in the direction `dir`, with the line's unit direction there, or
`nothing` when the line ends first.  A closed piece wraps.
"""
function along_line(line::GraticuleLine, p, dir, s::Real)
    best = nothing; bd = Inf
    for (k, pc) in enumerate(line.pieces)
        n = length(pc)
        for i in 1:(line.closed[k] ? n : n - 1)
            d = _seg_dist(p, pc[i], pc[mod1(i + 1, n)])
            d < bd && (bd = d; best = (k, i))
        end
    end
    best === nothing && return nothing
    k, i = best
    pc = line.pieces[k]
    n = length(pc)
    closed = line.closed[k]
    a, b = pc[i], pc[mod1(i + 1, n)]
    seg = b - a
    forward = seg[1] * dir[1] + seg[2] * dir[2] >= 0
    # start from p's projection onto the segment
    l2 = seg[1]^2 + seg[2]^2
    t = l2 > 0 ? clamp(((p - a)[1] * seg[1] + (p - a)[2] * seg[2]) / l2, 0.0, 1.0) : 0.0
    cur = Point2d(a + seg * t)
    remaining = float(s)
    j = forward ? i + 1 : i
    steps = 0
    while steps <= n
        (closed || 1 <= j <= n) || return nothing
        q = pc[mod1(j, n)]
        step = q - cur
        len = norm(step)
        if len >= remaining
            t = len > 0 ? Vec2d(step / len) : Vec2d(dir / norm(dir))
            return Point2d(cur + step * (len > 0 ? remaining / len : 0.0)), t
        end
        remaining -= len
        cur = q
        j += forward ? 1 : -1
        steps += 1
    end
    return nothing
end

"""
    interior_box(x, dir, half, pad, rotation, line; reach = 1, shift = 0) -> Union{Nothing, Tuple{OBox, Vec2d}}

The box of an interior label on its own line, `reach` times as far along it
(with `dir = ±1` the line's tangent) from the crossing `x` as it takes to
clear the carrier by `pad`, and the line's direction at the box, in the space
of `x.p`.  `rotation` is `automatic` for that direction's upright angle.  With
`shift = ±1` the box is moved off the line to that side, `INTERIOR_SHIFT_GAP`
of the pad away from it.  `nothing` when the line ends first or crosses the
carrier too obliquely.
"""
function interior_box(x::CarrierCrossing, dir::Int, half::Vec2d, pad::Real, rotation, line::GraticuleLine;
                      reach::Real = 1.0, shift::Int = 0)
    lt, ct = x.ltangent, x.ctangent
    sinφ = abs(lt[1] * ct[2] - lt[2] * ct[1])
    sinφ >= INTERIOR_MIN_CROSS || return nothing
    θ0 = rotation isa Makie.Automatic ? tangent_rotation(lt) : float(rotation)
    box0 = OBox(Point2d(0, 0), half, θ0)
    dist = reach * (pad * (1 + INTERIOR_PAD_SLACK) + half_extent(box0, _right_normal(ct))) / sinφ
    at = along_line(line, x.p, dir * lt, dist)
    at === nothing && return nothing
    c, t = at
    θ = rotation isa Makie.Automatic ? tangent_rotation(t) : float(rotation)
    b = OBox(c, half, θ)
    if shift != 0
        n = _right_normal(t)
        b = OBox(Point2d(c + n * (shift * (half_extent(b, n) + INTERIOR_SHIFT_GAP * pad))), half, θ)
    end
    return b, t
end

"A box grown by `pad` on every side."
inflate(b::OBox, pad::Real) = OBox(b.centre, b.half .+ pad, b.θ)

"""
    _interior_candidates!(labels, suppressed, family, groups, lines, fr, attrs)

Add one `:interior` candidate per line of `family` that qualifies: a line with
no frame candidate that lost at least one exit for a geometric reason
(`:convergent`, `:grazing`, `:noexit`), so not a line whose every exit was
turned away solely by the family / axis-position rule (every line when
`attrs.interior.mode === :all`).
`groups` are `(carrier value, crossings)` in preference order.  The carrier
and direction along the line are chosen together, in dest space scaled by
`attrs.interior.px_scale`: the first pair under which every label is on the
map, clears the carrier by the pad, crosses no other graticule line and
clears its neighbours; failing that the pair with the most such labels (the
equator, then the earlier pair, on a tie), and each remaining label takes the
first placement that works for it alone, or is suppressed.
"""
function _interior_candidates!(labels::Vector{TickLabel}, suppressed::Vector{Suppressed}, family::Symbol,
                               groups, lines::Vector{GraticuleLine}, fr::Frame, attrs)
    int = attrs.interior
    fa = attrs[family]
    px_scale = max(int.px_scale, 1e-300)
    # which lines qualify
    framed = Set{Float64}(l.exit.value for l in labels if l.exit.family === family && !isinterior(l))
    geometric = Set{Float64}(s.value for s in suppressed if s.family === family && s.kind === :frame && s.reason !== :family)
    values = Float64[]
    for l in lines
        l.family === family || continue
        (int.mode === :all || (!(l.value in framed) && l.value in geometric)) && push!(values, l.value)
    end
    isempty(values) && return
    font = Makie.to_font(attrs.fonts, fa.font)
    size = int.size[family]
    halves = Dict{Float64, Vec2d}(v => text_half_extents(fa.labels[v], font, size) for v in values)
    own = Dict{Float64, GraticuleLine}(l.value => l for l in lines if l.family === family)
    pad = fa.pad / px_scale
    gap = int.mingap / px_scale
    auto_rot = int.rotation isa Makie.Automatic
    pieces_bb = _pieces_bounds(lines)
    loops_bb = [_aabb(lp) for lp in fr.loops]
    valueset = Set(values)

    other = family === :lon ? :lat : :lon
    carriers = Dict{Float64, Int}(l.value => i for (i, l) in enumerate(lines) if l.family === other)
    # does the box cross a line other than its own, or come within the pad of the carrier?
    function crossed(b, x)
        graticule_crosses_box(b, lines, pieces_bb, (family, x.value)) && return true
        i = get(carriers, x.carrier, 0)
        i == 0 && return false
        ib = inflate(b, pad * (1 + INTERIOR_PAD_SLACK))
        return any(k -> polyline_crosses_box(ib, lines[i].pieces[k], pieces_bb[i][k]), eachindex(lines[i].pieces))
    end
    # the first placement at which the box is on the map and clear
    function fit(x, dir)
        reason = :outside
        for (reach, shift) in INTERIOR_PLACEMENTS
            at = interior_box(x, dir, halves[x.value] / px_scale, pad, int.rotation, own[x.value]; reach, shift)
            at === nothing && break
            b, t = at
            box_within_loops(b, fr.loops, loops_bb) || continue
            reason = :crossed
            crossed(b, x) && continue
            return (b, t), :ok
        end
        return nothing, reason
    end
    function score(xs, dir)
        placed = [fit(x, dir)[1] for x in xs]
        ok = [b !== nothing for b in placed]
        for i in eachindex(xs), j in (i + 1):length(xs)
            (ok[i] && ok[j] && collides(placed[i][1], placed[j][1]; gap)) || continue
            ok[i] = false; ok[j] = false
        end
        return count(ok), ok, placed
    end

    best = nothing   # (score, group index, direction index, crossings, ok, boxes)
    order = 0
    for (gi, (carrier, xs)) in enumerate(groups), (di, dir) in enumerate(INTERIOR_DIRECTIONS)
        order += 1
        sel = [x for x in xs if x.value in valueset]
        n, ok, boxes = score(sel, dir)
        key = (n, carrier == 0 ? 1 : 0, -order)
        if best === nothing || key > best[1]
            best = (key, gi, di, sel, ok, boxes)
        end
        n == length(values) && break
    end
    best === nothing && return
    _, gi, di, sel, ok, fits = best
    carrier = groups[gi][1]
    present = Set(x.value for x in sel)
    for v in values
        v in present || push!(suppressed, Suppressed(0, family, v, :nocrossing, 0, :interior))
    end
    # the labels the shared direction places, then each remaining one in the
    # first direction that fits it beside what is already placed
    chosen = Vector{Union{Nothing, Tuple{Int, OBox, Vec2d}}}(nothing, length(sel))
    placed = OBox[]
    for (i, x) in enumerate(sel)
        ok[i] || continue
        chosen[i] = (INTERIOR_DIRECTIONS[di], fits[i]...)
        push!(placed, fits[i][1])
    end
    for (i, x) in enumerate(sel)
        ok[i] && continue
        reason = :outside
        for dir in INTERIOR_DIRECTIONS
            at, why = fit(x, dir)
            if at === nothing
                (reason === :outside && why === :crossed) && (reason = :crossed)
                continue
            end
            b, t = at
            reason = :collision
            any(q -> collides(q, b; gap), placed) && continue
            chosen[i] = (dir, b, t)
            push!(placed, b)
            break
        end
        chosen[i] === nothing && push!(suppressed, Suppressed(0, family, x.value, reason, 0, :interior))
    end
    for (i, x) in enumerate(sel)
        m = chosen[i]
        m === nothing && continue
        dir, b, t = m
        exit = Exit(family, x.value, x.p, 0, 0, :interior, _right_normal(x.ctangent), 90.0, x.ltangent)
        push!(labels, TickLabel(exit, fa.labels[x.value], x.p, Vec2d(dir * t), b.centre, float(fa.pad),
            halves[x.value], b.θ, auto_rot, (:center, :center), true, :interior, carrier,
            (roundness(x.value), 0.0, length(labels) + 1)))
    end
    return
end

"""
    place(exits, frame, rect, lines, crossings, attrs) -> (Vector{TickLabel}, Vector{Suppressed})

One label per admitted exit, and one interior label per line that never gets
one.  `attrs` carries per-family `(labels, size, font, pad, ticksize,
ticksvisible, rotation, align)` under `:lon` and `:lat`, `fonts`,
`xaxisposition`, `yaxisposition`, `minangle`, `band` (the fancy band's width
in pixels, `0` for a plain frame), and `interior = (mode, px_scale, mingap,
size, rotation)` (`size` per family; `rotation` a fixed angle or `automatic`
for the line's tangent); `crossings` has the carrier crossings (`lat` for the
carrier meridian, `lon` per candidate parallel).  The suppressed list names every exit
that was not admitted, every tick value with no exit, and every interior
label that found no place.
"""
function place(exits::Vector{Exit}, fr::Frame, rect::Rect2d, lines::Vector{GraticuleLine}, crossings, attrs)
    labels = TickLabel[]
    suppressed = Suppressed[]
    extent = max(maximum(widths(rect)), 1e-300)
    convergent = convergent_exits(exits, ON_FRAME_FRAC * extent; poletol = POLE_CONVERGE_FRAC * extent)
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
        # a fancy band replaces the tick stubs: labels clear the band instead
        offset = (attrs.band > 0 ? attrs.band : (fa.ticksvisible ? fa.ticksize : 0.0)) + fa.pad
        auto = fa.align isa Makie.Automatic
        align = auto ? (:center, :center) : fa.align
        # distance from the middle of the edge, in units of the extent
        mid = _edge_middle_distance(fr, e, extent)
        push!(labels, TickLabel(e, text, e.p, e.normal, Point2d(NaN, NaN), offset, half, float(fa.rotation), false, align, auto,
            :frame, NaN, (roundness(e.value), mid, length(labels) + 1)))
    end
    for family in (:lon, :lat)
        for v in sort!(collect(keys(attrs[family].labels)))
            v in seen[family] || push!(suppressed, Suppressed(0, family, v, :noexit, 0))
        end
    end
    if attrs.interior.mode !== false && !isempty(fr.loops)
        _interior_candidates!(labels, suppressed, :lat, [(crossings.lat_carrier, crossings.lat)], lines, fr, attrs)
        _interior_candidates!(labels, suppressed, :lon, crossings.lon, lines, fr, attrs)
    end
    return labels, suppressed
end

"""
    band_exits(exits, rect, minangle) -> Vector{Exit}

The exits that mark the frame for the `:fancy` band: the family that varies
along a straight edge (longitudes on horizontal viewport edges, latitudes on
vertical ones, whichever side the labels are on), both families elsewhere,
never a convergent pole point or a grazing exit.
"""
function band_exits(exits::Vector{Exit}, rect::Rect2d, minangle::Real)
    extent = max(maximum(widths(rect)), 1e-300)
    convergent = convergent_exits(exits, ON_FRAME_FRAC * extent; poletol = POLE_CONVERGE_FRAC * extent)
    return Exit[e for (k, e) in enumerate(exits) if admits(e, :both, :both) && !(k in convergent) && e.angle >= minangle]
end

function _edge_middle_distance(fr::Frame, e::Exit, extent)
    lp = fr.loops[e.loop]
    a = lp[e.edge]; b = lp[mod1(e.edge + 1, length(lp))]
    return norm(e.p - 0.5 * (a + b)) / extent
end

"""
    protrusion_bound(labels, visible; base = 0, ticks = nothing) -> RectSides{Float32}

Per side, the most any frame label pushes past its exit toward that side
(tick, pad and glyph box), taking the exit to sit on that side of the limits
rectangle, and at least `base` (the fancy band's width, which lies outside
the frame on every side).  Interior labels are on the map and reserve
nothing.  `visible` maps family to label visibility; `ticks` maps family to
`(size, align, visible)` so a tick stub still reserves its length when its
label is hidden.
"""
function protrusion_bound(labels::Vector{TickLabel}, visible; base::Real = 0.0, ticks = nothing)
    left = right = bottom = top = float(base)
    for l in labels
        isinterior(l) && continue
        tk = ticks === nothing ? nothing : ticks[l.exit.family]
        stub = (tk !== nothing && tk.visible) ? max(0.0, tk.size * (1 - tk.align)) : 0.0
        labelled = visible[l.exit.family]
        (labelled || stub > 0) || continue
        b = OBox(Point2d(0, 0), l.half, l.rotation)
        n = l.normal
        hn = half_extent(b, n)
        d = l.offset + hn
        for (comp, u) in ((-n[1], Vec2d(-1, 0)), (n[1], Vec2d(1, 0)), (-n[2], Vec2d(0, -1)), (n[2], Vec2d(0, 1)))
            comp > 0.1 || continue
            reach = max(labelled ? comp * d + half_extent(b, u) : 0.0, comp * stub)
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

"`1` when the map keeps its orientation in pixels (the map stays on the left of a frame loop), `-1` when it is mirrored."
function pixel_orientation(m::PixelMap)
    o = m(Point2d(0, 0))
    ux = m(Point2d(1, 0)) - o
    uy = m(Point2d(0, 1)) - o
    return ux[1] * uy[2] - ux[2] * uy[1] < 0 ? -1 : 1
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
family, per drawn frame label the pixel `position` handed to `text!` and its
string (`interior_positions` / `interior_strings` / `interior_rotations` for
the interior labels), the glyph `box`, exit and normal of every drawn label,
`kept` (indices into the level-3 labels, in label order), `suppressed` (the
level-4 drops), and the tick `stub` segments per family.
"""
struct Pixels
    frame::Vector{Vector{Point2d}}
    graticule::Dict{Symbol, Vector{Vector{Point2d}}}
    positions::Dict{Symbol, Vector{Point2d}}
    strings::Dict{Symbol, Vector{String}}
    interior_positions::Dict{Symbol, Vector{Point2d}}
    interior_strings::Dict{Symbol, Vector{String}}
    interior_rotations::Dict{Symbol, Vector{Float64}}
    boxes::Vector{OBox}
    exits::Vector{Point2d}
    normals::Vector{Vec2d}
    kept::Vector{Int}
    suppressed::Vector{Suppressed}
    stubs::Dict{Symbol, Vector{Point2d}}
end

"""
    pixels(frame, lines, labels, pv, viewport, ticks; mingap = 2, collisions = true) -> Pixels

`ticks` maps family to `(size, align, visible)`.  Labels are placed in
priority order; a frame box on the map is not drawn, an interior box off the
map is not drawn, and with `collisions` on a box within `mingap` pixels of an
already placed one is dropped.
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
        u = norm(l.normal) > 1e-300 ? pixel_direction(m, e.p, l.normal * (scale / norm(l.normal))) : Vec2d(0, 0)
        if isinterior(l)
            # on its line: the rotation follows the line as the pixel map draws it
            θ = l.auto_rotation ? tangent_rotation(pixel_direction(m, l.centre, l.normal * scale)) : l.rotation
            boxes[k] = OBox(m(l.centre), l.half, θ)
        else
            box0 = OBox(Point2d(0, 0), l.half, l.rotation)
            boxes[k] = OBox(Point2d(p + u * (l.offset + half_extent(box0, u))), l.half, l.rotation)
        end
        epx[k] = p; npx[k] = u
    end
    # the greedy pass, in priority order: the record it leaves is order-free
    kept = Int[]; suppressed = Suppressed[]
    for k in sortperm(labels; by = l -> l.priority)
        l = labels[k]
        if isinterior(l)
            # the one label allowed on the map must lie wholly on it
            if !box_within_loops(boxes[k], fpx)
                push!(suppressed, Suppressed(k, l.exit.family, l.exit.value, :outside, 0, :interior))
                continue
            end
        elseif box_inside_map(boxes[k], fpx)
            # a cut's outward side is the neighbouring lobe: a label that would sit on the map is not drawn
            push!(suppressed, Suppressed(k, l.exit.family, l.exit.value, :inside, 0))
            continue
        end
        if collisions
            hit = findfirst(j -> collides(boxes[j], boxes[k]; gap = mingap), kept)
            if hit !== nothing
                # the same tick on both sides of a cut is one label, not crowding
                h = labels[kept[hit]].exit
                reason = (h.family === l.exit.family && h.value == l.exit.value && !isinterior(l)) ? :duplicate : :collision
                push!(suppressed, Suppressed(k, l.exit.family, l.exit.value, reason, kept[hit], l.kind))
                continue
            end
        end
        push!(kept, k)
    end
    sort!(kept)
    sort!(suppressed; by = s -> s.index)
    positions = Dict{Symbol, Vector{Point2d}}(:lon => Point2d[], :lat => Point2d[])
    strings = Dict{Symbol, Vector{String}}(:lon => String[], :lat => String[])
    ipositions = Dict{Symbol, Vector{Point2d}}(:lon => Point2d[], :lat => Point2d[])
    istrings = Dict{Symbol, Vector{String}}(:lon => String[], :lat => String[])
    irotations = Dict{Symbol, Vector{Float64}}(:lon => Float64[], :lat => Float64[])
    for k in kept
        l = labels[k]
        if isinterior(l)
            # centred on its line, whatever the frame labels' alignment
            push!(ipositions[l.exit.family], boxes[k].centre)
            push!(istrings[l.exit.family], l.text)
            push!(irotations[l.exit.family], boxes[k].θ)
        else
            pos = l.auto_align ? boxes[k].centre : Point2d(epx[k] + npx[k] * l.offset)
            push!(positions[l.exit.family], pos)
            push!(strings[l.exit.family], l.text)
        end
    end
    # a tick marks every admitted exit that is not on the map, labelled or not
    stubs = Dict{Symbol, Vector{Point2d}}(:lon => Point2d[], :lat => Point2d[])
    done = Set{Tuple{Symbol, Float64, Int, Int}}()
    inside = Set{Int}(s.index for s in suppressed if s.reason === :inside)
    for k in 1:n
        k in inside && continue
        isinterior(labels[k]) && continue
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
    return Pixels(fpx, gpx, positions, strings, ipositions, istrings, irotations, boxes[kept], epx[kept], npx[kept], kept, suppressed, stubs)
end

# ---- the report -------------------------------------------------------------------

"""
    suppression_report(suppressed, mingap, minangle) -> Union{Nothing, String}

The crowding diagnostic: how many labels of each family were skipped for
collisions, for grazing exits, and for interior labels that found no place,
naming the attribute that controls each.  `nothing` when nothing was skipped
for any of these reasons.
"""
function suppression_report(suppressed::Vector{Suppressed}, mingap::Real, minangle::Real)
    clon = count(s -> s.reason === :collision && s.family === :lon, suppressed)
    clat = count(s -> s.reason === :collision && s.family === :lat, suppressed)
    graze = count(s -> s.reason === :grazing, suppressed)
    interior = count(s -> s.kind === :interior && s.reason in (:crossed, :outside), suppressed)
    parts = String[]
    (clon + clat) > 0 && push!(parts,
        "$clon longitude and $clat latitude labels skipped due to crowding; controlled by `ticklabelmingap`, currently $(float(mingap)) px")
    graze > 0 && push!(parts,
        "$graze labels skipped for leaving the frame at a grazing angle; controlled by `ticklabelminangle`, currently $(float(minangle))°")
    interior > 0 && push!(parts,
        "$interior interior labels skipped for finding no place on the map clear of other graticule lines; controlled by `carriermeridian`, `carrierparallel` and `interiorlabelsize`")
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
