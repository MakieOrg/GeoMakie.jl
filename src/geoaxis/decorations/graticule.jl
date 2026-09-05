#=
# The graticule

Every graticule line is an arc on the sphere: clipped against the view region
there (closed form), projected adaptively, then clipped to the limits
rectangle in the plane.  Where a projected piece ends on the frame it leaves an
`Exit`, which is what a tick and its label hang from.

Also here: the visible lon/lat `Extent` (the frame's inverse image, widened to
the full turn and ±90 when a pole is in view) and the two carrier lines whose
pixel length sizes the tick interval per direction.
=#

const EXTENT_EDGE_SAMPLES = 64          # most inverse-projected samples per frame edge
const EXTENT_SAMPLE_FRAC = 1 / 200      # sample spacing along the frame as a fraction of the extent
const FULL_TURN_GAP_DEG = 0.5           # a longitude gap under this means every meridian is visible
const ON_FRAME_FRAC = 2e-3              # an endpoint this close to the frame (× extent) is an exit
const CORNER_PREFER = 0.5               # a corner exit prefers the edge better aligned with its family

"""
    Extent

The visible lon/lat range.  `lon_lo..lon_hi` is unwrapped (it may run past
±180 when the view straddles the antimeridian); `full_turn` says every meridian
is visible, `north`/`south` that a pole is.
"""
struct Extent
    lon_lo::Float64
    lon_hi::Float64
    lat_lo::Float64
    lat_hi::Float64
    full_turn::Bool
    north::Bool
    south::Bool
end
const FULL_EXTENT = Extent(-180.0, 180.0, -90.0, 90.0, true, true, true)

lon_span(e::Extent) = e.full_turn ? 360.0 : e.lon_hi - e.lon_lo
lat_span(e::Extent) = e.lat_hi - e.lat_lo
lon_range(e::Extent) = e.full_turn ? (-180.0, 180.0) : (e.lon_lo, e.lon_hi)
lat_range(e::Extent) = (e.lat_lo, e.lat_hi)

"The unwrapped longitude range covering the sorted longitudes, or `nothing` when they cover the turn."
function _lon_range_from_samples(lons::Vector{Float64})
    isempty(lons) && return nothing
    u = sort!(mod.(lons, 360.0))
    n = length(u)
    n == 1 && return (u[1], u[1])
    gap, at = u[1] + 360.0 - u[end], n
    for i in 1:(n - 1)
        g = u[i + 1] - u[i]
        g > gap && (gap = g; at = i)
    end
    gap < FULL_TURN_GAP_DEG && return nothing
    lo = u[mod1(at + 1, n)]
    hi = u[at]
    hi < lo && (hi += 360.0)
    lo >= 180.0 && (lo -= 360.0; hi -= 360.0)
    return (lo, hi)
end

"Is a pole drawn inside `rect` (as a point or a line)?"
function _pole_in_rect(t, lat::Real, rect::Rect2d, tol)
    x0, y0 = minimum(rect) .- tol; x1, y1 = maximum(rect) .+ tol
    for lon in -180.0:45.0:180.0
        q = project_lonlat(t, lon, lat)
        _finite2(q) || continue
        (x0 <= q[1] <= x1 && y0 <= q[2] <= y1) && return true
    end
    return false
end

"""
    visible_extent(frame, t, view, rect) -> Extent

Inverse-project samples along every frame edge; a pole inside the view and the
rect widens the range to ±90 and the full turn.
"""
function visible_extent(fr::Frame, t, view::SphereRegion, rect::Rect2d)
    inv = _inverse_of(t)
    inv === nothing && return FULL_EXTENT
    extent = max(maximum(widths(rect)), 1e-300)
    lons = Float64[]; lats = Float64[]
    for lp in fr.loops
        n = length(lp)
        for j in 1:n
            a, b = lp[j], lp[mod1(j + 1, n)]
            len = norm(b - a)
            m = clamp(ceil(Int, len / (EXTENT_SAMPLE_FRAC * extent)), 1, EXTENT_EDGE_SAMPLES)
            for k in 0:(m - 1)
                p = a + (b - a) * (k / m)
                ll = try
                    Makie.apply_transform(inv, Point2d(p))
                catch
                    continue
                end
                (isfinite(ll[1]) && isfinite(ll[2])) || continue
                push!(lons, ll[1]); push!(lats, ll[2])
            end
        end
    end
    tol = ON_FRAME_FRAC * extent
    north = contains(view, ZHAT) && _pole_in_rect(t, 90.0, rect, tol)
    south = contains(view, -ZHAT) && _pole_in_rect(t, -90.0, rect, tol)
    isempty(lats) && return Extent(-180.0, 180.0, -90.0, 90.0, true, north, south)
    lat_lo = south ? -90.0 : clamp(minimum(lats), -90.0, 90.0)
    lat_hi = north ? 90.0 : clamp(maximum(lats), -90.0, 90.0)
    lr = north || south ? nothing : _lon_range_from_samples(lons)
    if lr === nothing
        return Extent(-180.0, 180.0, lat_lo, lat_hi, true, north, south)
    end
    return Extent(lr[1], lr[2], lat_lo, lat_hi, false, north, south)
end

# ---- arcs of the graticule -----------------------------------------------

"The meridian at `lon` between latitudes `lat0..lat1` (degrees)."
function meridian_arc(lon::Real, lat0::Real = -90.0, lat1::Real = 90.0)
    d = _dir(lon)
    return make_arc(_cross3(d, ZHAT), 0.0, d, deg2rad(lat0), deg2rad(lat1))
end

"The parallel at `lat`, the full circle or the longitude range `lon0..lon1`."
function parallel_arc(lat::Real, lon0::Real = -180.0, lon1::Real = 180.0)
    if lon1 - lon0 >= 360 - 1e-9
        return full_circle(ZHAT, sind(lat))
    end
    return make_arc(ZHAT, sind(lat), XHAT, deg2rad(lon0), deg2rad(lon1))
end

# ---- clipping a polyline to a rectangle -------------------------------------

"""
    clip_polyline_rect(pts, rect, eps) -> Vector{(points, start_cut, end_cut)}

Runs of `pts` inside `rect` (points within `eps` of a side count as inside and
are clamped onto it).  `NaN` points split runs.  A run's flags say whether its
first / last point was created by the rectangle.
"""
function clip_polyline_rect(pts::Vector{Point2d}, rect::Rect2d, eps::Real)
    x0, y0 = minimum(rect); x1, y1 = maximum(rect)
    inside(p) = x0 - eps <= p[1] <= x1 + eps && y0 - eps <= p[2] <= y1 + eps
    clampr(p) = Point2d(clamp(p[1], x0, x1), clamp(p[2], y0, y1))
    out = Tuple{Vector{Point2d}, Bool, Bool}[]
    cur = Point2d[]; cur_start_cut = false
    function flush!(end_cut)
        length(cur) >= 2 && push!(out, (cur, cur_start_cut, end_cut))
        cur = Point2d[]; cur_start_cut = false
    end
    n = length(pts)
    for i in 1:n
        p = pts[i]
        if !_finite2(p)
            flush!(false)
            continue
        end
        if inside(p)
            if isempty(cur) && i > 1 && _finite2(pts[i - 1]) && !inside(pts[i - 1])
                q = _rect_entry(pts[i - 1], p, rect)
                q === nothing || (push!(cur, clampr(q)); cur_start_cut = true)
            end
            push!(cur, clampr(p))
        else
            if !isempty(cur)
                q = _rect_entry(p, cur[end], rect)
                q === nothing || push!(cur, clampr(q))
                flush!(true)
            elseif i > 1 && _finite2(pts[i - 1]) && !inside(pts[i - 1])
                # both outside: the segment may still cross the rect
                seg = _rect_segment(pts[i - 1], p, rect)
                if seg !== nothing
                    push!(out, ([clampr(seg[1]), clampr(seg[2])], true, true))
                end
            end
        end
    end
    flush!(false)
    return out
end

"Liang–Barsky parameter range of the segment `a → b` inside `rect`."
function _lb_range(a, b, rect::Rect2d)
    x0, y0 = minimum(rect); x1, y1 = maximum(rect)
    t0, t1 = 0.0, 1.0
    d = b - a
    for (p, q) in ((-d[1], a[1] - x0), (d[1], x1 - a[1]), (-d[2], a[2] - y0), (d[2], y1 - a[2]))
        if p == 0
            q < 0 && return nothing
        else
            r = q / p
            if p < 0
                r > t1 && return nothing
                r > t0 && (t0 = r)
            else
                r < t0 && return nothing
                r < t1 && (t1 = r)
            end
        end
    end
    return (t0, t1)
end

"Where the segment from outside point `o` to inside point `i` enters the rect."
function _rect_entry(o, i, rect::Rect2d)
    r = _lb_range(o, i, rect)
    r === nothing && return nothing
    return o + (i - o) * r[1]
end

function _rect_segment(a, b, rect::Rect2d)
    r = _lb_range(a, b, rect)
    r === nothing && return nothing
    r[2] - r[1] <= 1e-12 && return nothing
    return (a + (b - a) * r[1], a + (b - a) * r[2])
end

# ---- the frame as a spatial index ---------------------------------------------

"""
    FrameIndex

Frame edges bucketed on a grid so an endpoint finds its edge without a scan.
`edges[k]` is `(a, b, loop, j)`.
"""
struct FrameIndex
    edges::Vector{Tuple{Point2d, Point2d, Int, Int}}
    origin::Vec2d
    cell::Float64
    n::Int
    buckets::Dict{Tuple{Int, Int}, Vector{Int}}
end

function FrameIndex(fr::Frame, rect::Rect2d)
    edges = Tuple{Point2d, Point2d, Int, Int}[]
    for (k, lp) in enumerate(fr.loops), j in eachindex(lp)
        push!(edges, (lp[j], lp[mod1(j + 1, length(lp))], k, j))
    end
    n = clamp(ceil(Int, sqrt(length(edges))), 4, 64)
    cell = max(maximum(widths(rect)), 1e-300) / n
    buckets = Dict{Tuple{Int, Int}, Vector{Int}}()
    o = Vec2d(minimum(rect))
    for (i, e) in enumerate(edges)
        lo = floor.(Int, (min.(e[1], e[2]) .- o) ./ cell)
        hi = floor.(Int, (max.(e[1], e[2]) .- o) ./ cell)
        for cx in lo[1]:hi[1], cy in lo[2]:hi[2]
            push!(get!(() -> Int[], buckets, (cx, cy)), i)
        end
    end
    return FrameIndex(edges, o, cell, n, buckets)
end

function _seg_dist(p, a, b)
    ab = b - a
    l2 = ab[1]^2 + ab[2]^2
    l2 <= 1e-300 && return norm(p - a)
    s = clamp(((p - a)[1] * ab[1] + (p - a)[2] * ab[2]) / l2, 0.0, 1.0)
    return norm(p - (a + ab * s))
end

"""
    nearest_edge(idx, p, tol; prefer) -> Union{Nothing, Int}

The index of a frame edge within `tol` of `p`.  When several qualify (a
corner), `prefer` is a unit direction: the edge whose direction is most
aligned with it wins, distance breaking ties.
"""
function nearest_edge(idx::FrameIndex, p, tol::Real; prefer = nothing)
    lo = floor.(Int, (p .- tol .- idx.origin) ./ idx.cell)
    hi = floor.(Int, (p .+ tol .- idx.origin) ./ idx.cell)
    best = nothing; best_key = nothing
    seen = Set{Int}()
    for cx in lo[1]:hi[1], cy in lo[2]:hi[2]
        for i in get(idx.buckets, (cx, cy), Int[])
            i in seen && continue
            push!(seen, i)
            a, b = idx.edges[i][1], idx.edges[i][2]
            d = _seg_dist(p, a, b)
            d <= tol || continue
            align = 0.0
            if prefer !== nothing
                e = b - a
                ne = norm(e)
                ne > 0 && (align = abs(e[1] * prefer[1] + e[2] * prefer[2]) / ne)
            end
            key = (-round(align * CORNER_PREFER; digits = 3), d)
            if best_key === nothing || key < best_key
                best, best_key = i, key
            end
        end
    end
    return best
end

# ---- exits ---------------------------------------------------------------------

"""
    Exit

Where a graticule line meets the frame: `p` (dest), the frame edge (`loop`,
`edge` into `Frame.loops`), the edge's outward unit normal, the angle (degrees,
0..90) between the line and the frame there, and the tangent of the line
leaving the map.

The angle is measured on the sphere where the exit is a sphere-clip endpoint
on a rim piece: in the plane a projection's Jacobian is singular at a limb, so
every graticule line is tangent to an orthographic limb there and a planar
angle would call all of them grazing.  On a `:pole` edge the angle is 90° (a
pole line is a parallel drawn as a line), and on a `:viewport` edge it is the
planar angle between the last chord and the straight edge.
"""
struct Exit
    family::Symbol
    value::Float64
    p::Point2d
    loop::Int
    edge::Int
    tag::Symbol
    normal::Vec2d
    angle::Float64
    tangent::Vec2d
end

"Outward unit normal of the edge `a → b` of a loop traversed with the map on its left."
function outward_normal(a, b)
    e = b - a
    n = norm(e)
    n <= 1e-300 && return Vec2d(0, 0)
    return Vec2d(e[2] / n, -e[1] / n)
end

"""
    GraticuleLine

One graticule line after clipping: `pieces` are dest-space polylines;
`closed[i]` marks a piece that is a closed loop (no exits); `ends[i]` holds
the unit-sphere points of the piece's two ends where they are sphere-clip
endpoints of the arc (`NaN` where the rect cut the piece).
"""
struct GraticuleLine
    family::Symbol
    value::Float64
    pieces::Vector{Vector{Point2d}}
    closed::Vector{Bool}
    ends::Vector{Tuple{Vec3d, Vec3d}}
end

const NO_SPHERE_POINT = Vec3d(NaN, NaN, NaN)
_finite3(v) = isfinite(v[1]) && isfinite(v[2]) && isfinite(v[3])

"The axis of the circle a graticule line lies on."
graticule_axis(family::Symbol, value::Real) = family === :lon ? _cross3(_dir(value), ZHAT) : ZHAT

"""
    graticule_lines(family, values, view, t, rect, ext; tol) -> Vector{GraticuleLine}

Clip each meridian (`:lon`) or parallel (`:lat`) to the view on the sphere,
project it, and clip it to `rect`.
"""
function graticule_lines(family::Symbol, values, view::SphereRegion, t, rect::Rect2d, ext::Extent; tol::Real)
    out = GraticuleLine[]
    eps = DEDUP_FRAC * max(maximum(widths(rect)), 1e-300)
    for v in values
        # a pole is a point (or a pole line already on the frame), not a parallel
        family === :lat && abs(v) >= 90 - 1e-9 && continue
        arc = family === :lon ? meridian_arc(v) : parallel_arc(v)
        pieces = Vector{Point2d}[]; closed = Bool[]; ends = Tuple{Vec3d, Vec3d}[]
        for a in clip(view, arc)
            pts = adaptive_project(t, a; tol, dropnan = false)
            runs = clip_polyline_rect(pts, rect, eps)
            isempty(runs) && continue
            if isfull(a) && length(runs) >= 2 && !runs[1][2] && !runs[end][3]
                # the circle's seed point is inside the rect: the last run continues into the first
                merged = vcat(runs[end][1], runs[1][1][2:end])
                runs = vcat([(merged, runs[end][2], runs[1][3])], runs[2:(end - 1)])
            end
            first_pt = isempty(pts) ? Point2d(NaN, NaN) : pts[1]
            last_pt = isempty(pts) ? Point2d(NaN, NaN) : pts[end]
            for (r, sc, ec) in runs
                push!(pieces, r)
                full = isfull(a)
                push!(closed, full && !sc && !ec)
                # a run end that is the arc's own end (not the rect's cut) sits on the rim
                s = (!full && !sc && _finite2(first_pt) && norm(r[1] - first_pt) <= eps) ? arcpoint(a, a.t0) : NO_SPHERE_POINT
                e = (!full && !ec && _finite2(last_pt) && norm(r[end] - last_pt) <= eps) ? arcpoint(a, a.t1) : NO_SPHERE_POINT
                push!(ends, (s, e))
            end
        end
        isempty(pieces) && continue
        push!(out, GraticuleLine(family, v, pieces, closed, ends))
    end
    return out
end

"NaN-separated points of every piece of every line, for `lines!`."
function graticule_points(lines::Vector{GraticuleLine})
    out = Point2d[]
    for l in lines, pc in l.pieces
        isempty(out) || push!(out, Point2d(NaN, NaN))
        append!(out, pc)
    end
    return out
end

"""
    sphere_angle(family, value, q, pieces, part) -> Union{Nothing, Float64}

The angle (degrees, 0..90) at the unit-sphere point `q` between the graticule
line and the rim piece of primitive `part` that passes through `q`; `nothing`
when no piece of that part is there or a tangent is undefined.
"""
function sphere_angle(family::Symbol, value::Real, q, pieces::Vector{RimPiece}, part::Int)
    tg = _cross3(graticule_axis(family, value), q)
    ng = norm(tg)
    ng <= 1e-9 && return nothing
    best = nothing; best_d = Inf
    for piece in pieces
        piece.part == part || continue
        d = abs(_dot3(q, piece.arc.axis) - piece.arc.cosθ)
        if d < best_d
            best = piece
            best_d = d
        end
    end
    # seam pieces sit SEAM_EPS off the cut and clip ends are inset up to MAX_INSET
    (best === nothing || best_d > 2 * MAX_INSET) && return nothing
    tr = _cross3(best.arc.axis, q)
    nr = norm(tr)
    nr <= 1e-9 && return nothing
    return rad2deg(asin(clamp(norm(_cross3(tg, tr)) / (ng * nr), 0.0, 1.0)))
end

function _exit_at(l::GraticuleLine, k::Int, atstart::Bool, fr::Frame, idx::FrameIndex, tol, pieces::Vector{RimPiece})
    pc = l.pieces[k]
    n = length(pc)
    n >= 2 || return nothing
    p = atstart ? pc[1] : pc[end]
    q = atstart ? pc[2] : pc[end - 1]
    tangent = p - q
    nt = norm(tangent)
    nt <= 1e-300 && return nothing
    tangent = Vec2d(tangent / nt)
    # a corner: longitudes prefer the horizontal edge, latitudes the vertical one
    prefer = l.family === :lon ? Vec2d(1, 0) : Vec2d(0, 1)
    i = nearest_edge(idx, p, tol; prefer)
    i === nothing && return nothing
    a, b, loop, edge = idx.edges[i]
    nrm = outward_normal(a, b)
    tag = fr.tags[loop][edge]
    e = b - a
    ne = norm(e)
    angle = ne <= 1e-300 ? 90.0 : rad2deg(asin(clamp(abs(e[1] * tangent[2] - e[2] * tangent[1]) / ne, 0.0, 1.0)))
    if tag === :pole
        angle = 90.0
    elseif tag !== :viewport
        sp = atstart ? l.ends[k][1] : l.ends[k][2]
        if _finite3(sp)
            sa = sphere_angle(l.family, l.value, sp, pieces, fr.source[loop][edge])
            sa === nothing || (angle = sa)
        end
    end
    return Exit(l.family, l.value, p, loop, edge, tag, nrm, angle, tangent)
end

"""
    exits(lines, frame, rect, pieces = RimPiece[]) -> Vector{Exit}

Every piece endpoint that lies on the frame.  `pieces` is `rim(view)`, used to
measure exit angles on the sphere.
"""
function exits(lines::Vector{GraticuleLine}, fr::Frame, rect::Rect2d, pieces::Vector{RimPiece} = RimPiece[])
    out = Exit[]
    isempty(fr.loops) && return out
    idx = FrameIndex(fr, rect)
    tol = ON_FRAME_FRAC * max(maximum(widths(rect)), 1e-300)
    for l in lines, k in eachindex(l.pieces)
        l.closed[k] && continue
        for atstart in (true, false)
            e = _exit_at(l, k, atstart, fr, idx, tol, pieces)
            e === nothing || push!(out, e)
        end
    end
    return out
end

# ---- carriers -----------------------------------------------------------------

"""
    Carrier

The line whose pixel length sizes a direction's tick interval: `length` in
dest units of its visible pieces, `span` the degrees of it that are visible.
"""
struct Carrier
    family::Symbol
    value::Float64
    pieces::Vector{Vector{Point2d}}
    length::Float64
    span::Float64
end

_polyline_length(pc) = sum(norm(pc[i + 1] - pc[i]) for i in 1:(length(pc) - 1); init = 0.0)

function _carrier(family::Symbol, value::Real, arc::CircleArc, view, t, rect::Rect2d, ext::Extent, tol)
    eps = DEDUP_FRAC * max(maximum(widths(rect)), 1e-300)
    pieces = Vector{Point2d}[]
    len = 0.0; span = 0.0
    for a in clip(view, arc)
        span += rad2deg(abs(a.t1 - a.t0))
        pts = adaptive_project(t, a; tol, dropnan = false)
        for (r, _, _) in clip_polyline_rect(pts, rect, eps)
            push!(pieces, r)
            len += _polyline_length(r)
        end
    end
    span = min(span, family === :lon ? lon_span(ext) : lat_span(ext))
    return Carrier(family, float(value), pieces, len, span)
end

"""
    pole_line_length(frame, ext) -> Float64

The dest-space length of one pole line: the total length of the frame's
`:pole` edges shared between the poles in view.  `Inf` when the frame has none.
"""
function pole_line_length(fr::Frame, ext::Extent)
    total = 0.0; any = false
    for (a, b, tag, _) in edges(fr)
        tag === :pole || continue
        total += norm(b - a); any = true
    end
    any || return Inf
    return total / max(1, (ext.north ? 1 : 0) + (ext.south ? 1 : 0))
end

"""
    carriers(view, t, rect, ext, lon_0; tol) -> (lon = Carrier, lat = Carrier)

The middle visible parallel (for longitudes) and the middle visible meridian
(for latitudes; the central meridian `lon_0` when every meridian is visible).
"""
function carriers(view::SphereRegion, t, rect::Rect2d, ext::Extent, lon_0::Real; tol::Real)
    lat_mid = 0.5 * (ext.lat_lo + ext.lat_hi)
    abs(lat_mid) >= 89.0 && (lat_mid = sign(lat_mid) * 89.0)
    lon_mid = ext.full_turn ? float(lon_0) : 0.5 * (ext.lon_lo + ext.lon_hi)
    # a meridian on a cut seam projects to both sides of the map; step off it
    for _ in 1:5
        _coincident_seam(view, meridian_arc(lon_mid)) === nothing && break
        lon_mid += 1.0
    end
    lon = _carrier(:lon, lat_mid, parallel_arc(lat_mid), view, t, rect, ext, tol)
    lat = _carrier(:lat, lon_mid, meridian_arc(lon_mid, ext.lat_lo, ext.lat_hi), view, t, rect, ext, tol)
    return (; lon, lat)
end

"The central meridian PROJ was given, `0` when the projection has none."
function central_meridian(t)
    id = identify(t)
    id === nothing && return 0.0
    return get(id.params, :lon_0, 0.0)
end

# ---- carrier crossings, for interior labels ---------------------------------

const TANGENT_STEP_DEG = 0.01           # finite-difference step for a graticule tangent in dest space
const TANGENT_JUMP_FRAC = 1e-2          # a difference longer than this × extent crossed a seam

"""
    CarrierCrossing

Where a graticule line meets a carrier line of the other family: the line's
`family` and `value`, the `carrier`'s value, the point in dest space, and the
unit dest-space tangents of the carrier and of the line there.  An interior
label hangs from one of these.
"""
struct CarrierCrossing
    family::Symbol
    value::Float64
    carrier::Float64
    p::Point2d
    ctangent::Vec2d
    ltangent::Vec2d
end

"""
    _lonlat_tangent(t, lon, lat, dlon, dlat, extent) -> Union{Nothing, Vec2d}

Unit dest-space direction of the lon/lat curve through `(lon, lat)` along
`(dlon, dlat)`: a central difference, falling back to one-sided ones; a
difference that jumped across a seam or vanished is rejected.
"""
function _lonlat_tangent(t, lon, lat, dlon, dlat, extent)
    lat0, lat1 = clamp(lat - dlat, -90.0, 90.0), clamp(lat + dlat, -90.0, 90.0)
    p1 = project_lonlat(t, lon - dlon, lat0)
    p2 = project_lonlat(t, lon + dlon, lat1)
    p0 = project_lonlat(t, lon, lat)
    limit = TANGENT_JUMP_FRAC * extent
    for (a, b) in ((p1, p2), (p0, p2), (p1, p0))
        (_finite2(a) && _finite2(b)) || continue
        d = b - a
        n = norm(d)
        (n > 0 && n < limit) || continue
        return Vec2d(d / n)
    end
    return nothing
end

"""
    carrier_crossings(family, values, carrier, view, t, rect) -> Vector{CarrierCrossing}

The crossings of the `family` lines at `values` with the carrier line of the
other family at `carrier`, keeping those inside the view and the rect.
"""
function carrier_crossings(family::Symbol, values, carrier::Real, view::SphereRegion, t, rect::Rect2d)
    out = CarrierCrossing[]
    extent = max(maximum(widths(rect)), 1e-300)
    tol = ON_FRAME_FRAC * extent
    x0, y0 = minimum(rect) .- tol
    x1, y1 = maximum(rect) .+ tol
    δ = TANGENT_STEP_DEG
    for v in values
        lon, lat = family === :lon ? (float(v), float(carrier)) : (float(carrier), float(v))
        abs(lat) >= 90 - 1e-9 && continue
        contains(view, lonlat_to_xyz(lon, lat)) || continue
        p = project_lonlat(t, lon, lat)
        _finite2(p) || continue
        (x0 <= p[1] <= x1 && y0 <= p[2] <= y1) || continue
        along_parallel = _lonlat_tangent(t, lon, lat, δ, 0.0, extent)
        along_meridian = _lonlat_tangent(t, lon, lat, 0.0, δ, extent)
        (along_parallel === nothing || along_meridian === nothing) && continue
        ct, lt = family === :lon ? (along_parallel, along_meridian) : (along_meridian, along_parallel)
        push!(out, CarrierCrossing(family, float(v), float(carrier), p, ct, lt))
    end
    return out
end

_lon_distance(a, b) = (d = mod(a - b, 360.0); min(d, 360.0 - d))

"""
    label_carriers(xvals, yvals, lon_mid, lat_mid, carriermeridian, carrierparallel) -> (; meridian, parallels)

The carrier meridian interior latitude labels sit beside (the drawn meridian
nearest the central one, `lon_mid`, unless the user named one) and the
candidate carrier parallels for interior longitude labels in preference
order: outermost first, south before north (only the user's when named).
`lat_mid` stands in when no parallel is drawn.
"""
function label_carriers(xvals, yvals, lon_mid::Real, lat_mid::Real, carriermeridian, carrierparallel)
    meridian = if carriermeridian isa Makie.Automatic
        isempty(xvals) ? float(lon_mid) : float(xvals[argmin([_lon_distance(v, lon_mid) for v in xvals])])
    else
        float(carriermeridian)
    end
    parallels = if carrierparallel isa Makie.Automatic
        cands = Float64[float(v) for v in yvals if abs(v) < 90 - 1e-9]
        isempty(cands) && push!(cands, float(lat_mid))
        sort!(cands; by = v -> (-abs(v), v))
    else
        Float64[float(carrierparallel)]
    end
    return (; meridian, parallels)
end
