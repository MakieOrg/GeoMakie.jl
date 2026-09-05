#=
# The spine and the fancy band

The spine is the frame drawn as a stroke, in the block scene in pixel space
(as Makie's `Axis` draws its spines), so the whole stroke is visible where the
frame lies on the axis scene's clip edge.

`framestyle = :fancy` adds GMT's alternating band outside the spine: the frame
polyline is swept, and each stretch between two consecutive tick exits is a
strip of `framewidth` pixels offset outward, coloured in turn from
`framecolors`.  Curved frames get a band too.  Two colours cannot alternate
around a loop with an odd number of exits, so the closing band is split at its
middle; that one boundary is not at an exit and is recorded as such.
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

The fancy band in pixels: one polygon and colour per band, the loop each band
lies on, per loop the band boundaries in sweep order (band `i` of a loop runs
from its boundary `i` to the next, wrapping), and per loop the index of the
boundary added to keep the colours alternating (`0` when none was needed).
"""
struct FrameBands
    polygons::Vector{Vector{Point2d}}
    colors::Vector{RGBAf}
    loop::Vector{Int}
    boundaries::Vector{Vector{Point2d}}
    extra::Vector{Int}
end
FrameBands() = FrameBands(Vector{Point2d}[], RGBAf[], Int[], Vector{Point2d}[], Int[])

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
bands meeting at a corner leave no gap.
"""
function _band_polygon(lp::Vector{Point2d}, cum, s0::Real, s1::Real, width::Real, outward::Int)
    n = length(lp)
    L = cum[n + 1]
    inner = Point2d[]; outer = Point2d[]
    s0 = mod(s0, L)
    d = mod(s1 - s0, L)
    s1 = s0 + (d > 0 ? d : L)      # a whole turn is one band
    p0, j0, v0 = _point_at(lp, cum, s0)
    push!(inner, p0)
    if v0
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

"""
    frame_bands(loops, exits, width, colors; outward = 1) -> FrameBands

Sweep each frame loop (pixel points, the map on its left when `outward == 1`
and on its right when `-1`) into bands between consecutive exits.  `exits` are
`(loop, edge, point)` in pixels; exits within `BAND_MERGE_PX` of each other
along the loop are one boundary.  A loop with no exit is one band.
"""
function frame_bands(loops::Vector{Vector{Point2d}}, exits, width::Real, colors::Vector{RGBAf}; outward::Int = 1)
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
        bounds = Float64[]
        for s in ss
            (isempty(bounds) || s - bounds[end] > BAND_MERGE_PX) && push!(bounds, s)
        end
        length(bounds) >= 2 && bounds[1] + L - bounds[end] <= BAND_MERGE_PX && pop!(bounds)
        extra = 0
        if isempty(bounds)
            push!(bounds, 0.0); extra = 1
        elseif length(bounds) >= 2 && (length(bounds) - 1) % nc == 0
            # the closing band would share its colour with the first: split it
            sx = mod(0.5 * (bounds[end] + bounds[1] + L), L)
            push!(bounds, sx); sort!(bounds)
            extra = findfirst(==(sx), bounds)
        end
        m = length(bounds)
        pts = Point2d[]
        for i in 1:m
            s0 = bounds[i]
            s1 = i < m ? bounds[i + 1] : bounds[1] + L
            push!(out.polygons, _band_polygon(lp, cum, s0, s1, width, outward))
            push!(out.colors, colors[mod1(i, nc)])
            push!(out.loop, k)
            push!(pts, _point_at(lp, cum, s0)[1])
        end
        push!(out.boundaries, pts)
        push!(out.extra, extra)
    end
    return out
end
