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

Geometry I/O goes through GeoInterface (`GI`) so the input type is irrelevant. The clip driver,
the d3 antimeridian/circle seam logic, the projection-adaptive `resample_sphere`, and the
winding point-in-polygon (`_polygon_contains`) are ported because they have no GeometryOps
equivalent (GO's `Spherical()` clip is polygon∩polygon; its predicates and resampler are planar /
distance-based, not seam-aware or projection-adaptive).

What DOES defer to the lower-level packages:
- planar helpers on already-projected points — the oblique-square boundary's convex hull and
  Douglas–Peucker simplify — defer to `GO.convex_hull` / `GO.simplify`;
- the great-circle interpolation (`_geo_interp`) and angular distance (`_gcdist_deg`) used by the
  boundary builders defer to `GO.UnitSpherical.slerp` / `spherical_distance`.

Deliberately NOT delegated (investigated, see HANDOFF.md):
- the `PolygonClip` spherical clip (`_clip_against_polygon`) is NOT routed through
  `GO.intersection(GO.Spherical(), …)`: GO's Foster–Hormann clip computes edge intersections with
  *planar* lon/lat math regardless of manifold (`_intersection_point`/`_find_cross_intersection`
  are planar; the source itself notes "spherical/geodesic will need s2 support at some point"), so
  delegating would regress correctness exactly on the seam-crossing edges this code exists for;
- the `NTuple{3}` math primitives (`_cart`/`_sph`/`_dot3`/…) and the line-by-line d3 ports stay
  hand-rolled: they benchmark identical to UnitSpherical and mirror the d3-geo source verbatim.
=#

const _D2R = π / 180
const _R2D = 180 / π
const _EPS = 1.0e-6             # d3 epsilon (radians)
const _EPS2 = 1.0e-12           # d3 epsilon2 (squared tolerance for exact-point tests)

# Lower-level spherical primitives we delegate to GeometryOps.UnitSpherical (a tuple ⇄
# UnitSphericalPoint conversion that benchmarks neutral, see HANDOFF P2). Used for the
# great-circle interpolation (`slerp`, antipodal-robust) and angular distance
# (`spherical_distance`) in the boundary builders below. The hand-rolled `NTuple{3}` math
# primitives and the line-by-line d3 ports are kept as-is: they benchmark identical and
# mirror the d3-geo source for verifiability.
const _US_FROM_GEO = GO.UnitSpherical.UnitSphereFromGeographic()  # (lon,lat)° → UnitSphericalPoint
const _GEO_FROM_US = GO.UnitSpherical.GeographicFromUnitSphere()  # UnitSphericalPoint → (lon,lat)°

# unit cartesian of a lon/lat (degrees) — delegated to UnitSpherical's `UnitSphereFromGeographic`
# (identical maths: sinϕ·cosθ with ϕ=90−lat, θ=lon; benchmarks identical to the hand-rolled form).
# Returns the `NTuple{3,Float64}` the d3 ports thread through.
@inline _cart(lon, lat) = (p = _US_FROM_GEO((Float64(lon), Float64(lat))); (p[1], p[2], p[3]))
# unit cartesian -> (lon,lat) degrees. Kept hand-rolled: UnitSpherical's `GeographicFromUnitSphere`
# does NOT `clamp(z, -1, 1)`, so on a normalised vector with |z| a hair over 1 (FP) it throws a
# DomainError where this must stay total. (Filed upstream — see HANDOFF.)
@inline function _sph(v)
    x, y, z = v
    return (atan(y, x) * _R2D, asin(clamp(z, -1.0, 1.0)) * _R2D)
end
# radian versions (canonical-frame clip works in radians, like d3). Kept hand-rolled: UnitSpherical
# only exposes a degrees transform, so routing the hot radian-native clip through it would add a
# rad→deg→rad round-trip per call (a real regression in `_cp_clip_line`).
@inline _cartr(λ, φ) = (c = cos(φ); (c * cos(λ), c * sin(λ), sin(φ)))
@inline _sphr(v) = (atan(v[2], v[1]), asin(clamp(v[3], -1.0, 1.0)))

@inline _dot3(a, b) = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
@inline _norm3(v) = sqrt(_dot3(v, v))
@inline _cross3(a, b) = (a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1])
@inline function _normalize3(v)
    n = _norm3(v)
    return n < 1.0e-300 ? v : (v[1] / n, v[2] / n, v[3] / n)
end

@inline _cart_eq(a, b) = abs(a[1] - b[1]) < _EPS2 && abs(a[2] - b[2]) < _EPS2 && abs(a[3] - b[3]) < _EPS2

# Great-circle segment intersection (port of d3-geo-polygon intersect.js). `_IxSeg` precomputes
# the edge normals; `_gc_intersect` returns the intersection unit vector of two segments (or
# `nothing`), `_gc_point_on_line` tests whether a point lies on a segment.
struct _IxSeg
    from::NTuple{3, Float64}
    to::NTuple{3, Float64}
    normal::NTuple{3, Float64}
    fromNormal::NTuple{3, Float64}
    toNormal::NTuple{3, Float64}
    l::Float64
end
function _ixseg(from, to)
    n = _cross3(from, to)
    return _IxSeg(from, to, n, _cross3(n, from), _cross3(n, to), acos(clamp(_dot3(from, to), -1.0, 1.0)))
end
function _gc_intersect(a::_IxSeg, b::_IxSeg)
    (_cart_eq(a.from, b.from) || _cart_eq(a.from, b.to)) && return a.from
    (_cart_eq(a.to, b.from) || _cart_eq(a.to, b.to)) && return a.to
    lc = (a.l + b.l < π) ? cos(a.l + b.l) - _EPS : -1.0
    (
        _dot3(a.from, b.from) < lc || _dot3(a.from, b.to) < lc ||
            _dot3(a.to, b.from) < lc || _dot3(a.to, b.to) < lc
    ) && return nothing
    cx = _cross3(a.normal, b.normal)
    # degenerate (zero-length segment → zero normal, or parallel great circles): d3's
    # cartesianNormalize yields NaN here, which fails the on-arc comparisons → no intersection.
    # `_normalize3` instead returns the zero vector, which would spuriously pass `0≥0 && 0≤0`.
    _norm3(cx) < _EPS2 && return nothing
    axb = _normalize3(cx)
    a0 = _dot3(axb, a.fromNormal); a1 = _dot3(axb, a.toNormal)
    b0 = _dot3(axb, b.fromNormal); b1 = _dot3(axb, b.toNormal)
    (a0 >= 0 && a1 <= 0 && b0 >= 0 && b1 <= 0) && return axb
    (a0 <= 0 && a1 >= 0 && b0 <= 0 && b1 >= 0) && return (-axb[1], -axb[2], -axb[3])
    return nothing
end
function _gc_point_on_line(p, a::_IxSeg)
    a0 = _dot3(p, a.fromNormal); a1 = _dot3(p, a.toNormal); pp = _dot3(p, a.normal)
    return abs(pp) < _EPS^2 && ((a0 > -_EPS^2 && a1 < _EPS^2) || (a0 < _EPS^2 && a1 > -_EPS^2))
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
const _DELTA2 = 0.5         # d3 default precision² (projected units after scaling)
const _COSMIN = cos(30 * _D2R)   # d3 cosMinDistance

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

"""
    resample_scale(project) -> Float64

Estimate a scale factor that makes the resampling threshold `_DELTA2` correspond to a small
fraction of the projected map size, so the same threshold behaves consistently across
projections with wildly different units (degrees vs metres). `project(lon, lat) -> (x, y)` is
sampled on a coarse lon/lat grid to estimate the projected span. Used as the `scale` argument
to [`resample_sphere`](@ref).
"""
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

# Spherical area (steradians, range [0, 4π]) of the region a lon/lat ring BOUNDS under d3's
# winding convention (port of d3-geo area.js). A ring traversed so its interior is the small
# region returns < 2π; one traversed the other way (interior = complement) returns > 2π. We use
# this to canonicalise Makie's arbitrarily-wound contourf bands before clipping — a band wound
# as its own complement would otherwise be clipped to fill (nearly) the whole map.
function _geo_area(ring)
    n = length(ring)
    n < 3 && return 0.0
    λ0 = ring[1][1] * _D2R
    h = (ring[1][2] * _D2R) / 2 + π / 4
    cosφ0 = cos(h); sinφ0 = sin(h)
    s = 0.0
    @inbounds for i in 2:(n + 1)
        p = ring[i <= n ? i : 1]
        λ = p[1] * _D2R; φ = (p[2] * _D2R) / 2 + π / 4
        dλ = λ - λ0; sd = dλ >= 0 ? 1.0 : -1.0; ad = sd * dλ
        cosφ = cos(φ); sinφ = sin(φ)
        k = sinφ0 * sinφ
        s += atan(k * sd * sin(ad), cosφ0 * cosφ + k * cos(ad))
        λ0 = λ; cosφ0 = cosφ; sinφ0 = sinφ
    end
    return 2 * (s < 0 ? 2π + s : s)
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
    AntimeridianClip(lon0, lat_max = 90)

Tear at the meridian `lon0 ± 180` (the periodicity seam). Port of `clip/antimeridian.js`.
`lon0` (degrees) is the projection centre (`+lon_0 +pm`). `lat_max < 90` additionally clamps
geometry/boundary to ±`lat_max` for normal Mercator (merc/webmerc), whose y → ±∞ at the poles —
otherwise Antarctica (and the spine's ±90) blow the y-limits to ~12× the useful map.
"""
struct AntimeridianClip <: SphereClip
    lon0::Float64
    lat_max::Float64
end
AntimeridianClip(lon0) = AntimeridianClip(lon0, 90.0)

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

"""
    ObliqueAntimeridianClip(fwd, inv, centred)

Antimeridian seam in a *rotated* (oblique) frame, drawn with Option B via a NATIVE centred
projector. `fwd`/`inv` rotate geographic ↔ the oblique frame (radians); the clip cuts at the
rotated antimeridian, and `centred::_NativeCentred` projects the rotated-frame split directly to
metres — exactly d3's `rotate(...) → clipAntimeridian → centredProjection`. Drawing in the rotated
frame (rather than unrotating back through PROJ) is essential: PROJ's `atan2` collapses the ±π
seam onto one edge, smearing geometry that straddles it (Antarctica on bertin).

Used for **bertin1953** (a rotated, fudged Hammer that PROJ ships with no inverse): see
[`_bertin_rotation`](@ref)/[`_bertin_centred`](@ref). NOT used for spilhaus — that's a *square*
(adams) whose oblique pole is a sharp corner the antimeridian pole-walk can't match, so it stays
on the no-smear [`PolygonClip`] hull (rounded corners, documented workaround).
"""
# A native (non-PROJ) centred projector: rotated lon/lat (deg) → projected metres, callable both
# as `c((lon,lat))` (for `_projector`) and via `Makie.apply_transform` (as a child transform_func),
# so Option B works for an oblique projection whose "centred" frame PROJ doesn't expose (bertin).
struct _NativeCentred
    f::Function
end
(c::_NativeCentred)(p) = c.f(p[1], p[2])
function Makie.apply_transform(c::_NativeCentred, p::Makie.VecTypes)
    xy = c.f(p[1], p[2])
    return length(p) == 3 ? Makie.Point3{Float64}(xy[1], xy[2], p[3]) : Makie.Point2{Float64}(xy[1], xy[2])
end
Makie.apply_transform(c::_NativeCentred, ps::AbstractArray) = map(p -> Makie.apply_transform(c, p), ps)
function Makie.apply_transform(c::_NativeCentred, r::Makie.Rect2{T}) where {T}
    mn = minimum(r); mx = maximum(r)
    (umin, umax), (vmin, vmax) = iterated_bounds(c, (mn[1], mx[1]), (mn[2], mx[2]))
    return Makie.Rect2{T}(Makie.Vec2{T}(umin, vmin), Makie.Vec2{T}(umax - umin, vmax - vmin))
end
# A plot's data limits arrive as a Rect3; without this, Makie projects the box's CORNERS, which for
# a nonlinear projection under-estimates the extent (a bertin land box's corners sit at high
# latitude where the ellipse is narrow → the map auto-zoomed to a cropped strip). Sample via the
# Rect2 method (iterated_bounds) instead, mirroring `apply_transform(::Proj.Transformation, ::Rect3)`.
function Makie.apply_transform(c::_NativeCentred, r::Makie.Rect3{T}) where {T}
    r2 = Makie.apply_transform(c, Makie.Rect2{T}(r))
    return Makie.Rect3{T}((Makie.origin(r2)..., r.origin[3]), (Makie.widths(r2)..., r.widths[3]))
end
# Geometry overloads (defensive): Makie has no generic apply_transform(f, ::Polygon/LineString) and
# special-cases Proj.Transformation, so a native transform should handle these too for any code path
# that transforms a geometry directly. (Makie's poly!/lines! recipes actually transform the decomposed
# point arrays, so the array method already covers the common case — these are belt-and-suspenders.)
Makie.apply_transform(c::_NativeCentred, p::GeometryBasics.Polygon) =
    GeometryBasics.Polygon(
    Makie.apply_transform(c, GeometryBasics.coordinates(p.exterior)),
    [Makie.apply_transform(c, GeometryBasics.coordinates(i)) for i in p.interiors]
)
Makie.apply_transform(c::_NativeCentred, ls::GeometryBasics.LineString) =
    GeometryBasics.LineString(Makie.apply_transform(c, GeometryBasics.coordinates(ls)))
Makie.apply_transform(c::_NativeCentred, mp::GeometryBasics.MultiPolygon) =
    GeometryBasics.MultiPolygon([Makie.apply_transform(c, p) for p in mp.polygons])
Makie.apply_transform(c::_NativeCentred, ml::GeometryBasics.MultiLineString) =
    GeometryBasics.MultiLineString([Makie.apply_transform(c, l) for l in ml.linestrings])

struct ObliqueAntimeridianClip <: SphereClip
    fwd::Function
    inv::Function
    centred::_NativeCentred   # rotated lon/lat (deg) → metres; draw the rotated split with this
end

"""
    ProjectedClip()

Lighter fallback for projections whose tear is an arbitrary curve with no simple analytic
sphere boundary — oblique squares (`spilhaus`/`guyou`/`ob_tran`/`ocea`/`oea`) and interrupted
lobes (`igh`/`igh_o`/`imoll`/`goode`). Rather than clip on the sphere, we densify in lon/lat,
project, and break the line wherever the **projected** segment jumps abnormally (cartopy-style,
validated for `spilhaus`). Output stays geographic + full transform. (A future phase will add a
faithful d3 `clipPolygon` against the inverse-projected boundary.)
"""
struct ProjectedClip <: SphereClip end

"""
    PolygonClip(boundary)

Clip against an arbitrary spherical polygon `boundary` (vector of lon/lat-degree rings) — d3's
`clipPolygon`. Used for oblique squares (boundary derived by inverse-projecting the projected
outline, d3 `reclip`) and interrupted lobes (explicit lobe polygon). `segs` are the boundary
edges as precomputed great-circle `_IxSeg`s (radians) for fast intersection.
"""
struct PolygonClip <: SphereClip
    boundary::Vector{Vector{Point2d}}        # lon/lat degree rings
    segs::Vector{_IxSeg}                      # boundary edges (cartesian, radians)
    flat::Vector{Point2d}                     # first ring, for polygonContains start
end
function PolygonClip(boundary::Vector{<:AbstractVector})
    rings = [Point2d[Point2d(p[1], p[2]) for p in r] for r in boundary]
    # Orient so the boundary bounds its LARGER region — the projection interior (≈ the whole
    # sphere for an oblique square). Otherwise `polygonContains` treats mapped geometry as
    # OUTSIDE and the clip fills the entire domain.
    _geo_area(rings[1]) < 2π && (rings[1] = reverse(rings[1]))
    segs = _IxSeg[]
    for r in rings, i in 2:length(r)
        push!(segs, _ixseg(_cartr(r[i - 1][1] * _D2R, r[i - 1][2] * _D2R), _cartr(r[i][1] * _D2R, r[i][2] * _D2R)))
    end
    return PolygonClip(rings, segs, rings[1])
end

# --- boundary derivation (d3 reclip): inverse-project the projected outline -----------------
const _BOUNDARY_CACHE = Dict{String, Vector{Vector{Point2d}}}()

# Oblique squares (spilhaus/guyou/…): trace the projected outline by binary-searching, in many
# directions from the projected centre, the radius where the inverse stops being finite, then
# inverse-project (inset by R) to get a single spherical boundary ring. (d3 streams `.sphere()`.)
# great-circle distance (degrees) between two lon/lat points (delegated to UnitSpherical's
# `spherical_distance`, the numerically-stable atan2(‖a×b‖, a·b) form; matches the old
# acos-of-dot to ~1e-6° and is stable for near-coincident points).
_gcdist_deg(a, b) = _R2D * GO.UnitSpherical.spherical_distance(
    _US_FROM_GEO((Float64(a[1]), Float64(a[2]))), _US_FROM_GEO((Float64(b[1]), Float64(b[2])))
)

# Exterior ring of a GI polygon as an OPEN Point2d vector (drop the closing duplicate vertex, if
# any). Used to read back GeometryOps' convex-hull / simplify output for the boundary trace below.
function _exterior_open(poly)
    r = GI.getexterior(poly)
    pts = Point2d[Point2d(GI.x(p), GI.y(p)) for p in GI.getpoint(r)]
    length(pts) > 1 && isapprox(pts[end], pts[1]; atol = 1.0e-9) && pop!(pts)
    return pts
end

# Derive the spherical clip boundary of an oblique projection (d3 `reclip`, in-order variant).
# These projections map the whole sphere into a CONVEX projected domain (square / ellipse), so
# the in-order domain outline is exactly the convex hull of the projected points — which hits the
# corners (the radial scan rounded them) and is naturally ordered. Densify the hull edges
# (straight in projected space), inset slightly toward the centroid, and inverse-project each →
# the spherical boundary with sharp corners. Bail (→ ProjectedClip) if the inverse is unavailable
# (e.g. guyou) or the result is malformed.
function _oblique_boundary(t)
    tinv = Base.inv(t; always_xy = true)
    proj(lo, la) = (
        try
            xy = t((Float64(lo), Float64(la))); (Float64(xy[1]), Float64(xy[2]))
        catch
            (NaN, NaN)
        end
    )
    invp(x, y) = (
        try
            ll = tinv((Float64(x), Float64(y))); (Float64(ll[1]), Float64(ll[2]))
        catch
            (NaN, NaN)
        end
    )
    proj_pts = Point2d[]
    for lo in -180.0:0.5:180.0, la in -89.5:0.5:89.5
        x, y = proj(lo, la)
        (isfinite(x) && isfinite(y)) && push!(proj_pts, Point2d(x, y))
    end
    length(proj_pts) < 16 && return Vector{Point2d}[]
    # Convex hull of the projected grid = the in-order domain outline (these projections map the
    # whole sphere into a CONVEX projected domain). GeometryOps' planar monotone-chain hull.
    hullpoly = GO.convex_hull(proj_pts)
    hull = _exterior_open(hullpoly)
    length(hull) < 3 && return Vector{Point2d}[]
    # collapse grid-sampling noise at the corners (Douglas–Peucker): straight edges → sharp
    # corners, curves kept. tol = perpendicular distance as a fraction of the hull's diagonal.
    diag = hypot(
        maximum(p -> p[1], hull) - minimum(p -> p[1], hull),
        maximum(p -> p[2], hull) - minimum(p -> p[2], hull)
    )
    hull = _exterior_open(GO.simplify(GO.DouglasPeucker(; tol = 0.004 * diag), hullpoly))
    length(hull) < 3 && return Vector{Point2d}[]
    cx = sum(p -> p[1], hull) / length(hull); cy = sum(p -> p[2], hull) / length(hull)
    R = 1 - 1.0e-6
    n = length(hull); per = max(2, cld(400, n))         # ~400 boundary points total
    ring = Point2d[]
    for i in 1:n
        a = hull[i]; b = hull[mod(i, n) + 1]
        for k in 0:(per - 1)
            s = k / per
            px = a[1] + s * (b[1] - a[1]); py = a[2] + s * (b[2] - a[2])
            ll = invp(cx + R * (px - cx), cy + R * (py - cy))
            (isfinite(ll[1]) && isfinite(ll[2])) && push!(ring, Point2d(ll[1], ll[2]))
        end
    end
    length(ring) < 16 && return Vector{Point2d}[]
    jumps = count(i -> _gcdist_deg(ring[i - 1], ring[i]) > 25.0, 2:length(ring))
    jumps > 4 && return Vector{Point2d}[]
    return Vector{Point2d}[ring]
end

# Interrupted projections (igh/imoll): build the lobe-outline clip polygon from the lobe
# triangles (port of d3-geo-polygon clipInterrupted). Each lobe vertex is pulled an ε along the
# great circle toward its apex meridian at the equator; north lobes forward, south reversed.
# Goode/interrupted-Mollweide lobes (match PROJ igh/imoll, transcribed from d3 homolosine.js):
const _IGH_LOBES = (
    (((-180.0, 0.0), (-100.0, 90.0), (-40.0, 0.0)), ((-40.0, 0.0), (30.0, 90.0), (180.0, 0.0))),
    (
        ((-180.0, 0.0), (-160.0, -90.0), (-100.0, 0.0)), ((-100.0, 0.0), (-60.0, -90.0), (-20.0, 0.0)),
        ((-20.0, 0.0), (20.0, -90.0), (80.0, 0.0)), ((80.0, 0.0), (140.0, -90.0), (180.0, 0.0)),
    ),
)
# Oceanic Goode (PROJ igh_o): N split at lon −90/60, S split at −60/90; central meridians from
# igh_o.cpp's zone setup (N: −140/−10/130, S: −110/20/150).
const _IGH_O_LOBES = (
    (
        ((-180.0, 0.0), (-140.0, 90.0), (-90.0, 0.0)), ((-90.0, 0.0), (-10.0, 90.0), (60.0, 0.0)),
        ((60.0, 0.0), (130.0, 90.0), (180.0, 0.0)),
    ),
    (
        ((-180.0, 0.0), (-110.0, -90.0), (-60.0, 0.0)), ((-60.0, 0.0), (20.0, -90.0), (90.0, 0.0)),
        ((90.0, 0.0), (150.0, -90.0), (180.0, 0.0)),
    ),
)
# Great-circle interpolation at fraction `s` between two lon/lat° points, returning (lon,lat)°.
# Delegated to UnitSpherical's `slerp` (S2 tangent-vector form): machine-precision-identical to
# the old sin-weighted formula on all non-antipodal inputs, and antipodal-robust where the old
# `1/sin(Ω)` divisor blew up. Boundary edges here are never near-antipodal, so this is a pure
# robustness upgrade at neutral cost.
function _geo_interp(a, b, s)
    p = GO.UnitSpherical.slerp(
        _US_FROM_GEO((Float64(a[1]), Float64(a[2]))),
        _US_FROM_GEO((Float64(b[1]), Float64(b[2]))), s
    )
    return _GEO_FROM_US(p)
end
function _interrupted_boundary(lobes, lon0)
    poly = Point2d[]
    for (hi, hemi) in enumerate(lobes)
        pts = Point2d[]
        for lobe in hemi
            apexlon = lobe[2][1]
            for p in lobe
                q = _geo_interp(p, (apexlon, 0.0), 1.0e-6)
                push!(pts, Point2d(q[1] + lon0, q[2]))
            end
        end
        hi > 1 && reverse!(pts)
        append!(poly, pts)
    end
    push!(poly, poly[1])
    # Densify each lobe edge with great-circle points so the clipped fills and the spine trace
    # smooth pole-to-equator arcs (the raw lobe triangles are just corner vertices).
    K = 24
    dense = Point2d[]
    for i in 2:length(poly)
        a = poly[i - 1]; b = poly[i]; push!(dense, a)
        if abs(a[1] - b[1]) > 1.0e-3 || abs(a[2] - b[2]) > 1.0e-3      # skip ~zero junction edges
            for t in 1:(K - 1)
                q = _geo_interp((a[1], a[2]), (b[1], b[2]), t / K)
                push!(dense, Point2d(q[1], q[2]))
            end
        end
    end
    push!(dense, poly[end])
    return Vector{Point2d}[dense]
end

############################################################
#   Arbitrary spherical-polygon clip (d3-geo-polygon port) #
############################################################

# clip-stream point in RADIANS; `index`/`t` locate boundary intersections (index = -1 for an
# ordinary vertex) for the rejoin sort and boundary-walk interpolate.
struct _CPt
    λ::Float64
    φ::Float64
    index::Int
    t::Float64
end
_randsign(i, j) = sign(sin(100 * i + j))
# geodesic distance between two cartesian unit vectors — UnitSpherical's `spherical_distance` is the
# identical atan2(‖a×b‖, a·b) form; the NTuple→UnitSphericalPoint wrap is allocation-free.
_cp_dist(a, b) = GO.UnitSpherical.spherical_distance(
    GO.UnitSpherical.UnitSphericalPoint(a), GO.UnitSpherical.UnitSphericalPoint(b)
)
_cp_sort(a, b) = a.index != b.index ? float(a.index - b.index) : (a.t - b.t)

# Port of d3-geo-polygon clipPolygon's clipLine, on one polyline (radians). Returns the visible
# sub-lines (each a Vector{_CPt}, endpoints carrying boundary index/t) and the `clean` flag.
function _cp_clip_line(pts, pc::PolygonClip; closed::Bool)
    segs = pc.segs
    vis(λ, φ) = _polygon_contains(pc.boundary, (λ * _R2D, φ * _R2D))
    lines = Vector{_CPt}[]; line = _CPt[]
    point0 = nothing; λ00 = 0.0; φ00 = 0.0; v00 = false; v0 = false; clean = 1
    n = length(pts)
    feed = closed ? (n + 1) : n
    @inbounds for k in 1:feed
        close = closed && k == feed
        λ = close ? λ00 : pts[k][1] * _D2R
        φ = close ? φ00 : pts[k][2] * _D2R
        cos(λ) == -1 && (λ -= sign(sin(λ)) * 1.0e-5)
        point = _cartr(λ * 0.9999999999, φ + 1.0e-14)
        v = v0
        if point0 !== nothing
            ints = NamedTuple{(:λ, :φ, :index, :t, :d), NTuple{5, Float64}}[]
            segA = _ixseg(point0, point)
            i = 1; jc = 100
            while i <= length(segs) && jc > 0
                s = segs[i]
                x = _gc_intersect(segA, s)
                if x !== nothing
                    if _cart_eq(x, point0) || _cart_eq(x, point) || _cart_eq(x, s.from) || _cart_eq(x, s.to)
                        tt = 1.0e-4
                        λ = mod(λ + 3π + _randsign(i, jc) * tt, 2π) - π
                        φ = min(π / 2 - tt, max(tt - π / 2, φ + _randsign(i, jc) * tt))
                        point = _cartr(λ, φ); segA = _ixseg(point0, point)
                        i = 0; jc -= 1; empty!(ints)
                    else
                        sλ, sφ = _sphr(x)
                        push!(ints, (λ = sλ, φ = sφ, index = float(i - 1), t = _cp_dist(s.from, x), d = _cp_dist(point0, x)))
                    end
                end
                i += 1
            end
            if !isempty(ints)
                clean = 0
                sort!(ints; by = p -> p.d)
                for it in ints
                    v = !v
                    if v
                        line = _CPt[]; push!(line, _CPt(it.λ, it.φ, Int(it.index), it.t))
                    else
                        push!(line, _CPt(it.λ, it.φ, Int(it.index), it.t)); push!(lines, line)
                    end
                end
            end
            v && push!(line, _CPt(λ, φ, -1, 0.0))
        else
            i = 1; jc = 100
            while i <= length(segs) && jc > 0
                if _gc_point_on_line(point, segs[i])
                    tt = 1.0e-4
                    λ = mod(λ + 3π + _randsign(i, jc) * tt, 2π) - π
                    φ = min(π / 2 - 1.0e-4, max(1.0e-4 - π / 2, φ + _randsign(i, jc) * tt))
                    point = _cartr(λ, φ); i = 0; jc -= 1
                end
                i += 1
            end
            λ00 = λ; φ00 = φ; v00 = v = vis(λ, φ)
            v && (line = _CPt[]; push!(line, _CPt(λ, φ, -1, 0.0)))
        end
        point0 = point; v0 = v
    end
    v0 && push!(lines, line)
    return lines, (clean | ((v00 && v0) ? 2 : 0))
end

# boundary-walk interpolate: connect `from`→`to` along the boundary segments by index
function _cp_interpolate!(pc::PolygonClip, from, to, dir, out)
    segs = pc.segs; n = length(segs)
    if from === nothing
        for ring in pc.boundary, p in ring
            push!(out, _CPt(p[1] * _D2R, p[2] * _D2R, -1, 0.0))
        end
    elseif from.index < 0 || to.index < 0
        return                              # defensive: an ordinary (non-boundary) point reached
        # interpolate (a clipPolygon multi-hole edge case);
        # skip the boundary walk rather than index segs[0]
    elseif from.index != to.index
        i = from.index
        while i != to.index
            s = segs[i + 1]; p = dir > 0 ? s.to : s.from; sλ, sφ = _sphr(p)
            push!(out, _CPt(sλ, sφ, -1, 0.0))
            i = mod(i + dir + n, n)
        end
    elseif from.index == to.index && from.t > to.t
        for k in 0:(n - 1)
            s = segs[mod(from.index + k * dir + n, n) + 1]; p = dir > 0 ? s.to : s.from; sλ, sφ = _sphr(p)
            push!(out, _CPt(sλ, sφ, -1, 0.0))
        end
    end
    return
end

# rejoin (port of clip/rejoin.js) for _CPt segments with the index/t sort
mutable struct _IxC
    x::_CPt
    z::Union{Nothing, Vector{_CPt}}
    o::Union{Nothing, _IxC}
    e::Bool
    v::Bool
    n::Union{Nothing, _IxC}
    p::Union{Nothing, _IxC}
end
_IxC(x, z, o, e) = _IxC(x, z, o, e, false, nothing, nothing)
function _linkC!(arr)
    isempty(arr) && return
    a = arr[1]
    @inbounds for i in 2:length(arr)
        b = arr[i]; a.n = b; b.p = a; a = b
    end
    a.n = arr[1]
    return arr[1].p = a
end
@inline _cpteq(a, b) = abs(a.λ - b.λ) < _EPS && abs(a.φ - b.φ) < _EPS
function _cp_rejoin(segments, start_inside, pc)
    rings = Vector{_CPt}[]
    subject = _IxC[]; clip = _IxC[]
    for seg in segments
        (length(seg) - 1) <= 0 && continue
        p0 = seg[1]; p1 = seg[end]
        if _cpteq(p0, p1)
            push!(rings, seg[1:(end - 1)]); continue
        end
        a = _IxC(p0, seg, nothing, true);  ao = _IxC(p0, nothing, a, false); a.o = ao
        b = _IxC(p1, seg, nothing, false); bo = _IxC(p1, nothing, b, true);  b.o = bo
        push!(subject, a); push!(clip, ao); push!(subject, b); push!(clip, bo)
    end
    isempty(subject) && return rings
    sort!(clip; lt = (u, w) -> _cp_sort(u.x, w.x) < 0)
    _linkC!(subject); _linkC!(clip)
    si = start_inside
    for c in clip
        si = !si; c.e = si
    end
    start = subject[1]
    # Each intersection is visited once, so total work is bounded by the number of intersections.
    # Cap iterations defensively: a malformed boundary (e.g. a self-intersecting derived outline)
    # could otherwise spin forever in the entry/exit walk.
    guard = 0; lim = 4 * (length(subject) + length(clip)) + 64
    while true
        (guard += 1) > lim && break
        current = start
        while current.v
            current = current.n
            current === start && return rings
        end
        ring = _CPt[]; is_subject = true
        while true
            (guard += 1) > lim && break
            current.v = true; current.o.v = true
            if current.e
                is_subject ? append!(ring, current.z) : _cp_interpolate!(pc, current.x, current.n.x, 1, ring)
                current = current.n
            else
                if is_subject
                    pts = current.p.z
                    for k in length(pts):-1:1
                        push!(ring, pts[k])
                    end
                else
                    _cp_interpolate!(pc, current.x, current.p.x, -1, ring)
                end
                current = current.p
            end
            current = current.o
            is_subject = !is_subject
            current.v && break
        end
        push!(rings, ring)
    end
    return rings
end

# Clip the rings of one polygon against the spherical boundary; returns lon/lat-degree rings.
function _clip_against_polygon(pc::PolygonClip, rings_deg)
    isempty(pc.segs) && return [Point2d[Point2d(p[1], p[2]) for p in r] for r in rings_deg]
    # Rings arrive already canonically wound from `_split_polygon` (role-based, by the caller's
    # `:spherical`/`:planar` regime). Do NOT re-wind here — re-deciding would undo that and flip
    # the parity (e.g. shrinking igh/imoll contourf bands that bound >½ the globe).
    start_pt = (pc.flat[1][1], pc.flat[1][2])           # the clip boundary's start vertex (deg)
    segments = Vector{_CPt}[]
    whole = Vector{_CPt}[]
    for r in rings_deg
        length(r) < 2 && continue
        lines, clean = _cp_clip_line(r, pc; closed = true)
        isempty(lines) && continue
        if (clean & 1) != 0
            length(lines[1]) > 1 && push!(whole, lines[1])
            continue
        end
        if length(lines) > 1 && (clean & 2) != 0
            lines = vcat([vcat(lines[end], lines[1])], lines[2:(end - 1)])
        end
        for s in lines
            length(s) > 1 && push!(segments, s)
        end
    end
    out = whole
    # d3: startInside = is the boundary's start point inside the SUBJECT polygon (per-polygon).
    if !isempty(segments)
        append!(out, _cp_rejoin(segments, _polygon_contains(rings_deg, start_pt), pc))
    elseif isempty(out) && _polygon_contains(rings_deg, start_pt)
        r = _CPt[]; _cp_interpolate!(pc, nothing, nothing, 1, r); push!(out, r)
    end
    return [Point2d[Point2d(p.λ * _R2D, p.φ * _R2D) for p in ring] for ring in out]
end

# Internal clip-core point: (λ, φ, marker) in radians. `marker` carries d3's degeneracy
# flags (1 = coincident-intersection nudge, 2/3 = boundary-exit markers used by rejoin).
const _Pt = NTuple{3, Float64}
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
_rotation(c::ObliqueAntimeridianClip) = (c.fwd, c.inv)

# --- bertin1953: a rotated, fudged Hammer (PROJ `bertin1953.cpp`, no inverse) -----------------
# PROJ bakes the oblique aspect into the forward (lam += −16.5°, then a −42° rotation about the
# y-axis, dgamma=0). d3 does the same as `rotate([-16.5,-42])` then `clipAntimeridian`. A pure
# rotation IS analytically invertible (unlike the full bertin forward), so we clip at the rotated
# antimeridian and — crucially — draw with the native CENTRED Hammer (`_bertin_centred`), Option B,
# rather than unrotating through PROJ (whose atan2 collapses the ±π seam, smearing Antarctica).
const _BERTIN_DL = deg2rad(-16.5)
const _BERTIN_CD = cosd(-42.0)
const _BERTIN_SD = sind(-42.0)
function _bertin_rotation()
    fwd = function (λ, φ)                 # geographic (rad) → rotated frame (rad)
        λ2 = λ + _BERTIN_DL; c = cos(φ); x = cos(λ2) * c; y = sin(λ2) * c; z = sin(φ)
        z0 = z * _BERTIN_CD + x * _BERTIN_SD
        return (atan(y, x * _BERTIN_CD - z * _BERTIN_SD), asin(clamp(z0, -1.0, 1.0)))
    end
    inv = function (λr, φr)               # rotated frame (rad) → geographic (rad)
        c = cos(φr); xn = cos(λr) * c; yn = sin(λr) * c; zn = sin(φr)
        x = xn * _BERTIN_CD + zn * _BERTIN_SD; z = -xn * _BERTIN_SD + zn * _BERTIN_CD
        return (atan(yn, x) - _BERTIN_DL, asin(clamp(z, -1.0, 1.0)))
    end
    return fwd, inv
end
# Native centred bertin: the post-rotation forward (pre-fudge + Hammer(1.68) + post-fudge), taking
# rotated lon/lat in DEGREES → projected metres. No `adjlon`, so the seam ±180° stays distinct (the
# two ellipse edges). Verified `_bertin_centred(rotate(geo)) == PROJ bertin(geo)` to 0 m.
function _bertin_centred(λ, φ)
    λ = deg2rad(λ); φ = deg2rad(φ)
    fu = 1.4; k = 12.0; w = 1.68; a = 6.378137e6
    if λ + φ < -fu
        d = (λ - φ + 1.6) * (λ + φ + fu) / 8
        λ += d; φ -= 0.8 * d * sin(φ + π / 2)
    end
    cφ = cos(φ); d = sqrt(2 / (1 + cφ * cos(λ / 2)))
    x = w * d * cφ * sin(λ / 2); y = d * sin(φ)
    d = (1 - cos(λ * φ)) / k
    y < 0 && (x *= 1 + d)
    y > 0 && (y *= 1 + d / 1.5 * x * x)
    return (a * x, a * y)
end

# --- antimeridian crossing latitude (d3 clipAntimeridianIntersect), radians ---------------
@inline function _antimeridian_lat(λ0, φ0, λ1, φ1)
    s = sin(λ0 - λ1)
    abs(s) < _EPS && return (φ0 + φ1) / 2
    cφ0 = cos(φ0); cφ1 = cos(φ1)
    return atan((sin(φ0) * cφ1 * sin(λ1) - sin(φ1) * cφ0 * sin(λ0)) / (cφ0 * cφ1 * s))
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
    if λ < -r
        code |= 1
    elseif λ > r
        code |= 2
    end
    if φ < -r
        code |= 4
    elseif φ > r
        code |= 8
    end
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
        (
            polar ? xor(φ0 + φ1 > 0, qφ < (abs(qλ - λ0) < _EPS ? φ0 : φ1)) :
            (φ0 <= qφ <= φ1)
        ) :
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
_clip_ring(c::ObliqueAntimeridianClip, ring) = (lines = _antimeridian_stream(vcat(ring, [ring[1]])); (lines[1], 2 - lines[2]))
_clip_ring(c::CircleClip, ring) = _circle_stream(c, vcat(ring, [ring[1]]))

_clip_open(c::AntimeridianClip, line) = [l for l in _antimeridian_stream(line)[1] if length(l) > 1]
_clip_open(c::ObliqueAntimeridianClip, line) = [l for l in _antimeridian_stream(line)[1] if length(l) > 1]
_clip_open(c::CircleClip, line) = [l for l in _circle_stream(c, line)[1] if length(l) > 1]

_start(::AntimeridianClip) = (-π, -π / 2)
_start(::ObliqueAntimeridianClip) = (-π, -π / 2)
function _start(c::CircleClip)
    radius = c.radius * _D2R
    return cos(radius) > 0 ? (0.0, -radius) : (-π, radius - π)
end

# boundary interpolate from `from` to `to` (radian `_Pt` or `nothing`), appending to `out`
function _interpolate!(::Union{AntimeridianClip, ObliqueAntimeridianClip}, from, to, dir, out)
    return if from === nothing                            # whole sphere boundary
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
    return _circle_stream_arc!(out, radius, 2 * _D2R, dir, from, to)
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
    return
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
    z::Union{Nothing, Vector{_Pt}}
    o::Union{Nothing, _Ix}
    e::Bool
    v::Bool
    n::Union{Nothing, _Ix}
    p::Union{Nothing, _Ix}
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
                push!(rings, seg[1:(end - 1)])
                continue
            end
            p1 = (p1[1] + 2 * _EPS, p1[2], p1[3])  # nudge degenerate
            seg = vcat(seg[1:(end - 1)], [p1])
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
                    for q in current.z
                        push!(ring, q)
                    end
                else
                    interpolate!(current.x, current.n.x, 1, ring)
                end
                current = current.n
            else
                if is_subject
                    pts = current.p.z
                    for k in length(pts):-1:1
                        push!(ring, pts[k])
                    end
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
            segs = vcat([vcat(segs[end], segs[1])], segs[2:(end - 1)])
        end
        for s in segs
            length(s) > 1 && push!(segments, s)
        end
    end
    poly_deg = [[(_R2D * p[1], _R2D * p[2]) for p in ring] for ring in rings_rad]
    st = _start(c); st_deg = (_R2D * st[1], _R2D * st[2])
    # rings are already canonically wound (see `_split_polygon`), so use d3's raw winding-based
    # containment directly — re-normalising here would undo the rewind and flip the parity.
    contains = _polygon_contains(poly_deg, st_deg)
    if !isempty(segments)
        append!(out, _rejoin(segments, _compare_ix, contains, (f, t, d, o) -> _interpolate!(c, f, t, d, o)))
    elseif isempty(out) && !isempty(rings_rad) && contains
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
    isempty(valid) && return GeometryBasics.Polygon{2, Float32}[]
    n = length(valid)
    proj = [[project(p[1], p[2]) for p in r] for r in valid]
    # a finite representative vertex per ring (rings are visible ⇒ finite, but guard anyway)
    rep = Vector{NTuple{2, Float64}}(undef, n)
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
    polys = GeometryBasics.Polygon{2, Float32}[]
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
# project closure (lon,lat)->(x,y); error-safe (PROJ throws on out-of-domain lat/lon → NaN),
# mirroring `Makie.apply_transform`, so the resampler/clip can't crash on a boundary vertex.
function _projector(t)
    return function (lon, lat)
        try
            p = t((Float64(lon), Float64(lat)))
            return (Float64(p[1]), Float64(p[2]))
        catch
            return (NaN, NaN)
        end
    end
end

# Zero +lon_0/+lat_0/+pm in a PROJ dest string → the "centred" projection. Option B draws
# rotated-frame geometry with this transform; since `centred ∘ rotate == full` exactly for a
# pure-longitude rotation, the result lands in the same projected space as the axis, but the
# seam now sits at rotated ±180° which the centred projection maps to distinct edges (no
# longitude-wrap collapse). Non-string dests (GFT/EPSG) pass through unchanged.
# Centred (lon_0=0) variant for Option-B drawing of the antimeridian split. The
# `AntimeridianClip` rotation is LONGITUDE-ONLY (`_rotation`: (λ,φ)->(λ+dλ, φ)), so we zero only
# the longitude origin (`lon_0`/`pm`) and MUST keep `lat_0`/`lat_1`/`lat_2`: for a conic such as
# `lcc` (`lat_0=39 lat_1=33 lat_2=45`), zeroing `lat_0` shifts the false origin by megametres, so
# the split geometry — emitted in the rotated frame and drawn with this centred projector — lands
# far from where its own data limits expect it, zooming the GeoAxis out to a speck. (Harmless for
# the pseudocylindricals that dominate this path, whose `lat_0` is already 0.)
_centred_dest(d::AbstractString) = replace(
    d,
    r"\blon_0=[-+0-9.eE]+" => "lon_0=0",
    r"\bpm=[-+0-9.eE]+" => "pm=0"
)
_centred_dest(x) = x

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
# Projected-space polygon fill for ProjectedClip. E1: pass through (fills not yet split — the
# proper cartopy-style densify→project→jump-cut→reattach-to-boundary lands in E2). Lines are
# already handled via `_jump_split_line`.
_projected_fill(rings_deg, project, scale) = _rings_to_polygons(rings_deg, project)

# clamp ring/line latitudes to ±lat_max (pole-blowup cylindricals, e.g. merc); identity at 90.
_clamp_lat(r, lm) = lm >= 90.0 ? r : [Point2d(p[1], clamp(p[2], -lm, lm)) for p in r]

function _split_polygon(clip::SphereClip, rings_deg, project, scale; rotated::Bool = false, winding::Symbol = :spherical)
    clip isa NoClip && return _rings_to_polygons(rings_deg, project)
    clip isa ProjectedClip && return _projected_fill(rings_deg, project, scale)
    # ±lat clamp for pole-blowup cylindricals (merc): clamp the subject, resample through a
    # clamped projector (great-circle midpoints arc over the pole; the antimeridian clip adds the
    # ±90 pole boundary — both project to merc(±90) ≈ 12× the useful map and explode the
    # resampler), then clamp the OUTPUT lat so the child plot's own projection stays bounded too.
    lm = clip isa AntimeridianClip ? clip.lat_max : 90.0
    lm < 90 && (rings_deg = [_clamp_lat(r, lm) for r in rings_deg])
    prc = lm < 90 ? ((lo, la) -> project(lo, clamp(la, -lm, lm))) : project
    # Reconcile winding conventions to d3's spherical clip (exterior CW so its ≤½-sphere interior
    # is the side `_polygon_contains` reads as "inside"; holes the opposite). Two regimes:
    #
    # `:spherical` (user geometry via poly!/`split_geometry`) — orient by RING ROLE using the
    # SPHERICAL winding (`_geo_area`: the d3/S2 signed area, which honours the antimeridian and the
    # poles). The planar (lon/lat) shoelace this replaced is WRONG for rings that cross the seam
    # (their flat winding flips) and DEGENERATE for rings that encircle a pole (flat area ≈ 0, sign
    # is noise) — so it spuriously reversed Tissot's seam/pole circles into bounding the complement
    # and filled the whole map. `_geo_area` is correct there, and still flips RFC-7946 exterior-CCW
    # inputs (e.g. shapefiles) to the CW the clip wants.
    #
    # `:planar` (Makie contourf isobands) — orient by the planar shoelace. Bands are grid-rectangle
    # bounded (planar winding is reliable, never pole-degenerate) and a single band may legitimately
    # bound MORE than half the sphere; the spherical-area rule would wrongly shrink such a band to
    # its small complement (dropping bands), so the size-agnostic planar rule is the right one here.
    rings_deg = if winding === :planar
        [i == 1 ? (_planar_area(r) > 0 ? reverse(r) : r) :   # exterior → d3 (CW)
             (_planar_area(r) < 0 ? reverse(r) : r)          # holes    → d3 (CCW)
         for (i, r) in enumerate(rings_deg)]
    else
        [i == 1 ? (_geo_area(r) > 2π ? reverse(r) : r) :     # exterior → bounds the ≤½-sphere side
             (_geo_area(r) < 2π ? reverse(r) : r)            # holes    → the complement
         for (i, r) in enumerate(rings_deg)]
    end
    if clip isa PolygonClip      # d3 clipPolygon against the derived spherical boundary
        clipped = _clip_against_polygon(clip, rings_deg)
        return _rings_to_polygons([resample_sphere(r, project; scale = scale) for r in clipped], project)
    end
    fwd, inv = _rotation(clip)
    seam = clip isa AntimeridianClip || clip isa ObliqueAntimeridianClip
    rings_rad = [[(q = fwd(p[1] * _D2R, p[2] * _D2R); (q[1], q[2], 0.0)) for p in r] for r in rings_deg]
    clipped = _clip_polygon(clip, rings_rad)
    isempty(clipped) && return GeometryBasics.Polygon{2, Float32}[]
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
        push!(out_deg, _clamp_lat(resample_sphere(rd, prc; scale = scale), lm))
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
    out = GeometryBasics.Polygon{2, Float32}[]
    for p in _collect_polys(geom)
        append!(out, _split_polygon(clip, _poly_rings(p), project, scale))
    end
    return out
end
split_geometry(geom, dest::AbstractString) =
    split_geometry(geom, create_transform(dest, "+proj=longlat +datum=WGS84"))

# split a NaN-separated point vector into its finite sub-polylines
function _nan_segments(pts)
    segs = Vector{Point2d}[]; cur = Point2d[]
    for p in pts
        if isnan(_lon(p)) || isnan(_lat(p))
            length(cur) >= 2 && push!(segs, cur); cur = Point2d[]
        else
            push!(cur, Point2d(_lon(p), _lat(p)))
        end
    end
    length(cur) >= 2 && push!(segs, cur)
    return segs
end

# Projected-jump line split (ProjectedClip): densify in lon/lat, then break wherever a
# *projected* segment is abnormally long relative to the line's median segment — the
# discontinuity. A RELATIVE threshold catches both the full-map oblique tear (spilhaus) and the
# ~⅓-map inter-lobe jump of interrupted projections (igh), which an absolute one misses. Output
# stays geographic; the caller draws with the full transform.
function _jump_split_line(pts, project, scale; factor = 8.0)
    segs = [resample_sphere(seg, project; scale = scale) for seg in _nan_segments(pts)]
    projd = [[project(p[1], p[2]) for p in res] for res in segs]
    lens = Float64[]
    for pr in projd, i in 2:length(pr)
        (_isfinitexy(pr[i]) && _isfinitexy(pr[i - 1])) && push!(lens, hypot(pr[i][1] - pr[i - 1][1], pr[i][2] - pr[i - 1][2]))
    end
    isempty(lens) && return reduce(vcat, segs; init = Point2d[])
    med = sort(lens)[cld(length(lens), 2)]
    thr = max(factor * med, 1.0e-9)
    out = Point2d[]
    for (res, pr) in zip(segs, projd)
        for i in eachindex(res)
            if i > 1 && _isfinitexy(pr[i]) && _isfinitexy(pr[i - 1]) &&
                    hypot(pr[i][1] - pr[i - 1][1], pr[i][2] - pr[i - 1][2]) > thr
                push!(out, Point2d(NaN, NaN))      # break across the tear
            end
            push!(out, res[i])
        end
        push!(out, Point2d(NaN, NaN))
    end
    return out
end

"""
    split_resample_line(pts, t; scale=auto, rotated=false, project=nothing) -> Vector{Point2d}

Clip a lon/lat polyline `pts` (which may already contain `NaN` breaks) at `t`'s discontinuity,
adaptively resample each visible sub-line, and join with `NaN` breaks. With `rotated=true` the
output stays in the canonical rotated frame (Option B — the caller draws with the centred
transform) and `project` must be the centred projector; otherwise output is geographic lon/lat.
"""
function split_resample_line(
        pts, t::Proj.Transformation; scale::Float64 = NaN,
        rotated::Bool = false, project = nothing
    )
    clip = clip_strategy(t)
    project === nothing && (project = _projector(t))
    isnan(scale) && (scale = resample_scale(project))
    clip isa AntimeridianClip && clip.lat_max < 90 &&
        (pts = _clamp_lat(Point2d[Point2d(_lon(p), _lat(p)) for p in pts], clip.lat_max))
    clip isa NoClip &&
        return resample_sphere(Point2d[Point2d(_lon(p), _lat(p)) for p in pts], project; scale = scale)
    clip isa ProjectedClip && return _jump_split_line(pts, project, scale)
    if clip isa PolygonClip      # clip the line against the boundary, then resample each piece
        out = Point2d[]
        for seg in _nan_segments(pts)
            for s in _cp_clip_line(seg, clip; closed = false)[1]
                length(s) < 2 && continue
                sd = Point2d[Point2d(p.λ * _R2D, p.φ * _R2D) for p in s]
                !isempty(out) && push!(out, Point2d(NaN, NaN))
                append!(out, resample_sphere(sd, project; scale = scale))
            end
        end
        return out
    end
    fwd, inv = _rotation(clip)
    seam = clip isa AntimeridianClip || clip isa ObliqueAntimeridianClip
    lm = clip isa AntimeridianClip ? clip.lat_max : 90.0       # ±lat clamp for merc (see _split_polygon)
    prc = lm < 90 ? ((lo, la) -> project(lo, clamp(la, -lm, lm))) : project
    out = Point2d[]
    for seg in _nan_segments(pts)
        line_rad = [(q = fwd(p[1] * _D2R, p[2] * _D2R); (q[1], q[2], 0.0)) for p in seg]
        for s in _clip_open(clip, line_rad)
            isempty(s) && continue
            sd = rotated ? [Point2d(q[1] * _R2D, q[2] * _R2D) for q in s] :
                [Point2d(_unrotate(inv, q[1], q[2], seam)...) for q in s]
            !isempty(out) && push!(out, Point2d(NaN, NaN))
            append!(out, _clamp_lat(resample_sphere(sd, prc; scale = scale), lm))
        end
    end
    return out
end

# great-circle densify a lon/lat ring (k points per edge) so coarse boundary loops trace smooth
# arcs even before the projected-error resampler runs
function _densify_geo(ring, k)
    out = Point2d[]
    for i in 2:length(ring)
        a = ring[i - 1]; b = ring[i]; push!(out, a)
        for t in 1:(k - 1)
            q = _geo_interp((a[1], a[2]), (b[1], b[2]), t / k)
            push!(out, Point2d(q[1], q[2]))
        end
    end
    !isempty(ring) && push!(out, ring[end])
    return out
end

# resample a lon/lat ring for projected smoothness and return the PROJECTED points
_proj_ring(ring, project; scale = resample_scale(project)) =
    Point2d[Point2d(project(p[1], p[2])...) for p in resample_sphere(ring, project; scale = scale)]

"""
    boundary_points(dest, source=longlat) -> Vector{Point2d}

The projected outline of the map domain for destination `dest` — the d3 `.sphere()` boundary
of the active clip: the limb circle for an azimuthal/perspective horizon, the antimeridian
ellipse/rectangle for a cylindrical/pseudocylindrical projection. Returns already-projected
points (matching the GeoAxis's own gridline space) ready to draw as the axis spine. Antimeridian
projections use the centred projector (Option B) so the seam maps to the true map edges.
"""
function boundary_points(dest, source = "+proj=longlat +datum=WGS84")
    ftf = create_transform(dest, source)
    clip = clip_strategy(ftf)
    clip isa ProjectedClip && return Point2d[]      # no analytic outline (interrupted/guyou)
    if clip isa PolygonClip                         # spine = the derived boundary, projected
        project = _projector(ftf)
        # the boundary is already dense and its vertices sit on the (straight, in projected space)
        # domain edges, so project directly — great-circle densify/resample would bow the edges
        # and round the corners.
        return Point2d[Point2d(project(p[1], p[2])...) for p in clip.boundary[1]]
    end
    if clip isa ObliqueAntimeridianClip
        # spine = the rotated-frame antimeridian (λ=±180°, φ from −90 to 90), drawn DIRECTLY with
        # the native centred projector: λ=+180 → the right ellipse edge, λ=−180 → the left, with no
        # unrotate (which would collapse the ±π seam through PROJ's atan2). Closes into the ellipse.
        c = clip.centred.f
        N = 200; ring = Point2d[]
        for i in 0:N
            push!(ring, Point2d(c(180.0, -90 + 180 * i / N)...))
        end    # right edge ↑
        for i in 0:N
            push!(ring, Point2d(c(-180.0, 90 - 180 * i / N)...))
        end    # left edge ↓
        return ring
    end
    if clip isa NoClip
        project = _projector(ftf)
        ring = Point2d[]
        for lon in -180.0:5.0:180.0
            push!(ring, Point2d(lon, -89.9))
        end
        for lat in -89.9:5.0:89.9
            push!(ring, Point2d(180.0, lat))
        end
        for lon in 180.0:-5.0:-180.0
            push!(ring, Point2d(lon, 89.9))
        end
        for lat in 89.9:-5.0:-89.9
            push!(ring, Point2d(-180.0, lat))
        end
        return _proj_ring(ring, project)
    end
    fwd, inv = _rotation(clip)
    raw = _Pt[]
    _interpolate!(clip, nothing, nothing, 1, raw)        # full clip boundary, rotated frame
    if clip isa AntimeridianClip
        base = _projector(create_transform(_centred_dest(dest), source))
        # Conic projections (lcc, lcca, eqdc, aea…) extend to infinity OPPOSITE the cone's apex:
        # one pole projects finite (the apex), the other to ∞. Their antimeridian "seam" outline
        # then degenerates to a radial ray. Follow cartopy (`LambertConformal`, `cutoff`): build the
        # boundary as the apex pole joined to a CUTOFF PARALLEL on the far side (cartopy's default
        # cuts 30° past the equator) — a finite cone outline that frames the map. See
        # https://scitools.org.uk/cartopy `LambertConformal.__init__`.
        npf = all(isfinite, base(0.0, 90.0)); spf = all(isfinite, base(0.0, -90.0))
        if npf ⊻ spf
            plat = npf ? 90.0 : -90.0
            cutoff = plat > 0 ? -30.0 : 30.0
            cone = Point2d[Point2d(base(0.0, plat)...)]
            for lon in LinRange(180.0 - 1.0e-3, -180.0 + 1.0e-3, 181)
                push!(cone, Point2d(base(lon, cutoff)...))
            end
            push!(cone, Point2d(base(0.0, plat)...))
            return cone
        end
        lm = clip.lat_max                       # clamp lat (merc): the great-circle densify arcs
        project = lm < 90 ? ((lo, la) -> base(lo, clamp(la, -lm, lm))) : base   # over the pole
        ring = _densify_geo(Point2d[Point2d(q[1] * _R2D, q[2] * _R2D) for q in raw], 24)
    else
        project = _projector(ftf)
        sm = clip isa ObliqueAntimeridianClip          # nudge off the exact rotated ±π seam
        ring = Point2d[Point2d(_unrotate(inv, q[1], q[2], sm)...) for q in raw]
    end
    return _proj_ring(ring, project)
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
    elseif name in ("aeqd", "laea", "stere", "sterea", "ups")
        # full-disk azimuthal/conformal: the ANTIPODE (180° from the centre) is the singularity — it
        # maps to the whole boundary circle (stereographic sends it to infinity), so geometry crossing
        # it smears along the rim (NOT an antimeridian seam). Clip a thin cap at the antipode; the rim
        # becomes the spine. Routing `stere` through the default AntimeridianClip instead reprojected
        # everything via the centred-frame (Option B), which collapses a polar `lat_0=±90` into an
        # equatorial aspect (the "Africa-centred" bug).
        return CircleClip(lon0, lat0, 179.5)
    elseif name == "bertin1953"
        # rotated, fudged Hammer (no PROJ inverse). d3: rotate([-16.5,-42]) + clipAntimeridian.
        # We clip at the rotated antimeridian and draw with the native centred Hammer (Option B),
        # so the ±π seam doesn't collapse (which smeared Antarctica when unrotating through PROJ).
        fwd, inv = _bertin_rotation()
        return ObliqueAntimeridianClip(fwd, inv, _NativeCentred(_bertin_centred))
    elseif name in ("spilhaus", "guyou", "gringorten", "peirce_q", "ob_tran", "ocea", "oea")
        # Oblique squares: derive the spherical boundary (convex hull of the projected grid,
        # inverse-projected — our stand-in for d3 `reclip`, which traces the in-order outline) and
        # clip against it (d3 clipPolygon). Falls back to the projected-jump split when the outline
        # derivation yields nothing (e.g. guyou, whose PROJ inverse is unavailable).
        #
        # WORKAROUND vs d3: the hull rounds the sharp square corners (grid sampling). The faithful
        # route is `ObliqueAntimeridianClip` (clip at the oblique-frame antimeridian — exact
        # corners), but without a "centred" projector for that frame it can't apply Option B, so
        # pole-wrapping polygons smear. d3 avoids both because it owns its projections; matching it
        # needs a native (centred-frame) port. So we keep the no-smear hull and accept round corners.
        bnd = get!(() -> _oblique_boundary(t), _BOUNDARY_CACHE, def)
        return (isempty(bnd) || length(bnd[1]) < 4) ? ProjectedClip() : PolygonClip(bnd)
    elseif name in ("igh", "imoll")
        # interrupted Goode/Mollweide: clip against the explicit lobe polygon (d3 clipInterrupted).
        # NB: PROJ's `goode` is the *continuous* homolosine (not interrupted) → AntimeridianClip.
        bnd = get!(() -> _interrupted_boundary(_IGH_LOBES, lon0), _BOUNDARY_CACHE, def)
        return PolygonClip(bnd)
    elseif name in ("igh_o", "imoll_o")
        # oceanic interrupted Goode/Mollweide: same ocean-centred lobe layout, different raw.
        bnd = get!(() -> _interrupted_boundary(_IGH_O_LOBES, lon0), _BOUNDARY_CACHE, def)
        return PolygonClip(bnd)
    elseif name in ("merc", "webmerc")
        # normal Mercator: antimeridian seam PLUS a ±lat clamp — y→±∞ at the poles, so without
        # this Antarctica/Greenland and the spine's ±90 blow the y-limits ~12× past the useful map.
        return AntimeridianClip(lon0, 85.0)
    end
    return AntimeridianClip(lon0)
end
clip_strategy(::Any) = NoClip()
