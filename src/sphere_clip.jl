#=
# Sphere-space clipping + adaptive resampling (d3-geo port)

Generic handling of projection discontinuities (antimeridian seam, azimuthal/perspective
horizons) the way d3-geo does it: clip geometry **on the sphere, before projection**, then
densify each piece with **adaptive bisection** so projected curves are smooth. Output stays
in lon/lat, so the existing GeoAxis pipeline (child plot projects per-vertex) is untouched.

This is a faithful port of d3-geo's *architecture*, not just its primitives:

    rotate → preclip → resample → project              (d3 projection/index.js)

We clip in a **rotated canonical frame** (the projection centre at [0,0], so the seam is
at ±180° and a horizon circle is centred at the origin), exactly as d3 does, then rotate
the result back to geographic lon/lat. The downstream Proj transform then re-applies its
own `+lon_0`/`+lat_0` rotation, so emitting geographic coordinates is correct.

A single generic clip driver ([`_clip_polygon`](@ref)/[`_clip_open`](@ref)) is parameterised
by a [`SphereClip`](@ref) supplying *visibility*, a *line clipper*, a boundary *interpolate*,
and a *start* seed — the same four hooks d3 feeds to `clip/index.js`. Antimeridian and circle
share the driver and `rejoin`, so there is no projected-space surgery and no `GeometryOps`
strip-clipping fallback.

Ports of:
- `d3-geo/src/projection/resample.js`  → [`resample_sphere`](@ref)
- `d3-geo/src/clip/index.js`           → [`_clip_polygon`](@ref) / [`_clip_open`](@ref)
- `d3-geo/src/clip/rejoin.js`          → [`_rejoin`](@ref)
- `d3-geo/src/clip/antimeridian.js`    → [`AntimeridianClip`](@ref)
- `d3-geo/src/clip/circle.js`          → [`CircleClip`](@ref)
- `d3-geo/src/polygonContains.js`      → [`_polygon_contains`](@ref)
- `d3-geo/src/rotation.js`             → [`_rotation`](@ref)

The discontinuity each destination transform tears along is chosen by [`clip_strategy`](@ref),
the analog of d3's per-projection `preclip`.

Geometry I/O goes through GeoInterface (`GI`) so the input type is irrelevant; the spherical
math (containment, great-circle intersections, rejoin) has no GO/GI equivalent and is ported.
=#

const _D2R = π / 180
const _R2D = 180 / π
const _EPS = 1.0e-6             # d3 epsilon (radians)

# unit cartesian of a lon/lat (degrees)
@inline _cart(lon, lat) = (c = cos(lat * _D2R); (c * cos(lon * _D2R), c * sin(lon * _D2R), sin(lat * _D2R)))
# unit cartesian -> (lon,lat) degrees
@inline function _sph(v)
    x, y, z = v
    (atan(y, x) * _R2D, asin(clamp(z, -1.0, 1.0)) * _R2D)
end
# radian versions (canonical-frame clip works in radians, like d3)
@inline _cartr(λ, φ) = (c = cos(φ); (c * cos(λ), c * sin(λ), sin(φ)))
@inline _sphr(v) = (atan(v[2], v[1]), asin(clamp(v[3], -1.0, 1.0)))

@inline _dot3(a, b) = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
@inline _norm3(v) = sqrt(_dot3(v, v))
@inline _cross3(a, b) = (a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1])
@inline function _normalize3(v)
    n = _norm3(v)
    n < 1.0e-300 ? v : (v[1] / n, v[2] / n, v[3] / n)
end

@inline _lon(p) = @inbounds Float64(p[1])
@inline _lat(p) = @inbounds Float64(p[2])
@inline _isfinitexy(xy) = isfinite(xy[1]) && isfinite(xy[2])

# wrap a longitude (radians) into (-π, π], d3 rotationIdentity
@inline _wrapλ(λ) = abs(λ) > π ? λ - round(λ / 2π) * 2π : λ

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
    else
        # `_sph` wraps lon into (-180,180]; the clip output may be intentionally unwrapped
        # (e.g. a seam piece at 330°..360°), so snap the midpoint to the endpoints' branch.
        target = (ll0[1] + ll1[1]) / 2
        lon2 += round((target - lon2) / 360.0) * 360.0
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
degrees) so that, once projected by `project(lon, lat) -> (x,y)`, the curve is smooth.
Returns lon/lat points (the caller's transform does the projecting). Midpoints are taken
on the sphere (great-circle); the error test is in projected space. `scale` converts
projected units to the threshold's units — see [`resample_scale`](@ref).

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

# A scale that makes `_DELTA2` correspond to a small fraction of the projected map size, so
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
    return 200.0 / span
end

############################################################
#              Spherical point-in-polygon                  #
############################################################

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

# Winding-independent containment: `_polygon_contains` follows d3-geo's convention (which is
# winding-sensitive), so we normalise each ring to positive spherical area first. `_ring_contains`
# is true iff `pt` (lon/lat deg) is inside the region bounded by one `ring`; `_inside_polygon`
# combines an exterior (`rings[1]`) with holes (`rings[2:end]`).
_ring_contains(ring, pt) = _polygon_contains([_ring_area_sph(ring) < 0 ? reverse(ring) : ring], pt)
function _inside_polygon(rings, pt)
    isempty(rings) && return false
    _ring_contains(rings[1], pt) || return false
    for i in 2:length(rings)
        _ring_contains(rings[i], pt) && return false
    end
    return true
end

# Signed spherical area of a lon/lat ring (steradians). Rotation-invariant; its sign encodes
# winding. Used for ring-nesting in [`_rings_to_polygons`](@ref) and the containment above.
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

############################################################
#                   Clip strategies                        #
############################################################

"""
    SphereClip

A preclip strategy (d3's per-projection `preclip` analog). Concrete types supply the four
hooks the generic clip driver needs: visibility, a line clipper, a boundary interpolate, and
a start seed, plus a rotation mapping the projection centre to the canonical frame.
"""
abstract type SphereClip end

"No discontinuity — pass geometry through unchanged (non-Proj / `+over`)."
struct NoClip <: SphereClip end

"""
    AntimeridianClip(lon0)

Tear at the meridian `lon0 ± 180` (the periodicity seam). Port of `clip/antimeridian.js`.
`lon0` (degrees) is the projection centre (`+lon_0 +pm`).
"""
struct AntimeridianClip <: SphereClip
    lon0::Float64
end

"""
    CircleClip(lon0, lat0, radius)

Small-circle horizon of angular `radius` (degrees) about the projection centre
`(lon0, lat0)` (degrees). Port of `clip/circle.js`: keep only the visible side. Works at
`radius = 90°` (a hemisphere) via the cartesian visibility test, where a lon/lat disk does
not exist.
"""
struct CircleClip <: SphereClip
    lon0::Float64
    lat0::Float64
    radius::Float64
end

# Internal clip-core point: (λ, φ, marker) in radians. `marker` carries d3's degeneracy
# flags (1 = coincident-intersection nudge, 2/3 = boundary-exit markers used by rejoin).
const _Pt = NTuple{3,Float64}
@inline _seg_pteq(a, b) = abs(a[1] - b[1]) < _EPS && abs(a[2] - b[2]) < _EPS

# --- rotation (d3 rotation.js): map projection centre → canonical [0,0] and back ----------
# Returns (forward, invert) closures (λ,φ)->(λ,φ) in radians. The antimeridian invert does
# NOT wrap longitude, so the two sides of a seam crossing stay on their own side once the
# downstream Proj transform re-subtracts `+lon_0` (a wrap would collapse them and overlap).
function _rotation(::NoClip)
    id = (λ, φ) -> (λ, φ)
    return id, id
end
function _rotation(c::AntimeridianClip)
    dλ = -c.lon0 * _D2R
    fwd = (λ, φ) -> (_wrapλ(λ + dλ), φ)
    inv = (λ, φ) -> (λ - dλ, φ)                # deliberately unwrapped
    return fwd, inv
end
function _rotation(c::CircleClip)
    dλ = -c.lon0 * _D2R; dφ = -c.lat0 * _D2R
    cφ = cos(dφ); sφ = sin(dφ)
    # forward: rotationLambda then rotationPhiGamma (γ=0), d3 compose order
    function fwd(λ, φ)
        λ = _wrapλ(λ + dλ)
        cosφ = cos(φ); x = cos(λ) * cosφ; y = sin(λ) * cosφ; z = sin(φ)
        k = z * cφ + x * sφ
        return (atan(y, x * cφ - z * sφ), asin(clamp(k, -1.0, 1.0)))
    end
    function inv(λ, φ)
        cosφ = cos(φ); x = cos(λ) * cosφ; y = sin(λ) * cosφ; z = sin(φ)
        λ2 = atan(y, x * cφ + z * sφ)
        φ2 = asin(clamp(z * cφ - x * sφ, -1.0, 1.0))
        return (λ2 - dλ, φ2)
    end
    return fwd, inv
end

# --- antimeridian crossing latitude (d3 clipAntimeridianIntersect), radians ---------------
@inline function _antimeridian_lat(λ0, φ0, λ1, φ1)
    s = sin(λ0 - λ1)
    abs(s) < _EPS && return (φ0 + φ1) / 2
    cφ0 = cos(φ0); cφ1 = cos(φ1)
    atan((sin(φ0) * cφ1 * sin(λ1) - sin(φ1) * cφ0 * sin(λ0)) / (cφ0 * cφ1 * s))
end

############################################################
#       Generic clip driver (port of clip/index.js)        #
############################################################

# Mutable buffer of line segments (d3 clip/buffer.js). A new segment starts on _lineStart!;
# lineEnd is implicit (the next _lineStart! opens the next segment).
mutable struct _LineSink
    lines::Vector{Vector{_Pt}}
end
_LineSink() = _LineSink(Vector{_Pt}[])
@inline _lineStart!(s::_LineSink) = (push!(s.lines, _Pt[]); nothing)
@inline _point!(s::_LineSink, λ, φ, m = 0.0) = (push!(s.lines[end], (λ, φ, m)); nothing)

# Intersections are sorted along the clip edge; the same comparator serves both antimeridian
# and circle (d3 compareIntersection).
@inline _ix_key(p) = p[1] < 0 ? p[2] - π / 2 - _EPS : π / 2 - p[2]
@inline _compare_ix(a, b) = _ix_key(a) - _ix_key(b)

# ---- antimeridian line clipper (d3 clipAntimeridianLine) --------------------------------
function _antimeridian_stream(feed)
    sink = _LineSink()
    _lineStart!(sink)
    λ0 = NaN; φ0 = NaN; sign0 = NaN; clean = 1
    @inbounds for q in feed
        λ1 = q[1]; φ1 = q[2]
        sign1 = λ1 > 0 ? π : -π
        δ = abs(λ1 - λ0)
        if abs(δ - π) < _EPS                       # crosses a pole
            φm = (φ0 + φ1) / 2 > 0 ? π / 2 : -π / 2
            _point!(sink, λ0, φm); _point!(sink, sign0, φm)
            _lineStart!(sink)
            _point!(sink, sign1, φm); _point!(sink, λ1, φm)
            φ0 = φm; clean = 0
        elseif sign0 != sign1 && δ >= π            # crosses the antimeridian
            abs(λ0 - sign0) < _EPS && (λ0 -= sign0 * _EPS)
            abs(λ1 - sign1) < _EPS && (λ1 -= sign1 * _EPS)
            φx = _antimeridian_lat(λ0, φ0, λ1, φ1)
            _point!(sink, sign0, φx)
            _lineStart!(sink)
            _point!(sink, sign1, φx)
            clean = 0
        end
        _point!(sink, λ1, φ1)
        λ0 = λ1; φ0 = φ1; sign0 = sign1
    end
    return sink.lines, clean
end

# ---- circle line clipper (d3 clip/circle.js clipLine) -----------------------------------
@inline function _circle_code(λ, φ, radius, smallR)
    r = smallR ? radius : π - radius
    code = 0
    if λ < -r; code |= 1; elseif λ > r; code |= 2; end
    if φ < -r; code |= 4; elseif φ > r; code |= 8; end
    return code
end

# Intersect great circle a→b with the clip circle (cos radius = cr). `two=false` returns one
# crossing (a `_Pt` or `nothing`); `two=true` returns the pair `((q,_), (q1,_))` or `nothing`.
function _circle_intersect(cr, a, b, two)
    pa = _cartr(a[1], a[2]); pb = _cartr(b[1], b[2])
    n2 = _cross3(pa, pb)
    n2n2 = _dot3(n2, n2)
    n1n2 = n2[1]
    det = n2n2 - n1n2 * n1n2
    det == 0 && return two ? nothing : (a[1], a[2], 0.0)
    c1 = cr * n2n2 / det
    c2 = -cr * n1n2 / det
    u = (0.0, -n2[3], n2[2])                       # n1 × n2, n1 = (1,0,0)
    A = (c1 + c2 * n2[1], c2 * n2[2], c2 * n2[3])
    w = _dot3(A, u); uu = _dot3(u, u)
    t2 = w * w - uu * (_dot3(A, A) - 1)
    t2 < 0 && return nothing
    t = sqrt(t2)
    s0 = (-w - t) / uu
    q = (A[1] + s0 * u[1], A[2] + s0 * u[2], A[3] + s0 * u[3])
    qλ, qφ = _sphr(q)
    !two && return (qλ, qφ, 0.0)
    # is the first crossing between a and b?
    λ0 = a[1]; λ1 = b[1]; φ0 = a[2]; φ1 = b[2]
    λ1 < λ0 && ((λ0, λ1) = (λ1, λ0))
    δ = λ1 - λ0
    polar = abs(δ - π) < _EPS
    meridian = polar || δ < _EPS
    (!polar && φ1 < φ0) && ((φ0, φ1) = (φ1, φ0))
    cond = meridian ?
        (polar ? xor(φ0 + φ1 > 0, qφ < (abs(qλ - λ0) < _EPS ? φ0 : φ1)) :
                 (φ0 <= qφ <= φ1)) :
        xor(δ > π, λ0 <= qλ <= λ1)
    cond || return nothing
    s1 = (-w + t) / uu
    q1 = (A[1] + s1 * u[1], A[2] + s1 * u[2], A[3] + s1 * u[3])
    q1λ, q1φ = _sphr(q1)
    return ((qλ, qφ, 0.0), (q1λ, q1φ, 0.0))
end

function _circle_stream(c::CircleClip, feed)
    cr = cos(c.radius * _D2R); smallR = cr > 0; notHemi = abs(cr) > _EPS
    radius = acos(clamp(cr, -1.0, 1.0))
    sink = _LineSink()
    point0 = nothing; code0 = 0; v0 = false; v00 = false; clean = 1
    @inline vis(λ, φ) = cos(λ) * cos(φ) > cr
    @inbounds for q in feed
        λ = q[1]; φ = q[2]
        point1 = (λ, φ, 0.0)
        v = vis(λ, φ)
        cde = smallR ? (v ? 0 : _circle_code(λ, φ, radius, smallR)) :
                       (v ? _circle_code(λ + (λ < 0 ? π : -π), φ, radius, smallR) : 0)
        if point0 === nothing
            v00 = v0 = v
            v && _lineStart!(sink)
        end
        if v != v0
            p2 = _circle_intersect(cr, point0, point1, false)
            (p2 === nothing || _seg_pteq(point0, p2) || _seg_pteq(point1, p2)) &&
                (point1 = (λ, φ, 1.0))
        end
        if v != v0
            clean = 0
            if v                                   # outside → in
                _lineStart!(sink)
                p2 = _circle_intersect(cr, point1, point0, false)
                _point!(sink, p2[1], p2[2])
                point0 = p2
            else                                   # inside → out
                p2 = _circle_intersect(cr, point0, point1, false)
                _point!(sink, p2[1], p2[2], 2.0)
                point0 = (p2[1], p2[2], 2.0)
            end
        elseif notHemi && point0 !== nothing && xor(smallR, v)
            if (cde & code0) == 0
                t = _circle_intersect(cr, point1, point0, true)
                if t !== nothing
                    clean = 0
                    if smallR
                        _lineStart!(sink)
                        _point!(sink, t[1][1], t[1][2])
                        _point!(sink, t[2][1], t[2][2])
                    else
                        _point!(sink, t[2][1], t[2][2])
                        _lineStart!(sink)
                        _point!(sink, t[1][1], t[1][2], 3.0)
                    end
                end
            end
        end
        if v && (point0 === nothing || !_seg_pteq(point0, point1))
            _point!(sink, point1[1], point1[2])
        end
        point0 = point1; v0 = v; code0 = cde
    end
    return sink.lines, (clean | ((v00 && v0) ? 2 : 0))
end

# ---- per-strategy hooks dispatched by the generic driver --------------------------------
_clip_ring(c::AntimeridianClip, ring) = (lines = _antimeridian_stream(vcat(ring, [ring[1]])); (lines[1], 2 - lines[2]))
_clip_ring(c::CircleClip, ring)       = _circle_stream(c, vcat(ring, [ring[1]]))

_clip_open(c::AntimeridianClip, line) = [l for l in _antimeridian_stream(line)[1] if length(l) > 1]
_clip_open(c::CircleClip, line)       = [l for l in _circle_stream(c, line)[1] if length(l) > 1]

_start(::AntimeridianClip) = (-π, -π / 2)
function _start(c::CircleClip)
    radius = c.radius * _D2R
    cos(radius) > 0 ? (0.0, -radius) : (-π, radius - π)
end

# boundary interpolate from `from` to `to` (radian `_Pt` or `nothing`), appending to `out`
function _interpolate!(::AntimeridianClip, from, to, dir, out)
    if from === nothing                            # whole sphere boundary
        φ = dir * π / 2
        for p in ((-π, φ), (0.0, φ), (π, φ), (π, 0.0), (π, -φ), (0.0, -φ), (-π, -φ), (-π, 0.0), (-π, φ))
            push!(out, (p[1], p[2], 0.0))
        end
    elseif abs(from[1] - to[1]) > _EPS             # across a pole
        λ = from[1] < to[1] ? π : -π
        φ = dir * λ / 2
        push!(out, (-λ, φ, 0.0)); push!(out, (0.0, φ, 0.0)); push!(out, (λ, φ, 0.0))
    else                                           # along the antimeridian
        push!(out, (to[1], to[2], 0.0))
    end
end
function _interpolate!(c::CircleClip, from, to, dir, out)
    radius = c.radius * _D2R
    _circle_stream_arc!(out, radius, 2 * _D2R, dir, from, to)
end

# d3 circle.js circleStream: walk the canonical circle (centred at origin) from `t0` to `t1`
function _circle_stream_arc!(out, radius, delta, dir, t0p, t1p)
    delta == 0 && return
    cosR = cos(radius); sinR = sin(radius)
    step = dir * delta
    if t0p === nothing
        t0 = radius + dir * 2π
        t1 = radius - step / 2
    else
        t0 = _circle_radius(cosR, t0p)
        t1 = _circle_radius(cosR, t1p)
        (dir > 0 ? t0 < t1 : t0 > t1) && (t0 += dir * 2π)
    end
    t = t0
    while dir > 0 ? t > t1 : t < t1
        λ, φ = _sphr((cosR, -sinR * cos(t), -sinR * sin(t)))
        push!(out, (λ, φ, 0.0))
        t -= step
    end
end
function _circle_radius(cosR, p)
    v = _cartr(p[1], p[2])
    v = _normalize3((v[1] - cosR, v[2], v[3]))
    r = acos(clamp(-v[2], -1.0, 1.0))
    return mod((-v[3] < 0 ? -r : r) + 2π - _EPS, 2π)
end

# ---- rejoin (port of clip/rejoin.js) ----------------------------------------------------
mutable struct _Ix
    x::_Pt
    z::Union{Nothing,Vector{_Pt}}
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

function _rejoin(segments, compare, start_inside, interpolate!)
    rings = Vector{_Pt}[]
    subject = _Ix[]; clip = _Ix[]
    for seg in segments
        (length(seg) - 1) <= 0 && continue
        p0 = seg[1]; p1 = seg[end]
        if _seg_pteq(p0, p1)
            if p0[3] == 0.0 && p1[3] == 0.0       # closed ring, no intersections
                push!(rings, seg[1:end-1])
                continue
            end
            p1 = (p1[1] + 2 * _EPS, p1[2], p1[3])  # nudge degenerate
            seg = vcat(seg[1:end-1], [p1])
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
        ring = _Pt[]
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

# Clip ONE polygon's rings (canonical-frame radian `_Pt`, exterior first) → closed rings.
# Port of clip/index.js polygonStart/ringEnd/polygonEnd.
function _clip_polygon(c::SphereClip, rings_rad)
    segments = Vector{_Pt}[]
    out = Vector{_Pt}[]
    for ring in rings_rad
        length(ring) < 2 && continue
        segs, clean = _clip_ring(c, ring)
        isempty(segs) && continue
        if (clean & 1) != 0                        # no intersections: wholly visible ring
            length(segs[1]) > 1 && push!(out, segs[1])
            continue
        end
        if length(segs) > 1 && (clean & 2) != 0    # rejoin first & last segment
            segs = vcat([vcat(segs[end], segs[1])], segs[2:end-1])
        end
        for s in segs
            length(s) > 1 && push!(segments, s)
        end
    end
    poly_deg = [[(_R2D * p[1], _R2D * p[2]) for p in ring] for ring in rings_rad]
    st = _start(c); st_deg = (_R2D * st[1], _R2D * st[2])
    if !isempty(segments)
        start_inside = _inside_polygon(poly_deg, st_deg)
        append!(out, _rejoin(segments, _compare_ix, start_inside, (f, t, d, o) -> _interpolate!(c, f, t, d, o)))
    elseif isempty(out) && !isempty(rings_rad) && _inside_polygon(poly_deg, st_deg)
        r = _Pt[]                                  # clip region entirely inside polygon ⇒ fill it
        _interpolate!(c, nothing, nothing, 1, r)
        push!(r, r[1])
        push!(out, r)
    end
    return out
end

############################################################
#        Rings → polygons (nesting for Makie holes)        #
############################################################

# planar shoelace area and even-odd point-in-ring (on PROJECTED coordinates)
function _planar_area(r)
    s = 0.0; n = length(r)
    @inbounds for i in 1:n
        j = i == n ? 1 : i + 1
        s += r[i][1] * r[j][2] - r[j][1] * r[i][2]
    end
    return s / 2
end
function _point_in_ring(pt, r)
    x = pt[1]; y = pt[2]; inside = false; n = length(r); j = n
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

# Assemble clipped rings into GB polygons by CONTAINMENT NESTING (d3's even-odd fill has no
# explicit holes; Makie's `Polygon` needs them). A ring's depth (how many rings contain it)
# decides exterior (even) vs hole (odd); each hole attaches to its smallest containing
# exterior. Nesting is decided in PROJECTED space — where seam pieces (adjacent on the sphere
# but at opposite map edges) are genuinely separate and holes nest as the renderer sees them.
# Output geometry stays lon/lat (the GeoAxis transform re-projects it).
function _rings_to_polygons(rings, project)
    valid = [r for r in rings if length(r) >= 4]
    isempty(valid) && return GeometryBasics.Polygon{2,Float32}[]
    n = length(valid)
    proj = [[project(p[1], p[2]) for p in r] for r in valid]
    # a finite representative vertex per ring (rings are visible ⇒ finite, but guard anyway)
    rep = Vector{NTuple{2,Float64}}(undef, n)
    keep = trues(n)
    for i in 1:n
        k = findfirst(_isfinitexy, proj[i])
        k === nothing ? (keep[i] = false) : (rep[i] = (proj[i][k][1], proj[i][k][2]))
    end
    areas = [keep[i] ? abs(_planar_area([q for q in proj[i] if _isfinitexy(q)])) : 0.0 for i in 1:n]
    contains = falses(n, n)              # contains[j,i] = ring j encloses ring i
    @inbounds for i in 1:n, j in 1:n
        (i == j || !keep[i] || !keep[j]) && continue
        contains[j, i] = _point_in_ring(rep[i], proj[j])
    end
    depth = [count(j -> contains[j, i], 1:n) for i in 1:n]
    ext_idx = [i for i in 1:n if keep[i] && iseven(depth[i])]
    hole_idx = [i for i in 1:n if keep[i] && isodd(depth[i])]
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

############################################################
#         Geometry I/O (via GeoInterface) + frontends      #
############################################################

# rings of one polygon (exterior first, then holes) as Vector{Vector{Point2d}}, via GI so any
# GI-compatible geometry works (and we never touch concrete `.exterior`/`.interiors` fields).
function _poly_rings(poly)
    rings = Vector{Point2d}[]
    ext = GI.getexterior(poly)
    push!(rings, Point2d[Point2d(GI.x(p), GI.y(p)) for p in GI.getpoint(ext)])
    for i in 1:GI.nhole(poly)
        h = GI.gethole(poly, i)
        push!(rings, Point2d[Point2d(GI.x(p), GI.y(p)) for p in GI.getpoint(h)])
    end
    return rings
end

_collect_polys(p::GeometryBasics.Polygon) = GeometryBasics.Polygon[p]
_collect_polys(mp::GeometryBasics.MultiPolygon) = GeometryBasics.Polygon[p for p in mp.polygons]
_collect_polys(v) = isempty(v) ? GeometryBasics.Polygon[] : reduce(vcat, (_collect_polys(g) for g in v))

# project closure for the resampler / scale, from a Proj transform (lon,lat) -> (x,y)
_projector(t) = (lon, lat) -> (p = t(lon, lat); (Float64(p[1]), Float64(p[2])))

# Seam boundary vertices land at exactly rotated ±π. PROJ's longitude range is half-open, so
# the +π side (e.g. lon 360°) wraps to the *opposite* map edge (x = −180 instead of +180),
# smearing the piece across. Pull such vertices a hair inside the range so each lands on its
# own edge. (Only meaningful for the antimeridian seam; the circle horizon is elsewhere.)
const _SEAM_NUDGE = 1.0e-9
@inline function _unrotate(inv, λ, φ, seam)
    seam && abs(abs(λ) - π) < 1.0e-6 && (λ = sign(λ) * (π - _SEAM_NUDGE))
    ll = inv(λ, φ)
    return (ll[1] * _R2D, ll[2] * _R2D)
end

# Clip one polygon (given as lon/lat rings, exterior first) at `clip`, resample each piece,
# and assemble into GB polygons. The full d3 pipeline for fills.
#
# `rotated=false` (default): emit geographic lon/lat (un-rotated); the caller draws with the
# full `+lon_0` transform. `project` must be that full projector. Used for circle/NoClip and
# the standalone `split_geometry`.
#
# `rotated=true` (Option B, antimeridian only): emit coordinates in the CANONICAL ROTATED
# frame and let the caller draw with the CENTRED transform (`+lon_0=0`). Because
# `centred ∘ rotate == full` exactly for a pure-longitude rotation, the plot lands in the same
# projected space as the axis — but the seam now sits at rotated ±180°, which the centred
# projection maps to distinct edges, so there is no longitude-wrap collapse and no nudge.
# `project` must be the CENTRED projector.
function _split_polygon(clip::SphereClip, rings_deg, project, scale; rotated::Bool = false)
    clip isa NoClip && return _rings_to_polygons(rings_deg, project)
    fwd, inv = _rotation(clip)
    seam = clip isa AntimeridianClip
    rings_rad = [[(q = fwd(p[1] * _D2R, p[2] * _D2R); (q[1], q[2], 0.0)) for p in r] for r in rings_deg]
    clipped = _clip_polygon(clip, rings_rad)
    isempty(clipped) && return GeometryBasics.Polygon{2,Float32}[]
    out_deg = Vector{Point2d}[]
    for r in clipped
        rd = Point2d[]
        for q in r
            if rotated
                push!(rd, Point2d(q[1] * _R2D, q[2] * _R2D))      # keep the canonical rotated frame
            else
                lon, lat = _unrotate(inv, q[1], q[2], seam)
                push!(rd, Point2d(lon, lat))
            end
        end
        isempty(rd) && continue
        rd[end] != rd[1] && push!(rd, rd[1])                  # close
        push!(out_deg, resample_sphere(rd, project; scale = scale))
    end
    return _rings_to_polygons(out_deg, project)
end

"""
    split_geometry(geom, t::Proj.Transformation) -> Vector{Polygon}
    split_geometry(geom, dest::AbstractString)    -> Vector{Polygon}

Split polygonal `geom` at the destination transform's projection discontinuity (on the
sphere, via [`clip_strategy`](@ref)), adaptively resample, and return lon/lat polygons ready
to `poly!` onto a matching `GeoAxis` without smearing across the tear.
"""
function split_geometry(geom, t::Proj.Transformation)
    clip = clip_strategy(t)
    project = _projector(t)
    scale = resample_scale(project)
    out = GeometryBasics.Polygon{2,Float32}[]
    for p in _collect_polys(geom)
        append!(out, _split_polygon(clip, _poly_rings(p), project, scale))
    end
    return out
end
split_geometry(geom, dest::AbstractString) =
    split_geometry(geom, create_transform(dest, "+proj=longlat +datum=WGS84"))

"""
    split_resample_line(pts, t::Proj.Transformation; scale=auto) -> Vector{Point2d}

Clip an open lon/lat polyline `pts` at `t`'s discontinuity, adaptively resample each visible
sub-line, and join with `NaN` breaks. Output is lon/lat for the caller's transform to project.
"""
function split_resample_line(pts, t::Proj.Transformation; scale::Float64 = NaN)
    clip = clip_strategy(t)
    project = _projector(t)
    isnan(scale) && (scale = resample_scale(project))
    clip isa NoClip &&
        return resample_sphere(Point2d[Point2d(_lon(p), _lat(p)) for p in pts], project; scale = scale)
    fwd, inv = _rotation(clip)
    seam = clip isa AntimeridianClip
    line_rad = [(q = fwd(_lon(p) * _D2R, _lat(p) * _D2R); (q[1], q[2], 0.0)) for p in pts]
    out = Point2d[]
    for (k, s) in enumerate(_clip_open(clip, line_rad))
        isempty(s) && continue
        sd = [Point2d(_unrotate(inv, q[1], q[2], seam)...) for q in s]
        k > 1 && !isempty(out) && push!(out, Point2d(NaN, NaN))
        append!(out, resample_sphere(sd, project; scale = scale))
    end
    return out
end

############################################################
#        clip_strategy registry (per-transform preclip)    #
############################################################

# The destination transform's definition is a `+proj=pipeline +step …` string; the
# *destination* projection is the LAST step, so the last `proj=`/`lon_0=`/… match wins. PROJ
# writes keys without `+` and with a word boundary, so match `\bkey=`.
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
_proj_pm(def::AbstractString) = _proj_param(def, "pm"; default = 0.0)

"""
    clip_strategy(t) -> SphereClip

The discontinuity a destination transform `t` tears geometry along, as a [`SphereClip`](@ref)
(d3's per-projection `preclip` analog). `NoClip` for a non-`Proj` transform or `+over`;
`CircleClip` for azimuthal/perspective horizons; `AntimeridianClip` otherwise.
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
        return CircleClip(lon0, lat0, 89.5)
    elseif name in ("geos", "nsper", "tpers")
        R = 6378137.0
        h = _proj_param(def, "h"; default = 35786000.0)
        ρ = h > 0 ? acosd(R / (R + h)) : 89.5
        return CircleClip(lon0, lat0, max(ρ - 0.5, 1.0))
    end
    return AntimeridianClip(lon0)
end
clip_strategy(::Any) = NoClip()
