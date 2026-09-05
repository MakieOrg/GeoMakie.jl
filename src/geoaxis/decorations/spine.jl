#=
# The spine and the fancy band

The spine is the frame drawn as a stroke, in the block scene in pixel space
(as Makie's `Axis` draws its spines), so the whole stroke is visible where the
frame lies on the axis scene's clip edge.

`framestyle = :fancy` adds GMT's alternating band outside the spine: the frame
polyline is swept, and each stretch between two consecutive tick exits is a
strip of `framewidth` pixels offset outward, coloured in turn from
`framecolors`.  Curved frames get a band too.

GMT's rule (gmt_plot.c, `gmtplot_fancy_frame_*`) is that each side of the
frame is segmented on its own and the corners are separate cells.  Here a
"run" is a maximal stretch of consecutive frame edges with one tag and one
source (a straight pole line, a viewport side, one limit arc, one limb or cut
arc); the colours restart at every run, and at every run boundary a corner
cell, the square of `framewidth` at the vertex offset outward like the bands,
is drawn in the background colour so two runs never touch.  A loop that is a
single run (an orthographic limb, a polar limit circle) has no corners and
alternates all the way round; two colours cannot alternate around an odd
number of exits, so its closing band is split at the middle, and that one
boundary is not at an exit and is recorded as such.
=#

const BAND_MERGE_PX = 1.0       # band boundaries closer than this are one boundary
const MITER_LIMIT = 2.0         # the offset at a sharp corner is capped at this many band widths

"Closed loops as one NaN-separated polyline for `lines!`."
function closed_polylines(loops::Vector{Vector{Point2d}})
    out = Point2d[]
    for lp in loops
        isempty(lp) && continue
        isempty(out) || push!(out, Point2d(NaN, NaN))
        append!(out, lp)
        push!(out, lp[1])
    end
    return out
end

"""
    FrameBands

The fancy band in pixels: one polygon and colour per band, the loop and the
run (numbered along the loop) each band lies on, per loop the band boundaries
in sweep order (band `i` of a loop runs from its boundary `i` to the next,
wrapping; every run corner is a boundary), and per loop the index of the
boundary added to keep the colours alternating around a single-run loop (`0`
when none was needed).  `corners` are the frame vertices where one run ends
and the next begins, `cells` the corner cell polygon at each of them, and
`cell_loop` the loop each corner is on.
"""
struct FrameBands
    polygons::Vector{Vector{Point2d}}
    colors::Vector{RGBAf}
    loop::Vector{Int}
    run::Vector{Int}
    boundaries::Vector{Vector{Point2d}}
    extra::Vector{Int}
    corners::Vector{Point2d}
    cells::Vector{Vector{Point2d}}
    cell_loop::Vector{Int}
end
FrameBands() = FrameBands(Vector{Point2d}[], RGBAf[], Int[], Int[], Vector{Point2d}[], Int[], Point2d[], Vector{Point2d}[], Int[])

"Cumulative arc length along the closed loop: `cum[j]` up to `lp[j]`, `cum[n + 1]` the whole loop."
function _cumulative_length(lp::Vector{Point2d})
    n = length(lp)
    cum = zeros(n + 1)
    for j in 1:n
        cum[j + 1] = cum[j] + norm(lp[mod1(j + 1, n)] - lp[j])
    end
    return cum
end

const VERTEX_SNAP_PX = 1e-6     # a boundary this close to a frame vertex is at the vertex

"""
    _point_at(lp, cum, s) -> (point, edge, atvertex)

The point at arc length `s` (taken modulo the loop's length), the edge it is
on, and whether it is that edge's first vertex (within `VERTEX_SNAP_PX`, so a
tick on a frame corner is treated as the corner).
"""
function _point_at(lp::Vector{Point2d}, cum, s::Real)
    n = length(lp)
    L = cum[n + 1]
    s = mod(s, L)
    j = clamp(searchsortedlast(cum, s), 1, n)
    len = cum[j + 1] - cum[j]
    if len - (s - cum[j]) <= VERTEX_SNAP_PX
        j = mod1(j + 1, n)
        return lp[j], j, true
    end
    s - cum[j] <= VERTEX_SNAP_PX && return lp[j], j, true
    t = len > 0 ? (s - cum[j]) / len : 0.0
    return Point2d(lp[j] + (lp[mod1(j + 1, n)] - lp[j]) * t), j, false
end

"The outward offset of vertex `j` by `width`: along the miter of its two edges, capped at `MITER_LIMIT` widths."
function _miter_offset(lp::Vector{Point2d}, j::Int, width::Real, outward::Int)
    n = length(lp)
    nprev = _edge_normal(lp, mod1(j - 1, n), outward)
    nnext = _edge_normal(lp, j, outward)
    m = nprev + nnext
    nm = norm(m)
    dir = nm > 1e-12 ? m / nm : nnext
    cosh = max(dir[1] * nnext[1] + dir[2] * nnext[2], 1 / MITER_LIMIT)
    return Point2d(lp[j] + dir * (width / cosh))
end

"Drop consecutive repeated points of a ring (the last against the first too)."
function _dedup_ring!(pts::Vector{Point2d})
    i = 1
    while length(pts) > 1 && i <= length(pts)
        j = mod1(i + 1, length(pts))
        if norm(pts[j] - pts[i]) <= VERTEX_SNAP_PX
            deleteat!(pts, j)
        else
            i += 1
        end
    end
    return pts
end

"Outward unit normal of edge `j` of the loop; `outward` is `±1` for the map on the left / right."
function _edge_normal(lp::Vector{Point2d}, j::Int, outward::Int)
    n = length(lp)
    e = lp[mod1(j + 1, n)] - lp[j]
    ne = norm(e)
    ne <= 1e-300 && return Vec2d(0, 0)
    return Vec2d(e[2], -e[1]) * (outward / ne)
end

"""
    _band_polygon(lp, cum, s0, s1, width, outward) -> Vector{Point2d}

The strip along the loop from arc length `s0` to `s1` (`s1 > s0`, possibly
past the loop's length), offset outward by `width`: the inner polyline
followed by the outer one reversed.  Interior vertices are offset along the
miter of their two edges.  A band starting on a frame vertex owns the corner
square there (the band ending on it stops flush with its own edge), so two
bands meeting at a corner leave no gap; with `corner_start` the starting band
stops flush with its own edge too, leaving the corner to a corner cell.
"""
function _band_polygon(lp::Vector{Point2d}, cum, s0::Real, s1::Real, width::Real, outward::Int; corner_start::Bool = false)
    n = length(lp)
    L = cum[n + 1]
    inner = Point2d[]; outer = Point2d[]
    s0 = mod(s0, L)
    d = mod(s1 - s0, L)
    s1 = s0 + (d > 0 ? d : L)      # a whole turn is one band
    p0, j0, v0 = _point_at(lp, cum, s0)
    push!(inner, p0)
    if v0 && !corner_start
        push!(outer, p0 + _edge_normal(lp, mod1(j0 - 1, n), outward) * width)
        push!(outer, _miter_offset(lp, j0, width, outward))
    else
        push!(outer, p0 + _edge_normal(lp, j0, outward) * width)
    end
    # every vertex strictly inside (s0, s1), in sweep order; the range may wrap the loop once
    j = j0
    snext = cum[j0 + 1]             # the first vertex past s0 (a start snapped to vertex 1 may sit at ≈ L)
    snext <= s0 && (snext += L)
    while snext < s1 - VERTEX_SNAP_PX
        j = mod1(j + 1, n)
        push!(inner, lp[j]); push!(outer, _miter_offset(lp, j, width, outward))
        snext += cum[j + 1] - cum[j]
    end
    p1, j1, v1 = _point_at(lp, cum, s1)
    push!(inner, p1)
    push!(outer, p1 + _edge_normal(lp, v1 ? mod1(j1 - 1, n) : j1, outward) * width)
    return _dedup_ring!(vcat(inner, reverse!(outer)))
end

const STRAIGHT_TAGS = (:viewport, :pole)   # tags whose edges are straight lines: every turn between two of them is a corner
const RUN_TURN_DEG = 1.0                    # a junction turning less than this is not a corner

"Degrees the loop turns at vertex `j`."
function _turn_deg(lp::Vector{Point2d}, j::Int)
    n = length(lp)
    a = lp[j] - lp[mod1(j - 1, n)]
    b = lp[mod1(j + 1, n)] - lp[j]
    na, nb = norm(a), norm(b)
    (na <= 1e-300 || nb <= 1e-300) && return 0.0
    return acosd(clamp((a[1] * b[1] + a[2] * b[2]) / (na * nb), -1.0, 1.0))
end

"""
    run_corners(loop, tags, sources) -> Vector{Int}

The vertices of a loop where one run ends and the next begins: the tag or
source changes across the vertex, or a straight edge meets another edge, and
the loop turns there by more than `RUN_TURN_DEG`.  Empty for a loop that is a
single run.
"""
function run_corners(lp::Vector{Point2d}, tags::Vector{Symbol}, srcs::Vector{Int})
    n = length(lp)
    out = Int[]
    n >= 2 || return out
    for j in 1:n
        h = mod1(j - 1, n)
        boundary = tags[h] !== tags[j] || srcs[h] != srcs[j] || tags[j] in STRAIGHT_TAGS || tags[h] in STRAIGHT_TAGS
        (boundary && _turn_deg(lp, j) > RUN_TURN_DEG) && push!(out, j)
    end
    return out
end

"The corner cell at vertex `j`: the vertex, the two band ends beside it, and the miter point between them."
function _corner_cell(lp::Vector{Point2d}, j::Int, width::Real, outward::Int)
    n = length(lp)
    v = lp[j]
    n1 = _edge_normal(lp, mod1(j - 1, n), outward)
    n2 = _edge_normal(lp, j, outward)
    return _dedup_ring!(Point2d[v, v + n1 * width, _miter_offset(lp, j, width, outward), v + n2 * width])
end

"""
    frame_bands(loops, tags, sources, exits, width, colors; outward = 1) -> FrameBands

Sweep each frame loop (pixel points, the map on its left when `outward == 1`
and on its right when `-1`) into bands between consecutive exits, the colours
restarting at every run corner (see `run_corners`; `tags` and `sources` are
the frame's, per edge).  `exits` are `(loop, edge, point)` in pixels; exits
within `BAND_MERGE_PX` of each other, or of a corner, along the loop are one
boundary.  A run with no exit is one band.
"""
function frame_bands(loops::Vector{Vector{Point2d}}, tags::Vector{Vector{Symbol}}, srcs::Vector{Vector{Int}},
                     exits, width::Real, colors::Vector{RGBAf}; outward::Int = 1)
    out = FrameBands()
    nc = length(colors)
    (nc >= 1 && width > 0) || return out
    for (k, lp) in enumerate(loops)
        n = length(lp)
        n >= 2 || continue
        cum = _cumulative_length(lp)
        L = cum[n + 1]
        L > 0 || continue
        ss = Float64[]
        for (loop, edge, p) in exits
            loop == k || continue
            push!(ss, cum[edge] + min(norm(p - lp[edge]), cum[edge + 1] - cum[edge]))
        end
        sort!(ss)
        corners = run_corners(lp, tags[k], srcs[k])
        bounds = Float64[]; runs = Int[]; starts = Bool[]
        extra = 0
        if isempty(corners)
            for s in ss
                (isempty(bounds) || s - bounds[end] > BAND_MERGE_PX) && push!(bounds, s)
            end
            length(bounds) >= 2 && bounds[1] + L - bounds[end] <= BAND_MERGE_PX && pop!(bounds)
            if isempty(bounds)
                push!(bounds, 0.0); extra = 1
            elseif length(bounds) >= 2 && (length(bounds) - 1) % nc == 0
                # the closing band would share its colour with the first: split it
                sx = mod(0.5 * (bounds[end] + bounds[1] + L), L)
                push!(bounds, sx); sort!(bounds)
                extra = findfirst(==(sx), bounds)
            end
            runs = ones(Int, length(bounds)); starts = falses(length(bounds))
        else
            cs = [cum[j] for j in corners]
            for r in eachindex(cs)
                sa = cs[r]
                sb = r < length(cs) ? cs[r + 1] : cs[1] + L
                push!(bounds, sa); push!(runs, r); push!(starts, true)
                # the exits of this run, in sweep order (the last run wraps past the loop's end)
                for s in sort!([s < sa ? s + L : s for s in ss])
                    (s - bounds[end] > BAND_MERGE_PX && sb - s > BAND_MERGE_PX) || continue
                    push!(bounds, s); push!(runs, r); push!(starts, false)
                end
            end
        end
        m = length(bounds)
        pts = Point2d[]
        pos = 0
        for i in 1:m
            s0 = bounds[i]
            s1 = i < m ? bounds[i + 1] : bounds[1] + L
            pos = starts[i] ? 1 : pos + 1
            push!(out.polygons, _band_polygon(lp, cum, s0, s1, width, outward; corner_start = starts[i]))
            push!(out.colors, colors[mod1(pos, nc)])
            push!(out.loop, k)
            push!(out.run, runs[i])
            push!(pts, _point_at(lp, cum, s0)[1])
        end
        push!(out.boundaries, pts)
        push!(out.extra, extra)
        for j in corners
            push!(out.corners, lp[j])
            push!(out.cells, _corner_cell(lp, j, width, outward))
            push!(out.cell_loop, k)
        end
    end
    return out
end

"A sweep with every loop a single run (no tags): alternation is continuous around each loop."
function frame_bands(loops::Vector{Vector{Point2d}}, exits, width::Real, colors::Vector{RGBAf}; outward::Int = 1)
    tags = [fill(:limb, length(lp)) for lp in loops]
    srcs = [ones(Int, length(lp)) for lp in loops]
    return frame_bands(loops, tags, srcs, exits, width, colors; outward)
end
