#=
# The frame

The frame is the rim of the view, projected, and clipped to the viewport:

    frame = project(rim(view)) ∩ rect

Rim pieces are chained on the sphere by endpoint matching with provenance
(which primitive, which side of a seam), each loop is oriented with the map on
its left, projected piece by piece (every endpoint approached from inside its
arc, so poles and seams land on the right side), joined with straight `:pole`
edges where a pole line opens a gap, and finally clipped to the rect with
Sutherland–Hodgman, whose introduced edges are tagged `:viewport`.

Tags: `:limb` (projection limb / band edge / cutoff), `:limit` (a user limit),
`:cut` (seam / interruption), `:pole` (a pole line), `:viewport` (the rect).
=#

const FRAME_TAGS = (:limb, :limit, :cut, :pole, :viewport)
const DEDUP_FRAC = 1e-9                  # consecutive points closer than this × extent merge
const CHAIN_OPEN = Ref(0)                # loops that had to be closed blindly (diagnostic)

"""
    Frame

Closed loops in dest space.  `loops[i]` is an open point list (the last point
connects back to the first); `tags[i][j]` and `source[i][j]` describe the edge
from `loops[i][j]` to the next point: its tag and the rim primitive it came
from (`0` for introduced edges).
"""
struct Frame
    loops::Vector{Vector{Point2d}}
    tags::Vector{Vector{Symbol}}
    source::Vector{Vector{Int}}
end
Frame() = Frame(Vector{Point2d}[], Vector{Symbol}[], Vector{Int}[])

nloops(f::Frame) = length(f.loops)
nedges(f::Frame) = sum(length, f.loops; init = 0)
edge_tags(f::Frame) = reduce(vcat, f.tags; init = Symbol[])

"Every edge as `(a, b, tag, source)`."
function edges(f::Frame)
    out = Tuple{Point2d, Point2d, Symbol, Int}[]
    for (lp, tg, sc) in zip(f.loops, f.tags, f.source)
        n = length(lp)
        for j in 1:n
            push!(out, (lp[j], lp[mod1(j + 1, n)], tg[j], sc[j]))
        end
    end
    return out
end

"NaN-separated closed loops, ready for `lines!`."
function spine_points(f::Frame)
    out = Point2d[]
    for lp in f.loops
        isempty(lp) && continue
        isempty(out) || push!(out, Point2d(NaN, NaN))
        append!(out, lp)
        push!(out, lp[1])
    end
    return out
end

# ---- chaining on the sphere ------------------------------------------------

_endpoint(piece::RimPiece, at::Int) = arcpoint(piece.arc, at == 1 ? piece.arc.t0 : piece.arc.t1)
_isseam(piece::RimPiece) = piece.side != 0
"The seam plane normal of a cut piece before its `SEAM_EPS` rotation (half-meridians keep `u` = wedge axis)."
_unrotated_normal(piece::RimPiece) = Vec3d(rotation_about(piece.arc.u, -piece.side * SEAM_EPS) * piece.arc.axis)
_at_axis(piece::RimPiece, p) = abs(_dot3(p, piece.arc.u)) >= 1 - 1e-9

"""
    _link_score(a, p, b, q) -> Union{Nothing, Tuple{Float64, Int}}

Whether the end `p` of piece `a` may chain to the end `q` of piece `b`, and
how good the link is: `(distance + penalty, rank)`, lower is better.
"""
function _link_score(a::RimPiece, p, b::RimPiece, q)
    d = angular_distance(p, q)
    d > CHAIN_TOL && return nothing
    sa, sb = _isseam(a), _isseam(b)
    if sa && sb
        if a.part == b.part
            a.side == b.side && return (d, 1)
            (_at_axis(a, p) && _at_axis(b, q)) || return nothing
            return (d, 0)
        end
        abs(_dot3(a.arc.axis, b.arc.axis)) > 1 - 1e-12 && return (d, 1)
        na, nb = _unrotated_normal(a), _unrotated_normal(b)
        abs(_dot3(na, nb)) > 1 - 1e-12 && return (d + 0.25 * CHAIN_TOL, 2)
        return nothing
    elseif sa || sb
        seam, po = sa ? (a, q) : (b, p)
        s = _dot3(po, _unrotated_normal(seam))
        abs(s) < 1e-12 && return (d, 3)
        sign(s) == seam.side || return nothing
        return (d, 1)
    end
    return (d, 1)
end

_score_key(sc) = (round(sc[1]; digits = 8), sc[2])

"""
    chain_pieces(pieces) -> Vector{Vector{Tuple{Int, Bool}}}

Closed chains of `(piece index, reversed)`; full circles are their own loops.
"""
function chain_pieces(pieces::Vector{RimPiece})
    chains = Vector{Tuple{Int, Bool}}[]
    used = falses(length(pieces))
    for (i, piece) in enumerate(pieces)
        if isfull(piece.arc)
            used[i] = true
            push!(chains, [(i, false)])
        end
    end
    while !all(used)
        start = findfirst(!, used)
        used[start] = true
        chain = [(start, false)]
        head = _endpoint(pieces[start], 1)          # the loop's first point
        cur_piece = pieces[start]
        cur = _endpoint(cur_piece, 2)
        while true
            best = nothing; best_key = nothing; best_rev = false
            for j in eachindex(pieces)
                used[j] && continue
                for at in (1, 2)
                    sc = _link_score(cur_piece, cur, pieces[j], _endpoint(pieces[j], at))
                    sc === nothing && continue
                    key = _score_key(sc)
                    if best_key === nothing || key < best_key
                        best, best_key, best_rev = j, key, at == 2
                    end
                end
            end
            close_sc = _link_score(cur_piece, cur, pieces[start], head)
            if close_sc !== nothing && length(chain) > 1
                ck = _score_key(close_sc)
                (best_key === nothing || ck <= best_key) && break
            end
            best === nothing && (CHAIN_OPEN[] += 1; break)
            used[best] = true
            push!(chain, (best, best_rev))
            cur_piece = pieces[best]
            cur = _endpoint(cur_piece, best_rev ? 1 : 2)
        end
        push!(chains, chain)
    end
    return chains
end

# ---- orientation on the sphere ---------------------------------------------

"Is the map on the left of this chain as traversed?  `nothing` when no piece can tell."
function _interior_on_left(chain, pieces, view)
    for (idx, rev) in chain
        piece = pieces[idx]
        if _isseam(piece)
            return (piece.side == 1) != rev
        end
        a = piece.arc
        tm = 0.5 * (a.t0 + a.t1)
        m = arcpoint(a, tm)
        τ = arc_tangent(a, tm)
        rev && (τ = -τ)
        left = _cross3(m, τ)
        ql = _unit3(m + ORIENT_NUDGE * left)
        qr = _unit3(m - ORIENT_NUDGE * left)
        cl, cr = contains(view, ql), contains(view, qr)
        cl != cr && return cl
    end
    return nothing
end

# ---- assembly in dest space -------------------------------------------------

function _assemble(chain, pieces, t, tol)
    pts = Point2d[]; tags = Symbol[]; src = Int[]
    for (idx, rev) in chain
        piece = pieces[idx]
        pp = adaptive_project(t, piece.arc; tol)
        rev && reverse!(pp)
        isempty(pp) && continue
        if !isempty(pts)
            gap = norm(pp[1] - pts[end])
            push!(tags, gap > tol ? :pole : piece.tag)
            push!(src, gap > tol ? 0 : piece.part)
        end
        append!(pts, pp)
        for _ in 1:(length(pp) - 1)
            push!(tags, piece.tag); push!(src, piece.part)
        end
    end
    isempty(pts) && return (pts, tags, src)
    gap = norm(pts[end] - pts[1])
    push!(tags, gap > tol ? :pole : (isempty(tags) ? pieces[chain[1][1]].tag : tags[end]))
    push!(src, gap > tol ? 0 : (isempty(src) ? pieces[chain[1][1]].part : src[end]))
    return (pts, tags, src)
end

function _dedup!(pts, tags, src, eps)
    i = 1
    while i <= length(pts) && length(pts) > 1
        j = mod1(i + 1, length(pts))
        if norm(pts[j] - pts[i]) <= eps
            if j < i
                # the last point repeats the first: drop it and its closing edge
                deleteat!(pts, i); deleteat!(tags, i); deleteat!(src, i)
            else
                # drop the repeated point and the zero-length edge leading to it
                deleteat!(pts, j); deleteat!(tags, i); deleteat!(src, i)
            end
        else
            i += 1
        end
    end
    return
end

_signed_area(pts) = 0.5 * sum(pts[i][1] * pts[mod1(i + 1, end)][2] - pts[mod1(i + 1, end)][1] * pts[i][2] for i in eachindex(pts); init = 0.0)

function _reverse_loop!(pts, tags, src)
    # after reversing the points, the edge leaving new point k is old edge n-k
    n = length(pts)
    reverse!(pts)
    tags .= [tags[mod1(n - k, n)] for k in 1:n]
    src .= [src[mod1(n - k, n)] for k in 1:n]
    return
end

# ---- clipping ---------------------------------------------------------------

function _sh_clip(pts, tags, src, rect::Rect2d, eps::Real = 0.0)
    x0, y0 = minimum(rect); x1, y1 = maximum(rect)
    poly = [(pts[i], tags[i], src[i]) for i in eachindex(pts)]
    for side in 1:4
        isempty(poly) && break
        inside(p) = side == 1 ? p[1] >= x0 - eps : side == 2 ? p[1] <= x1 + eps : side == 3 ? p[2] >= y0 - eps : p[2] <= y1 + eps
        function isect(p, q)
            if side <= 2
                x = side == 1 ? x0 : x1
                s = (x - p[1]) / (q[1] - p[1])
                return Point2d(x, p[2] + s * (q[2] - p[2]))
            else
                y = side == 3 ? y0 : y1
                s = (y - p[2]) / (q[2] - p[2])
                return Point2d(p[1] + s * (q[1] - p[1]), y)
            end
        end
        out = similar(poly, 0)
        n = length(poly)
        for i in 1:n
            S, tagS, srcS = poly[i]
            E, tagE, srcE = poly[mod1(i + 1, n)]
            if inside(E)
                inside(S) || push!(out, (isect(S, E), tagS, srcS))
                push!(out, (E, tagE, srcE))
            elseif inside(S)
                push!(out, (isect(S, E), :viewport, 0))
            end
        end
        poly = out
    end
    return (Point2d[p[1] for p in poly], Symbol[p[2] for p in poly], Int[p[3] for p in poly])
end

"Even-odd point-in-polygon in the plane."
function _pip(pts, q)
    inside = false
    n = length(pts)
    for i in 1:n
        a, b = pts[i], pts[mod1(i + 1, n)]
        if (a[2] > q[2]) != (b[2] > q[2])
            x = a[1] + (q[2] - a[2]) / (b[2] - a[2]) * (b[1] - a[1])
            x > q[1] && (inside = !inside)
        end
    end
    return inside
end

_rect_loop(rect::Rect2d) = (
    Point2d[Point2d(minimum(rect)[1], minimum(rect)[2]), Point2d(maximum(rect)[1], minimum(rect)[2]),
            Point2d(maximum(rect)[1], maximum(rect)[2]), Point2d(minimum(rect)[1], maximum(rect)[2])],
    fill(:viewport, 4), fill(0, 4))

"The set of rect sides (bits 1..4: left, right, bottom, top) `p` lies on within `tol`."
function _rect_sides(p, rect::Rect2d, tol)
    x0, y0 = minimum(rect); x1, y1 = maximum(rect)
    m = 0
    abs(p[1] - x0) <= tol && (m |= 1)
    abs(p[1] - x1) <= tol && (m |= 2)
    abs(p[2] - y0) <= tol && (m |= 4)
    abs(p[2] - y1) <= tol && (m |= 8)
    return m
end

"""
    viewport_retag!(frame, rect, tol)

A `:limit` primitive whose every edge lies along the rect boundary is the
viewport: retag those edges `:viewport`.
"""
function viewport_retag!(f::Frame, rect::Rect2d, tol)
    parts = Set{Int}()
    for (lp, tg, sc) in zip(f.loops, f.tags, f.source), j in eachindex(lp)
        tg[j] == :limit && push!(parts, sc[j])
    end
    for part in parts
        allon = true
        for (lp, tg, sc) in zip(f.loops, f.tags, f.source), j in eachindex(lp)
            (tg[j] == :limit && sc[j] == part) || continue
            common = _rect_sides(lp[j], rect, tol) & _rect_sides(lp[mod1(j + 1, length(lp))], rect, tol)
            common != 0 || (allon = false; break)
        end
        allon || continue
        for (lp, tg, sc) in zip(f.loops, f.tags, f.source), j in eachindex(lp)
            (tg[j] == :limit && sc[j] == part) && (tg[j] = :viewport)
        end
    end
    return f
end

"Merge runs of collinear edges that share a tag and source, so a straight side is one edge."
function _merge_collinear!(pts, tags, src, eps)
    i = 1
    while length(pts) > 3 && i <= length(pts)
        n = length(pts)
        h, j = mod1(i - 1, n), mod1(i + 1, n)
        a, b, c = pts[h], pts[i], pts[j]
        if tags[h] == tags[i] && src[h] == src[i]
            ab = b - a; bc = c - b
            cross = ab[1] * bc[2] - ab[2] * bc[1]
            if abs(cross) <= eps * (norm(ab) + norm(bc)) && ab[1] * bc[1] + ab[2] * bc[2] >= 0
                deleteat!(pts, i); deleteat!(tags, i); deleteat!(src, i)
                continue
            end
        end
        i += 1
    end
    return
end

# ---- the frame ---------------------------------------------------------------

"""
    RimLoops

The projected, oriented, unclipped rim of a view: closed loops in dest space
with per-edge tags and sources, and their bounding box (`nothing` for a
rimless view).  `clip_frame` turns this into a `Frame` for any viewport.
"""
struct RimLoops
    loops::Vector{Vector{Point2d}}
    tags::Vector{Vector{Symbol}}
    source::Vector{Vector{Int}}
    bbox::Union{Rect2d, Nothing}
end
RimLoops() = RimLoops(Vector{Point2d}[], Vector{Symbol}[], Vector{Int}[], nothing)

"""
    project_rim(view, t; tol) -> RimLoops

Chain the rim of `view` on the sphere, orient every loop with the map on its
left, and project it to dest space with chord tolerance `tol` (defaults to a
thousandth of the extent of a dense first pass).
"""
function project_rim(view::SphereRegion, t; tol::Union{Real, Nothing} = nothing)
    pieces = rim(view)
    isempty(pieces) && return RimLoops()
    if tol === nothing
        dense = rim_bbox(view, t)
        dense === nothing && return RimLoops()
        tol = frame_tolerance(dense)
    end
    chains = chain_pieces(pieces)
    loops = Vector{Point2d}[]; tags = Vector{Symbol}[]; srcs = Vector{Int}[]
    for chain in chains
        left = _interior_on_left(chain, pieces, view)
        if left === false
            chain = [(idx, !rev) for (idx, rev) in reverse(chain)]
        end
        pts, tg, sc = _assemble(chain, pieces, t, tol)
        length(pts) >= 2 || continue
        push!(loops, pts); push!(tags, tg); push!(srcs, sc)
    end
    isempty(loops) && return RimLoops()
    allpts = reduce(vcat, loops)
    bbox = _bbox([p[1] for p in allpts], [p[2] for p in allpts])
    extent = max(maximum(widths(bbox)), 1e-300)
    for k in eachindex(loops)
        _dedup!(loops[k], tags[k], srcs[k], DEDUP_FRAC * extent)
    end
    # the map is on the left of every loop; a reflecting projection flips all of them
    if sum(_signed_area, loops; init = 0.0) < 0
        for k in eachindex(loops)
            _reverse_loop!(loops[k], tags[k], srcs[k])
        end
    end
    return RimLoops(loops, tags, srcs, bbox)
end

"""
    clip_frame(rl::RimLoops, rect; tol) -> Frame

Clip projected rim loops to `rect`.  A rimless view's frame is the rect; a loop
that surrounds the rect without touching it contributes to a winding count that
decides whether the rect itself is the frame.
"""
function clip_frame(rl::RimLoops, rect::Rect2d; tol::Real = frame_tolerance(rect))
    if isempty(rl.loops)
        rp = _rect_loop(rect)
        return rl.bbox === nothing ? Frame([rp[1]], [rp[2]], [rp[3]]) : Frame()
    end
    extent = max(maximum(widths(rl.bbox)), maximum(widths(rect)), 1e-300)
    out = Frame()
    centre = Point2d(minimum(rect) .+ 0.5 .* widths(rect))
    rectpts = _rect_loop(rect)[1]
    covers = 0
    for k in eachindex(rl.loops)
        cp, ct, cs = _sh_clip(rl.loops[k], rl.tags[k], rl.source[k], rect, DEDUP_FRAC * extent)
        isempty(cp) && continue
        if all(==(:viewport), ct) && !any(p -> _pip(rectpts, p), rl.loops[k])
            # no vertex inside the rect and only introduced edges survive: the
            # loop surrounds the rect (or misses it)
            _pip(rl.loops[k], centre) && (covers += 1)
            continue
        end
        _dedup!(cp, ct, cs, DEDUP_FRAC * extent)
        length(cp) >= 2 || continue
        push!(out.loops, cp); push!(out.tags, ct); push!(out.source, cs)
    end
    if isodd(covers)
        rp = _rect_loop(rect)
        push!(out.loops, rp[1]); push!(out.tags, rp[2]); push!(out.source, rp[3])
    end
    viewport_retag!(out, rect, tol)
    for k in eachindex(out.loops)
        _merge_collinear!(out.loops[k], out.tags[k], out.source[k], DEDUP_FRAC * extent)
    end
    return out
end

"""
    frame(view, t, rect; tol = frame_tolerance(rect)) -> (Frame, bbox)

The frame of `view` under `t` clipped to `rect`, and the bounding box of the
unclipped projected rim (`nothing` for a rimless view, whose frame is the rect).
"""
function frame(view::SphereRegion, t, rect::Rect2d; tol::Real = frame_tolerance(rect))
    rl = project_rim(view, t; tol)
    return (clip_frame(rl, rect; tol), rl.bbox)
end
