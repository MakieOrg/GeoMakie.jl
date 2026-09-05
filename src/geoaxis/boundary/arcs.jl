#=
# Arcs on the unit sphere

The boundary layer works on the unit sphere, where a projection's domain has no
antimeridian and no pole singularity.  Every curve it handles (a graticule line,
a limb, a cutoff parallel, a seam, a polygon edge) is one type, `CircleArc`, and
every clip, rim and point-in-region query bottoms out in one closed-form solver,
`circle_roots`.

Convention (matches `sphere/unit_sphere_transforms.jl`): `(lon, lat) = (0, 0)`
is `(1, 0, 0)`, the north pole is `(0, 0, 1)`, `(90, 0)` is `(0, 1, 0)`.
=#

const Vec3d = GeometryBasics.Vec3d
const Mat3d = GeometryBasics.Mat3d

lonlat_to_xyz(lon::Real, lat::Real) =
    Vec3d(cosd(lat) * cosd(lon), cosd(lat) * sind(lon), sind(lat))
lonlat_to_xyz(ll) = lonlat_to_xyz(ll[1], ll[2])

"Inverse of `lonlat_to_xyz`; lon in `(-180, 180]`, lat in `[-90, 90]`, degrees."
function xyz_to_lonlat(v)
    x, y, z = float(v[1]), float(v[2]), float(v[3])
    lon = atand(y, x)
    lon <= -180.0 && (lon += 360.0)
    return (lon, atand(z, hypot(x, y)))
end

"Great-circle angle (rad) between two vectors; accurate for tiny and near-π angles."
function angular_distance(a, b)
    av = Vec3d(a[1], a[2], a[3]); bv = Vec3d(b[1], b[2], b[3])
    return atan(norm(cross(av, bv)), dot(av, bv))
end

_v3(p) = Vec3d(p[1], p[2], p[3])
_dot3(a, b) = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
_cross3(a, b) = Vec3d(cross(_v3(a), _v3(b)))
_unit3(p) = (q = _v3(p); n = norm(q); n < 1e-300 ? Vec3d(0, 0, 1) : q / n)
"A unit vector perpendicular to `a`."
_perp3(a) = (av = _v3(a); _unit3(_cross3(av, abs(av[3]) < 0.9 ? Vec3d(0, 0, 1) : Vec3d(1, 0, 0))))
"Unit vector on the equator at longitude `lon` (degrees)."
_dir(lon) = lonlat_to_xyz(float(lon), 0.0)

const ZHAT = Vec3d(0, 0, 1)
const XHAT = Vec3d(1, 0, 0)

"Right-handed rotation about +z by `deg` degrees (adds `deg` to longitude)."
Rz(deg::Real) = Mat3d(cosd(deg), sind(deg), 0.0, -sind(deg), cosd(deg), 0.0, 0.0, 0.0, 1.0)
"Right-handed rotation about +y by `deg` degrees (maps `(1,0,0)` to latitude `-deg`)."
Ry(deg::Real) = Mat3d(cosd(deg), 0.0, -sind(deg), 0.0, 1.0, 0.0, sind(deg), 0.0, cosd(deg))

"Rotation matrix about unit `axis` by `ang` radians (Rodrigues)."
function rotation_about(axis, ang::Real)
    k = _unit3(axis)
    rod(v) = _v3(v) * cos(ang) + _cross3(k, v) * sin(ang) + k * (_dot3(k, v) * (1 - cos(ang)))
    e1 = rod(Vec3d(1, 0, 0)); e2 = rod(Vec3d(0, 1, 0)); e3 = rod(Vec3d(0, 0, 1))
    return Mat3d(e1[1], e1[2], e1[3], e2[1], e2[2], e2[3], e3[1], e3[2], e3[3])
end

"""
    CircleArc

An arc of a small circle about `axis`: `p(t) = sinθ (cos t · u + sin t · v) + cosθ · axis`
for `t ∈ [t0, t1]`, with `u ⟂ axis` fixing `t = 0` and `v = axis × u`.
`cosθ == 0` is a great circle (a meridian, the rim of a 90° cap).  Closed under
rotation, so a rotated arc needs no re-parameterisation.
"""
struct CircleArc
    axis::Vec3d
    u::Vec3d
    v::Vec3d
    cosθ::Float64
    t0::Float64
    t1::Float64
end

function make_arc(axis, cosθ, uref, t0, t1)
    a = _unit3(axis)
    uu = _unit3(_v3(uref) - a * _dot3(uref, a))
    return CircleArc(a, uu, _cross3(a, uu), float(cosθ), float(t0), float(t1))
end

sinrad(a::CircleArc) = sqrt(max(0.0, 1 - a.cosθ^2))
arcpoint(a::CircleArc, t) = Vec3d(sinrad(a) * (cos(t) * a.u + sin(t) * a.v) + a.cosθ * a.axis)
arclength(a::CircleArc) = abs(a.t1 - a.t0) * sinrad(a)
isfull(a::CircleArc) = abs(abs(a.t1 - a.t0) - 2pi) < 1e-9
rotate(a::CircleArc, R) = CircleArc(Vec3d(R * a.axis), Vec3d(R * a.u), Vec3d(R * a.v), a.cosθ, a.t0, a.t1)
"Unit tangent of the arc at `t`, in the direction of increasing `t`."
arc_tangent(a::CircleArc, t) = _unit3(sinrad(a) * (-sin(t) * a.u + cos(t) * a.v))

full_circle(axis, c) = make_arc(axis, c, _perp3(axis), 0.0, 2pi)
"Great-circle arc from `p` to `q`, the shorter way."
great_arc(p, q) = make_arc(_cross3(p, q), 0.0, p, 0.0, angular_distance(p, q))
"Half great circle from `+axis` through `d` to `-axis`."
half_meridian(axis, d) = make_arc(_cross3(axis, d), 0.0, axis, 0.0, pi)

"""
    circle_roots(arc, n, k) -> (roots, degenerate)

Roots `t ∈ (t0, t1)` of `dot(arcpoint(arc, t), n) == k`, each paired with the
`scale` of arc parameter per unit angular distance from the boundary circle (so
an inset measured on the sphere is `ε · scale` in `t`; near-tangential crossings
have a large scale).  `degenerate` is `true` when the whole arc satisfies the
equation.  This is the only place trigonometry is solved in the boundary layer.
"""
function circle_roots(a::CircleArc, n, k::Float64)
    s = sinrad(a)
    A = s * _dot3(a.u, n); B = s * _dot3(a.v, n); C = a.cosθ * _dot3(a.axis, n)
    K = k - C
    amp = hypot(A, B)
    amp <= 1e-13 && return (Tuple{Float64, Float64}[], abs(K) <= 1e-12)
    m = K / amp
    abs(m) > 1 + 1e-12 && return (Tuple{Float64, Float64}[], false)
    φ = atan(B, A); δ = acos(clamp(m, -1.0, 1.0))
    sk = sqrt(max(0.0, 1 - k * k))
    lo, hi = min(a.t0, a.t1), max(a.t0, a.t1)
    # a full circle's start point is a genuine crossing (its end point is the same point)
    lo_ok = isfull(a) ? lo - 1e-12 : lo + 1e-12
    out = Tuple{Float64, Float64}[]
    for base in (φ - δ, φ + δ), j in -2:2
        t = base + 2pi * j
        if lo_ok <= t < hi - 1e-12
            push!(out, (t, sk / max(abs(-A * sin(t) + B * cos(t)), 1e-12)))
        end
    end
    return (out, false)
end

"Maximum over the arc of `dot(p(t), d)`, in closed form."
function max_dot(a::CircleArc, d)
    s = sinrad(a)
    A = s * _dot3(a.u, d); B = s * _dot3(a.v, d); C = a.cosθ * _dot3(a.axis, d)
    cand = Float64[a.t0, a.t1]
    if hypot(A, B) > 1e-14
        φ = atan(B, A)
        for j in -2:2
            t = φ + 2pi * j
            min(a.t0, a.t1) <= t <= max(a.t0, a.t1) && push!(cand, t)
        end
    end
    return maximum(A * cos(t) + B * sin(t) + C for t in cand)
end

"Azimuth of `p` in the arc's own `(u, v)` frame, in `[0, 2π)`."
arc_azimuth(a::CircleArc, p) = mod(atan(_dot3(p, a.v), _dot3(p, a.u)), 2pi)

function on_arc_span(a::CircleArc, p; tol = 1e-9)
    isfull(a) && return true
    ψ = arc_azimuth(a, p)
    lo = mod(a.t0, 2pi); w = a.t1 - a.t0
    return mod(ψ - lo, 2pi) <= w + tol
end

"`n` points along the arc (a full circle omits the repeated seed point)."
function sample(a::CircleArc, n::Integer)
    if isfull(a)
        return [arcpoint(a, a.t0 + (a.t1 - a.t0) * (i - 1) / n) for i in 1:n]
    else
        return [arcpoint(a, a.t0 + (a.t1 - a.t0) * (i - 1) / (n - 1)) for i in 1:n]
    end
end
