#=
# Sphere-space clipping + adaptive resampling

Generic handling of projection discontinuities (antimeridian, azimuthal horizons,
interrupted lobes, oblique square tears) the way d3-geo does it: clip geometry **on
the sphere, before projection**, and densify each segment with **adaptive bisection**
so projected curves are smooth. Output stays in lon/lat, so the existing GeoAxis
pipeline (split node emits lon/lat → child plot projects per-vertex) is untouched —
no inverse projection of data, no projected-space heuristics.

Ports of:
- `d3-geo/src/projection/resample.js`        → [`resample_sphere`](@ref)
- `d3-geo/src/clip/antimeridian.js`          → [`AntimeridianClip`](@ref)
- `d3-geo/src/clip/circle.js` (visibility)   → [`CircleClip`](@ref)

The discontinuity each destination transform tears along is chosen by
[`clip_strategy`](@ref), the analog of d3's per-projection `preclip`.
=#

const _D2R = π / 180
const _R2D = 180 / π

# unit cartesian of a lon/lat (degrees)
@inline _cart(lon, lat) = (c = cos(lat * _D2R); (c * cos(lon * _D2R), c * sin(lon * _D2R), sin(lat * _D2R)))
# unit cartesian -> (lon,lat) degrees
@inline function _sph(v)
    x, y, z = v
    (atan(y, x) * _R2D, asin(clamp(z, -1.0, 1.0)) * _R2D)
end
@inline _dot3(a, b) = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
@inline _norm3(v) = sqrt(_dot3(v, v))
# great-circle interpolation between unit vectors, t in [0,1]
@inline function _slerp(a, b, t)
    d = clamp(_dot3(a, b), -1.0, 1.0)
    Ω = acos(d)
    Ω < 1.0e-12 && return a
    s = sin(Ω)
    w0 = sin((1 - t) * Ω) / s
    w1 = sin(t * Ω) / s
    v = (a[1] * w0 + b[1] * w1, a[2] * w0 + b[2] * w1, a[3] * w0 + b[3] * w1)
    n = _norm3(v)
    (v[1] / n, v[2] / n, v[3] / n)
end

@inline _lon(p) = @inbounds Float64(p[1])
@inline _lat(p) = @inbounds Float64(p[2])
@inline _isfinitexy(xy) = isfinite(xy[1]) && isfinite(xy[2])

############################################################
#                  Adaptive resampler                      #
############################################################

const _MAXDEPTH = 16          # d3 maxDepth
const _DELTA2   = 0.5         # d3 default precision² (projected units after scaling)
const _COSMIN   = cos(30 * _D2R)   # d3 cosMinDistance

# Port of d3 resample.js `resampleLineTo`, emitting **lon/lat** midpoints (the child
# projects them). The straightness test is measured in *projected* space via `project`.
function _resample_to!(out, project, scale, v0, ll0, xy0, v1, ll1, xy1, depth)
    dx = (xy1[1] - xy0[1]) * scale
    dy = (xy1[2] - xy0[2]) * scale
    d2 = dx * dx + dy * dy
    (d2 > 4 * _DELTA2 && depth > 0) || return out
    # geodesic midpoint on the sphere
    m = (v0[1] + v1[1], v0[2] + v1[2], v0[3] + v1[3])
    nm = _norm3(m)
    nm < 1.0e-12 && return out
    vm = (m[1] / nm, m[2] / nm, m[3] / nm)
    # keep d3's lon disambiguation near the poles / coincident meridians
    lon2, lat2 = _sph(vm)
    if abs(abs(vm[3]) - 1) < 1.0e-9 || abs(ll0[1] - ll1[1]) < 1.0e-9
        lon2 = (ll0[1] + ll1[1]) / 2
    end
    ll2 = (lon2, lat2)
    xy2 = project(lon2, lat2)
    _isfinitexy(xy2) || return out            # don't densify across ∞
    dx2 = (xy2[1] - xy0[1]) * scale
    dy2 = (xy2[2] - xy0[2]) * scale
    dz = dy * dx2 - dx * dy2
    if dz * dz / d2 > _DELTA2 ||                                   # projected perpendicular distance
       abs((dx * dx2 + dy * dy2) / d2 - 0.5) > 0.3 ||             # midpoint near an end
       _dot3(v0, v1) < _COSMIN                                    # angular distance > 30°
        _resample_to!(out, project, scale, v0, ll0, xy0, vm, ll2, xy2, depth - 1)
        push!(out, Point2d(lon2, lat2))
        _resample_to!(out, project, scale, vm, ll2, xy2, v1, ll1, xy1, depth - 1)
    end
    return out
end

"""
    resample_sphere(sub, project; scale=1.0) -> Vector{Point2d}

Adaptively densify one **break-free** lon/lat polyline `sub` (vector of point-likes,
degrees) so that, once projected by `project((lon,lat)) -> (x,y)`, the curve is smooth.
Returns lon/lat points (the caller's transform does the projecting). Midpoints are taken
on the sphere (great-circle); the error test is in projected space. `scale` converts
projected units to the threshold's units (e.g. 1/map-diagonal) — see `resample_scale`.

Direction-symmetric: `resample_sphere(sub) == reverse(resample_sphere(reverse(sub)))`.
"""
function resample_sphere(sub, project; scale::Float64 = 1.0)
    out = Point2d[]
    n = length(sub)
    n == 0 && return out
    ll0 = (_lon(sub[1]), _lat(sub[1]))
    v0 = _cart(ll0...)
    xy0 = project(ll0...)
    push!(out, Point2d(ll0[1], ll0[2]))
    @inbounds for i in 2:n
        ll1 = (_lon(sub[i]), _lat(sub[i]))
        v1 = _cart(ll1...)
        xy1 = project(ll1...)
        if _isfinitexy(xy0) && _isfinitexy(xy1)
            _resample_to!(out, project, scale, v0, ll0, xy0, v1, ll1, xy1, _MAXDEPTH)
        end
        push!(out, Point2d(ll1[1], ll1[2]))
        ll0, v0, xy0 = ll1, v1, xy1
    end
    return out
end

# A scale that makes `_DELTA2` correspond to ~a fraction of the projected map size, so
# the same threshold behaves across projections with wildly different units (degrees vs
# metres). `project` is sampled on a coarse lon/lat grid to estimate the projected span.
function resample_scale(project)
    umin = vmin = Inf; umax = vmax = -Inf
    for lon in -180.0:30.0:180.0, lat in -90.0:30.0:90.0
        xy = project(lon, lat)
        _isfinitexy(xy) || continue
        umin = min(umin, xy[1]); umax = max(umax, xy[1])
        vmin = min(vmin, xy[2]); vmax = max(vmax, xy[2])
    end
    span = max(umax - umin, vmax - vmin)
    (isfinite(span) && span > 0) || return 1.0
    # target: one "unit" ≈ span/200  ⇒ scale so that distances are measured in those units
    return 200.0 / span
end

############################################################
#                    Clip strategies                       #
############################################################

abstract type SphereClip end

"No discontinuity — pass geometry through unchanged (non-Proj / `+over`)."
struct NoClip <: SphereClip end

"""
    AntimeridianClip(lon0)

Tear at the meridian `lon0 ± 180` (the periodicity seam). Port of d3
`clip/antimeridian.js`: split a segment that crosses the antimeridian, inserting the
exact crossing latitude on each side. `lon0` is the projection centre (`+lon_0 +pm`).
"""
struct AntimeridianClip <: SphereClip
    lon0::Float64
end

"""
    CircleClip(axis, radius; mode=:horizon)

Small circle of angular `radius` (degrees) about unit cartesian `axis`. `:horizon`
keeps only the visible side (azimuthal/perspective horizons — `ortho`/`geos`/…); `:seam`
keeps both sides and only splits at the crossing. Visibility is the cartesian test
`dot(cartesian(p), axis) > cos(radius)` — works at `radius = 90°` (a hemisphere), where a
lon/lat disk polygon does not exist.
"""
struct CircleClip <: SphereClip
    axis::NTuple{3,Float64}
    cosr::Float64
    mode::Symbol
end
# build a CircleClip from a centre (lon,lat) and angular radius, both in degrees
circle_clip(center_lon, center_lat, radius_deg; mode = :horizon) =
    CircleClip(_cart(center_lon, center_lat), cos(radius_deg * _D2R), mode)

# --- antimeridian crossing latitude (d3 clipAntimeridianIntersect), radians -----
@inline function _antimeridian_lat(λ0, φ0, λ1, φ1)
    s = sin(λ0 - λ1)
    abs(s) < 1.0e-12 && return (φ0 + φ1) / 2
    cφ0 = cos(φ0); cφ1 = cos(φ1)
    atan((sin(φ0) * cφ1 * sin(λ1) - sin(φ1) * cφ0 * sin(λ0)) / (cφ0 * cφ1 * s))
end

############################################################
#         clip_line: split a polyline at the tear         #
############################################################

"""
    clip_line(clip, pts) -> Vector{Vector{Point2d}}

Split a lon/lat polyline `pts` into visible sub-polylines at `clip`'s discontinuity,
inserting boundary points at each crossing. Sub-polylines are later resampled and joined
with `NaN` breaks. `NoClip` returns the input as a single sub.
"""
function clip_line(::NoClip, pts)
    sub = Point2d[Point2d(_lon(p), _lat(p)) for p in pts]
    return Vector{Point2d}[sub]
end

function clip_line(c::AntimeridianClip, pts)
    subs = Vector{Point2d}[]
    cur = Point2d[]
    n = length(pts)
    n == 0 && return subs
    # work in a frame shifted so the tear is at ±180, normalised into [-180,180)
    sh(lon) = mod(lon - c.lon0 + 180.0, 360.0) - 180.0
    λprev = sh(_lon(pts[1])); φprev = _lat(pts[1]) * _D2R
    push!(cur, Point2d(_lon(pts[1]), _lat(pts[1])))
    @inbounds for i in 2:n
        λ1d = sh(_lon(pts[i])); φ1 = _lat(pts[i]) * _D2R
        λ0 = λprev * _D2R; λ1 = λ1d * _D2R
        sign0 = λ0 > 0 ? π : -π
        sign1 = λ1 > 0 ? π : -π
        Δ = abs(λ1 - λ0)
        if sign0 != sign1 && Δ >= π            # antimeridian crossing
            φx = _antimeridian_lat(λ0, φprev, λ1, φ1)
            φxd = φx * _R2D
            push!(cur, Point2d(c.lon0 + sign0 * _R2D, φxd))    # finish at this side's ±180
            push!(subs, cur)
            cur = Point2d[]
            push!(cur, Point2d(c.lon0 + sign1 * _R2D, φxd))    # resume at the other side
        end
        push!(cur, Point2d(_lon(pts[i]), _lat(pts[i])))
        λprev = λ1d; φprev = φ1
    end
    length(cur) >= 1 && push!(subs, cur)
    return subs
end

function clip_line(c::CircleClip, pts)
    subs = Vector{Point2d}[]
    cur = Point2d[]
    n = length(pts)
    n == 0 && return subs
    vis(p) = _dot3(_cart(_lon(p), _lat(p)), c.axis) > c.cosr
    function crossing(a, b)                    # binary-search the great-circle crossing
        va = _cart(_lon(a), _lat(a)); vb = _cart(_lon(b), _lat(b)); ina = vis(a)
        lo, hi = 0.0, 1.0
        for _ in 1:48
            mid = (lo + hi) / 2
            (_dot3(_slerp(va, vb, mid), c.axis) > c.cosr) == ina ? (lo = mid) : (hi = mid)
        end
        _sph(_slerp(va, vb, (lo + hi) / 2))
    end
    keep(p) = c.mode === :seam || vis(p)
    keep(pts[1]) && push!(cur, Point2d(_lon(pts[1]), _lat(pts[1])))
    @inbounds for i in 2:n
        q = pts[i - 1]; p = pts[i]
        if vis(q) == vis(p)
            keep(p) && push!(cur, Point2d(_lon(p), _lat(p)))
        else
            xlon, xlat = crossing(q, p)
            push!(cur, Point2d(xlon, xlat))                 # finish at the boundary
            (c.mode === :seam || vis(q)) && !isempty(cur) && push!(subs, cur)
            cur = Point2d[]
            push!(cur, Point2d(xlon, xlat))                 # resume at the boundary
            keep(p) && push!(cur, Point2d(_lon(p), _lat(p)))
            if c.mode === :horizon && !vis(p)
                length(cur) >= 2 && push!(subs, cur)
                cur = Point2d[]
            end
        end
    end
    length(cur) >= 2 && push!(subs, cur)
    return subs
end

"""
    split_resample_line(pts, project, clip; scale=resample_scale(project)) -> Vector{Point2d}

Full line pipeline: clip `pts` at `clip`'s discontinuity, adaptively resample each visible
sub, and join with `NaN` breaks. Output is lon/lat (degrees) for the caller to project.
"""
function split_resample_line(pts, project, clip::SphereClip; scale::Float64 = NaN)
    isnan(scale) && (scale = resample_scale(project))
    subs = clip_line(clip, pts)
    out = Point2d[]
    for (k, s) in enumerate(subs)
        length(s) < 1 && continue
        k > 1 && !isempty(out) && push!(out, Point2d(NaN, NaN))
        append!(out, resample_sphere(s, project; scale = scale))
    end
    return out
end

############################################################
#              clip_strategy registry (per transform)      #
############################################################

# The destination transform's definition is a `+proj=pipeline +step …` string with
# several `+proj=`/`+lon_0=` occurrences; the *destination* projection is the LAST step,
# so parse the last match (matching the pre-existing seam-registry convention).
# PROJ writes the pipeline definition without `+` and with a word-boundary before each
# key (`proj=ortho lat_0=0 lon_0=0 …`), so match `\bkey=` (the `\b` stops `h=` matching
# inside `path=`, etc.).
function _proj_param(def::AbstractString, name; default = 0.0)
    val = default
    for m in eachmatch(Regex("\\b" * name * "=([-+0-9.eE]+)"), def)
        val = parse(Float64, m.captures[1])
    end
    return val
end
function _proj_name(def::AbstractString)
    name = ""
    for m in eachmatch(r"\bproj=(\w+)", def)
        m.captures[1] == "pipeline" && continue
        name = m.captures[1]
    end
    return name
end
# +pm may be a number or a named meridian; handle the common numeric case
_proj_pm(def::AbstractString) = _proj_param(def, "pm"; default = 0.0)

############################################################
#        Polygon (fill) clipping: d3 clip + rejoin         #
############################################################

# Signed spherical area of a lon/lat ring (steradians). ROTATION-INVARIANT — unlike a
# planar lon/lat shoelace it is correct for antimeridian-crossing and pole-enclosing rings.
# Its sign encodes winding; `_polygon_contains` treats a POSITIVE-area ring as enclosing
# its bounded interior (calibrated against d3's convention), so exteriors are wound
# positive and holes negative.
function _ring_area_sph(r)
    n = length(r)
    n < 3 && return 0.0
    a = 0.0
    @inbounds for i in 1:n
        p0 = r[i]; p1 = r[i == n ? 1 : i + 1]
        dλ = (p1[1] - p0[1]) * _D2R
        dλ = mod(dλ + π, 2π) - π
        a += dλ * (2.0 + sin(p0[2] * _D2R) + sin(p1[2] * _D2R))
    end
    return a / 2
end
# ensure a ring is wound positive (exterior, `want_pos=true`) or negative (hole)
_rewind(r, want_pos::Bool) = ((_ring_area_sph(r) > 0) == want_pos) ? r : reverse(r)

@inline _cross3(a, b) = (a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1])
@inline function _normalize3(v)
    n = _norm3(v)
    n < 1.0e-300 ? v : (v[1] / n, v[2] / n, v[3] / n)
end
@inline _pointeq(a, b) = abs(a[1] - b[1]) < 1.0e-9 && abs(a[2] - b[2]) < 1.0e-9

# Spherical point-in-polygon (port of d3-geo polygonContains.js). `polygon` is a vector
# of rings, each a vector of lon/lat (degrees) points; `point` is lon/lat (degrees).
function _polygon_contains(polygon, point)
    _lonr(p) = (l = p[1] * _D2R; abs(l) <= π ? l : sign(l) * ((abs(l) + π) % (2π) - π))
    λ = _lonr(point); φ = point[2] * _D2R
    sinφ = sin(φ)
    normal = (sin(λ), -cos(λ), 0.0)
    angle = 0.0; winding = 0; total = 0.0
    sinφ == 1 ? (φ = π / 2 + 1.0e-6) : sinφ == -1 ? (φ = -π / 2 - 1.0e-6) : nothing
    for ring in polygon
        m = length(ring); m == 0 && continue
        p0 = ring[m]
        λ0 = _lonr(p0); h0 = (p0[2] * _D2R) / 2 + π / 4
        sφ0 = sin(h0); cφ0 = cos(h0)
        for j in 1:m
            p1 = ring[j]
            λ1 = _lonr(p1); h1 = (p1[2] * _D2R) / 2 + π / 4
            sφ1 = sin(h1); cφ1 = cos(h1)
            δ = λ1 - λ0
            sgn = δ >= 0 ? 1.0 : -1.0
            aδ = sgn * δ
            anti = aδ > π
            k = sφ0 * sφ1
            total += atan(k * sgn * sin(aδ), cφ0 * cφ1 + k * cos(aδ))
            angle += anti ? δ + sgn * 2π : δ
            if xor(anti, xor(λ0 >= λ, λ1 >= λ))
                arc = _normalize3(_cross3(_cart(p0[1], p0[2]), _cart(p1[1], p1[2])))
                inter = _normalize3(_cross3(normal, arc))
                φarc = (xor(anti, δ >= 0) ? -1.0 : 1.0) * asin(clamp(inter[3], -1.0, 1.0))
                if φ > φarc || (φ == φarc && (arc[1] != 0 || arc[2] != 0))
                    winding += xor(anti, δ >= 0) ? 1 : -1
                end
            end
            λ0 = λ1; sφ0 = sφ1; cφ0 = cφ1; p0 = p1
        end
    end
    return xor(angle < -1.0e-6 || (angle < 1.0e-6 && total < -1.0e-12), (winding & 1) == 1)
end

# --- rejoin (port of d3-geo clip/rejoin.js) ---------------------------------
mutable struct _Ix
    x::Point2d
    z::Union{Nothing,Vector{Point2d}}
    o::Union{Nothing,_Ix}
    e::Bool
    v::Bool
    n::Union{Nothing,_Ix}
    p::Union{Nothing,_Ix}
end
_Ix(x, z, o, e) = _Ix(x, z, o, e, false, nothing, nothing)

function _link!(arr)
    isempty(arr) && return
    a = arr[1]
    @inbounds for i in 2:length(arr)
        b = arr[i]; a.n = b; b.p = a; a = b
    end
    a.n = arr[1]; arr[1].p = a
    return
end

# `interpolate!(from, to, dir, out)` appends boundary-arc points (lon/lat) to `out`;
# `from`/`to` are `Point2d` or `nothing` (whole boundary). `compare(a,b)` orders the
# clip intersections along the boundary. Returns closed rings (Vector{Point2d}).
function _rejoin(segments, compare, start_inside, interpolate!)
    rings = Vector{Point2d}[]
    subject = _Ix[]; clip = _Ix[]
    for seg in segments
        (length(seg) - 1) <= 0 && continue
        p0 = seg[1]; p1 = seg[end]
        if _pointeq(p0, p1)                      # closed, no intersections
            push!(rings, seg[1:end-1])
            continue
        end
        a = _Ix(p0, seg, nothing, true);  ao = _Ix(p0, nothing, a, false); a.o = ao
        b = _Ix(p1, seg, nothing, false); bo = _Ix(p1, nothing, b, true);  b.o = bo
        push!(subject, a); push!(clip, ao); push!(subject, b); push!(clip, bo)
    end
    isempty(subject) && return rings
    sort!(clip; lt = (a, b) -> compare(a.x, b.x) < 0)
    _link!(subject); _link!(clip)
    si = start_inside
    for c in clip
        si = !si; c.e = si
    end
    start = subject[1]
    while true
        current = start
        while current.v
            current = current.n
            current === start && return rings
        end
        ring = Point2d[]
        is_subject = true
        while true
            current.v = true; current.o.v = true
            if current.e
                if is_subject
                    for q in current.z; push!(ring, q); end
                else
                    interpolate!(current.x, current.n.x, 1, ring)
                end
                current = current.n
            else
                if is_subject
                    pts = current.p.z
                    for k in length(pts):-1:1; push!(ring, pts[k]); end
                else
                    interpolate!(current.x, current.p.x, -1, ring)
                end
                current = current.p
            end
            current = current.o
            is_subject = !is_subject
            current.v && break
        end
        push!(ring, ring[1])
        push!(rings, ring)
    end
    return rings
end

# rotation closures mapping the cap `axis` to/from the north pole (deg → deg)
function _pole_rot(axis)
    α = atan(axis[2], axis[1]); β = asin(clamp(axis[3], -1.0, 1.0))
    cα, sα = cos(α), sin(α); cβ, sβ = cos(β - π / 2), sin(β - π / 2)
    function to(lon, lat)            # Rz(-α) then Ry(β-90)
        v = _cart(lon, lat)
        x = v[1] * cα + v[2] * sα; y = -v[1] * sα + v[2] * cα; z = v[3]
        _sph((x * cβ + z * sβ, y, -x * sβ + z * cβ))
    end
    cβ2, sβ2 = cos(π / 2 - β), sin(π / 2 - β)
    function from(lon, lat)          # Ry(90-β) then Rz(α)
        v = _cart(lon, lat)
        x = v[1] * cβ2 + v[3] * sβ2; y = v[2]; z = -v[1] * sβ2 + v[3] * cβ2
        _sph((x * cα - y * sα, x * sα + y * cα, z))
    end
    return to, from
end

# densify a ring on the great circle so no edge exceeds `dl` degrees
function _densify_ring_sphere(ring, dl)
    out = Point2d[]
    n = length(ring)
    n == 0 && return out
    for i in 1:n
        a = ring[i]; b = ring[i == n ? 1 : i + 1]
        va = _cart(a[1], a[2]); vb = _cart(b[1], b[2])
        ω = acos(clamp(_dot3(va, vb), -1.0, 1.0)) * _R2D
        push!(out, Point2d(a[1], a[2]))
        nseg = max(1, ceil(Int, ω / dl))
        for k in 1:(nseg-1)
            l, t = _sph(_slerp(va, vb, k / nseg))
            push!(out, Point2d(l, t))
        end
    end
    return out
end

# clip a (densified) ring against the parallel lat=`latb` in the pole frame:
# keep lat>latb. Returns (segments, clean) à la d3 ringEnd.
function _clip_ring_parallel(ring, latb)
    n = length(ring)
    n == 0 && return (Vector{Vector{Point2d}}[], 1)
    vis(p) = p[2] > latb
    function cross(a, b)            # latitude crossing along the edge (linear in lat is fine post-densify)
        t = (latb - a[2]) / (b[2] - a[2])
        t = clamp(t, 0.0, 1.0)
        Point2d(a[1] + t * (b[1] - a[1]), latb)
    end
    segs = Vector{Point2d}[]
    cur = Point2d[]
    clean = 1
    v0 = vis(ring[1])
    vfirst = v0
    v0 && push!(cur, Point2d(ring[1][1], ring[1][2]))
    @inbounds for i in 2:(n+1)
        p = ring[i == n + 1 ? 1 : i]
        q = ring[i - 1]
        v = vis(p)
        if v != v0
            clean = 0
            x = cross(q, p)
            if v   # entering
                push!(cur, x)            # start point at boundary (cur should be empty)
            else   # exiting
                push!(cur, x)
                push!(segs, cur); cur = Point2d[]
            end
        end
        v && i <= n && push!(cur, Point2d(p[1], p[2]))
        v0 = v
    end
    !isempty(cur) && push!(segs, cur)
    # whole ring visible (no crossings)
    clean == 1 && return (vfirst ? Vector{Point2d}[ring isa Vector{Point2d} ? ring : Point2d[Point2d(p[1],p[2]) for p in ring]] : Vector{Point2d}[], 1)
    # rejoin first & last if both ends visible (d3 clean&2)
    if length(segs) > 1 && vfirst && vis(ring[n])
        last = pop!(segs); first = popfirst!(segs)
        pushfirst!(segs, vcat(last, first))
        clean = 2
    end
    return (segs, clean)
end

# Clip the rings of ONE polygon (exterior + holes) against `c` on the sphere.
# Returns a vector of closed lon/lat rings (exteriors and holes mixed, oriented).
function clip_fill(c::CircleClip, rings; dl = 1.0)
    to, from = _pole_rot(c.axis)
    latb = 90.0 - acosd(clamp(c.cosr, -1.0, 1.0))   # boundary colatitude
    # transform rings to pole frame + densify, then rewind to d3's winding convention
    # (exterior = positive spherical area, holes = negative) so containment/rejoin are correct
    pframe = [ _densify_ring_sphere([Point2d(to(p[1], p[2])...) for p in r], dl) for r in rings ]
    @inbounds for i in eachindex(pframe)
        pframe[i] = _rewind(pframe[i], i == 1)
    end
    segments = Vector{Point2d}[]
    whole = Vector{Point2d}[]
    for r in pframe
        segs, clean = _clip_ring_parallel(r, latb)
        if clean == 1
            isempty(segs) || append!(whole, segs)   # wholly visible ring
        else
            append!(segments, segs)
        end
    end
    # interpolate along the boundary parallel from `f` to `t`
    function interp!(f, t, dir, out)
        if f === nothing
            for lon in (dir > 0 ? (-180.0:5.0:180.0) : (180.0:-5.0:-180.0))
                push!(out, Point2d(lon, latb))
            end
            return
        end
        l0 = f[1]; l1 = t[1]
        d = l1 - l0
        d = mod(d + 180.0, 360.0) - 180.0          # shortest signed lon delta
        nseg = max(1, ceil(Int, abs(d) / 5.0))
        for k in 1:nseg
            push!(out, Point2d(l0 + d * k / nseg, latb))
        end
    end
    compare(a, b) = a[1] - b[1]                      # sort intersections by longitude
    out_rings = whole
    if !isempty(segments)
        start_inside = !_polygon_contains(pframe, Point2d(0.0, -90.0))   # south pole = invisible centre
        append!(out_rings, _rejoin(segments, compare, start_inside, interp!))
    end
    # back to lon/lat
    return [ Point2d[Point2d(from(p[1], p[2])...) for p in r] for r in out_rings ]
end

# Cut a ring at the antimeridian (tear at ±180 in the lon0-shifted frame); all points
# stay visible — we only split. Returns (segments, clean) à la d3 clipAntimeridianLine.
function _clip_ring_antimeridian(ring)
    n = length(ring)
    n == 0 && return (Vector{Point2d}[], 1)
    if n > 1 && _pointeq(ring[1], ring[n])           # drop duplicate closing vertex
        ring = ring[1:n-1]; n -= 1
    end
    segs = Vector{Point2d}[]
    cur = Point2d[]
    clean = 1
    λ0 = ring[1][1]; φ0 = ring[1][2]
    sign0 = λ0 > 0 ? 180.0 : -180.0
    push!(cur, Point2d(λ0, φ0))
    @inbounds for i in 2:(n+1)
        p = ring[i == n + 1 ? 1 : i]
        λ1 = p[1]; φ1 = p[2]
        sign1 = λ1 > 0 ? 180.0 : -180.0
        Δ = abs(λ1 - λ0)
        if abs(Δ - 180.0) < 1.0e-9                    # segment crosses a pole
            φm = (φ0 + φ1) / 2 > 0 ? 90.0 : -90.0
            push!(cur, Point2d(λ0, φm)); push!(cur, Point2d(sign0, φm))
            push!(segs, cur); cur = Point2d[]
            push!(cur, Point2d(sign1, φm)); push!(cur, Point2d(λ1, φm))
            clean = 0
        elseif sign0 != sign1 && Δ >= 180.0           # segment crosses the antimeridian
            φx = _antimeridian_lat(λ0 * _D2R, φ0 * _D2R, λ1 * _D2R, φ1 * _D2R) * _R2D
            push!(cur, Point2d(sign0, φx))
            push!(segs, cur); cur = Point2d[]
            push!(cur, Point2d(sign1, φx))
            clean = 0
        end
        i <= n && push!(cur, Point2d(λ1, φ1))
        λ0 = λ1; φ0 = φ1; sign0 = sign1
    end
    !isempty(cur) && push!(segs, cur)
    clean == 1 && return (Vector{Point2d}[copy(ring)], 1)
    if length(segs) > 1                               # closed ring ⇒ rejoin first & last
        lastseg = pop!(segs); firstseg = popfirst!(segs)
        pushfirst!(segs, vcat(lastseg, firstseg))
    end
    return (segs, 0)
end

# build a GeometryBasics polygon (exterior + holes) from a vector of lon/lat rings
function _gb_poly(rings)
    ext = Point2f[Point2f(p[1], p[2]) for p in rings[1]]
    length(rings) == 1 && return GeometryBasics.Polygon(ext)
    return GeometryBasics.Polygon(ext, [Point2f[Point2f(q[1], q[2]) for q in rings[i]] for i in 2:length(rings)])
end
# extract exterior + interior rings of a GB polygon as Vector{Vector{Point2d}}
function _gb_rings(gp)
    out = Vector{Point2d}[Point2d[Point2d(p[1], p[2]) for p in GeometryBasics.coordinates(gp.exterior)]]
    for h in gp.interiors
        push!(out, Point2d[Point2d(p[1], p[2]) for p in GeometryBasics.coordinates(h)])
    end
    return out
end

# Antimeridian fill: clip the polygon against the 360°-wide longitude window
# `[lon0-180, lon0+180]` (and the translated copies a wrapped/unwrapped ring spans) with
# `GeometryOps.intersection`, translating each piece back into the window. A meridian strip
# is a valid lon/lat rectangle, so this is robust for pole-enclosing polygons (Antarctica)
# and seam-crossing ones (Greenland) — no over-the-pole `interpolate` smear. Result is
# geometrically identical to d3's antimeridian split.
function clip_fill(c::AntimeridianClip, rings; dl = 1.0)
    lo = minimum(p[1] for r in rings for p in r)
    hi = maximum(p[1] for r in rings for p in r)
    if c.lon0 - 180.0 - 1.0e-6 <= lo && hi <= c.lon0 + 180.0 + 1.0e-6
        return [ Point2d[Point2d(p[1], p[2]) for p in r] for r in rings ]   # already inside the window
    end
    subj = _gb_poly(rings)
    kmin = floor(Int, (lo - (c.lon0 - 180.0)) / 360.0)
    kmax = floor(Int, (hi - (c.lon0 - 180.0)) / 360.0)
    out = Vector{Point2d}[]
    for k in kmin:kmax
        xlo = c.lon0 - 180.0 + 360.0 * k
        xhi = c.lon0 + 180.0 + 360.0 * k
        rect = GeometryBasics.Polygon(Point2f[Point2f(xlo, -90), Point2f(xhi, -90),
                                              Point2f(xhi, 90), Point2f(xlo, 90), Point2f(xlo, -90)])
        pieces = try
            GO.intersection(subj, rect; target = GI.PolygonTrait())
        catch
            continue
        end
        for gp in pieces, r in _gb_rings(gp)
            length(r) >= 4 && push!(out, Point2d[Point2d(p[1] - 360.0 * k, p[2]) for p in r])
        end
    end
    return out
end

clip_fill(::NoClip, rings; kw...) = [ Point2d[Point2d(p[1], p[2]) for p in r] for r in rings ]

############################################################
#     Rings → polygons, and the split_geometry frontend    #
############################################################

_collect_polys(p::GeometryBasics.Polygon) = GeometryBasics.Polygon[p]
_collect_polys(mp::GeometryBasics.MultiPolygon) = GeometryBasics.Polygon[p for p in mp.polygons]
_collect_polys(v) = isempty(v) ? GeometryBasics.Polygon[] : reduce(vcat, (_collect_polys(g) for g in v))

# rings of one GB polygon (exterior first, then holes) as Vector{Vector{Point2d}}
function _poly_rings(poly::GeometryBasics.Polygon)
    rings = Vector{Point2d}[]
    push!(rings, Point2d[Point2d(p[1], p[2]) for p in GeometryBasics.coordinates(poly.exterior)])
    for h in poly.interiors
        push!(rings, Point2d[Point2d(p[1], p[2]) for p in GeometryBasics.coordinates(h)])
    end
    return rings
end

_shoelace(r) = (s = 0.0; n = length(r); @inbounds for i in 1:n
        j = i == n ? 1 : i + 1
        s += r[i][1] * r[j][2] - r[j][1] * r[i][2]
    end; s / 2)

function _point_in_ring(pt, r)
    x = pt[1]; y = pt[2]; inside = false; n = length(r)
    j = n
    @inbounds for i in 1:n
        yi = r[i][2]; yj = r[j][2]
        if (yi > y) != (yj > y)
            xint = r[i][1] + (y - yi) / (yj - yi) * (r[j][1] - r[i][1])
            x < xint && (inside = !inside)
        end
        j = i
    end
    return inside
end

# Assemble clipped rings into GB polygons by CONTAINMENT NESTING — robust to the
# inconsistent winding the rejoin can emit. A ring's nesting depth (how many other rings
# contain it) decides exterior (even depth) vs hole (odd); each hole attaches to its
# immediate (smallest-area) containing exterior. Containment uses the spherical
# `_polygon_contains` on positive-normalised rings, so it is correct across the
# antimeridian and near the poles (planar tests are not).
function _rings_to_polygons(rings)
    valid = [r for r in rings if length(r) >= 4]
    isempty(valid) && return GeometryBasics.Polygon{2,Float32}[]
    n = length(valid)
    areas = [abs(_ring_area_sph(r)) for r in valid]
    norm = [_ring_area_sph(valid[i]) < 0 ? reverse(valid[i]) : valid[i] for i in 1:n]
    contains = falses(n, n)              # contains[j,i] = ring j encloses ring i
    @inbounds for i in 1:n, j in 1:n
        i == j && continue
        contains[j, i] = _polygon_contains([norm[j]], valid[i][1])
    end
    depth = [count(j -> contains[j, i], 1:n) for i in 1:n]
    ext_idx = [i for i in 1:n if iseven(depth[i])]
    hole_idx = [i for i in 1:n if isodd(depth[i])]
    assigned = Dict(i => Vector{Vector{Point2d}}() for i in ext_idx)
    for h in hole_idx
        best = 0; bestarea = Inf
        for e in ext_idx
            if contains[e, h] && areas[e] < bestarea
                bestarea = areas[e]; best = e
            end
        end
        best > 0 && push!(assigned[best], valid[h])
    end
    polys = GeometryBasics.Polygon{2,Float32}[]
    for e in ext_idx
        ext = Point2f[Point2f(p[1], p[2]) for p in valid[e]]
        hs = assigned[e]
        if isempty(hs)
            push!(polys, GeometryBasics.Polygon(ext))
        else
            push!(polys, GeometryBasics.Polygon(ext, [Point2f[Point2f(p[1], p[2]) for p in h] for h in hs]))
        end
    end
    return polys
end

"""
    split_geometry(geom, t::Proj.Transformation) -> Vector{Polygon}
    split_geometry(geom, dest::AbstractString)    -> Vector{Polygon}

Split polygonal `geom` at the destination transform's projection discontinuity (on the
sphere, via [`clip_strategy`](@ref)/[`clip_fill`](@ref)), returning lon/lat polygons ready
to `poly!` onto a matching `GeoAxis` without smearing across the tear.
"""
function split_geometry(geom, t::Proj.Transformation)
    clip = clip_strategy(t)
    out = GeometryBasics.Polygon{2,Float32}[]
    for p in _collect_polys(geom)
        clipped = clip_fill(clip, _poly_rings(p))
        densified = [ _densify_ring_sphere(r, 1.0) for r in clipped ]
        append!(out, _rings_to_polygons(densified))
    end
    return out
end
split_geometry(geom, dest::AbstractString) =
    split_geometry(geom, create_transform(dest, "+proj=longlat +datum=WGS84"))

"""
    clip_strategy(t) -> SphereClip

The discontinuity a destination transform `t` tears geometry along, as a sphere clip
(d3's per-projection `preclip` analog). `NoClip` for a non-`Proj` transform or `+over`.
Antimeridian by default; a `CircleClip` for azimuthal/perspective horizons. (Interrupted
and oblique-square boundaries are added in later phases as `PolygonClip`.)
"""
function clip_strategy(t::Proj.Transformation)
    info = Proj.proj_pj_info(t.pj)
    info.definition == C_NULL && return AntimeridianClip(0.0)
    def = unsafe_string(info.definition)
    occursin(r"\bover\b", def) && return NoClip()
    name = _proj_name(def)
    lon0 = _proj_param(def, "lon_0") + _proj_pm(def)
    lat0 = _proj_param(def, "lat_0")
    if name in ("ortho", "airy", "adams_hemi")
        return circle_clip(lon0, lat0, 89.5; mode = :horizon)
    elseif name in ("geos", "nsper", "tpers")
        R = 6378137.0
        h = _proj_param(def, "h"; default = 35786000.0)
        ρ = h > 0 ? acosd(R / (R + h)) : 89.5
        return circle_clip(lon0, lat0, max(ρ - 0.5, 1.0); mode = :horizon)
    end
    return AntimeridianClip(lon0)
end
clip_strategy(::Any) = NoClip()
