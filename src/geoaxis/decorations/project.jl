#=
# Projecting arcs into dest space

The only place the decorations call PROJ.  Arcs are sampled adaptively (chord
deviation in dest units) and every endpoint is projected from a hair inside the
arc: a pole has no longitude and a seam point has two, so what the endpoint
projects to depends on the direction it is approached from, and the arc is the
thing that knows the direction.
=#

const ENDPOINT_NUDGE = 1e-7        # rad; how far inside an arc its endpoints are projected from
const SEED_SEGMENT_DEG = 10.0      # initial sampling of an arc before refinement
const SEED_SEGMENTS = (2, 64)
const MIN_DEPTH = 2
const MAX_DEPTH = 12
const TOL_FRACTION = 1e-3          # dest tolerance as a fraction of the extent

"""
    project_lonlat(t, lon, lat) -> Point2d

Forward projection of one lon/lat point; `NaN` when the projection refuses.
Every PROJ call made by the decorations goes through here.
"""
function project_lonlat(t, lon::Real, lat::Real)
    q = try
        Makie.apply_transform(t, Point2d(lon, lat))
    catch
        return Point2d(NaN, NaN)
    end
    return Point2d(q[1], q[2])
end

function project_point(t, p)
    lon, lat = xyz_to_lonlat(p)
    return project_lonlat(t, lon, lat)
end

"""
    project_on_arc(t, arc, tt, toward; tol = 0.0) -> Point2d

The projection of `arcpoint(arc, tt)`.  The point is also projected from a hair
inside the arc (`toward` is `+1` for increasing parameter, `-1` for decreasing);
when the two disagree by more than `tol` the endpoint is singular (a pole, a
seam) and the approach from inside wins.  Nudges further in when the
projection refuses the endpoint itself.
"""
function project_on_arc(t, arc::CircleArc, tt::Real, toward::Integer; tol::Real = 0.0)
    s = max(sinrad(arc), 1e-6)
    span = abs(arc.t1 - arc.t0)
    exact = project_point(t, arcpoint(arc, tt))
    for k in 0:5
        δ = min(ENDPOINT_NUDGE * 10.0^k / s, 0.5 * span)
        p = project_point(t, arcpoint(arc, tt + toward * δ))
        if _finite2(p)
            (_finite2(exact) && norm(p - exact) <= tol) && return exact
            return p
        end
    end
    return exact
end

_seed_segments(arc::CircleArc) = clamp(ceil(Int, arclength(arc) / deg2rad(SEED_SEGMENT_DEG)), SEED_SEGMENTS...)

"""
    adaptive_project(t, arc; tol, max_depth = MAX_DEPTH, min_depth = MIN_DEPTH, dropnan = true) -> Vector{Point2d}

Dest-space polyline of `arc` in the direction of increasing parameter, refined
until the chord midpoint deviation is under `tol`.  Non-finite samples are
dropped unless `dropnan = false`, which keeps them as `NaN` breaks.
"""
function adaptive_project(t, arc::CircleArc; tol::Real, max_depth::Integer = MAX_DEPTH, min_depth::Integer = MIN_DEPTH, dropnan::Bool = true)
    n = _seed_segments(arc)
    ts = range(arc.t0, arc.t1; length = n + 1)
    ps = Vector{Point2d}(undef, n + 1)
    for i in 1:(n + 1)
        ps[i] = i == 1 ? project_on_arc(t, arc, ts[1], 1; tol) :
                i == n + 1 ? project_on_arc(t, arc, ts[end], -1; tol) :
                project_point(t, arcpoint(arc, ts[i]))
    end
    out = Point2d[ps[1]]
    for i in 1:n
        _refine!(out, t, arc, ts[i], ps[i], ts[i + 1], ps[i + 1], float(tol), 0, max_depth, min_depth)
        push!(out, ps[i + 1])
    end
    return dropnan ? filter(_finite2, out) : out
end

function _refine!(out, t, arc, ta, pa, tb, pb, tol, depth, max_depth, min_depth)
    depth >= max_depth && return
    tm = 0.5 * (ta + tb)
    pm = project_point(t, arcpoint(arc, tm))
    if depth >= min_depth
        (_finite2(pm) && _finite2(pa) && _finite2(pb)) || return
        dev = hypot(pm[1] - 0.5 * (pa[1] + pb[1]), pm[2] - 0.5 * (pa[2] + pb[2]))
        dev <= tol && return
    end
    _refine!(out, t, arc, ta, pa, tm, pm, tol, depth + 1, max_depth, min_depth)
    push!(out, pm)
    _refine!(out, t, arc, tm, pm, tb, pb, tol, depth + 1, max_depth, min_depth)
    return
end

"""
    rim_bbox(view, t) -> Union{Rect2d, Nothing}

Bounding box of the view's projected rim (dense sampling, endpoints approached
from inside), `nothing` when the view has no rim or nothing projects.
"""
function rim_bbox(view::SphereRegion, t)
    pieces = rim(view)
    isempty(pieces) && return nothing
    xs = Float64[]; ys = Float64[]
    for piece in pieces
        a = piece.arc
        n = clamp(ceil(Int, arclength(a) / deg2rad(0.5)) + 1, 64, 1024)
        for i in 1:n
            tt = a.t0 + (a.t1 - a.t0) * (i - 1) / (n - 1)
            p = i == 1 ? project_on_arc(t, a, tt, 1) :
                i == n ? project_on_arc(t, a, tt, -1) : project_point(t, arcpoint(a, tt))
            _finite2(p) || continue
            push!(xs, p[1]); push!(ys, p[2])
        end
    end
    isempty(xs) && return nothing
    return _bbox(xs, ys)
end

_bbox(xs, ys) = Rect2d(Vec2d(minimum(xs), minimum(ys)), Vec2d(maximum(xs) - minimum(xs), maximum(ys) - minimum(ys)))

"The dest-space tolerance used for a rect: a thousandth of its longer side."
frame_tolerance(rect::Rect2) = TOL_FRACTION * max(maximum(widths(rect)), 1e-300)
