#=
# Probing an unknown domain

When nothing is declared about a projection, its domain is found by asking it:
a point is on the map when it projects to a finite position that inverts back
to itself.  Rays are cast on the sphere from a seed inside the map; each is
walked coarsely until the first off-map point and that flip is bisected.  The
result is a star-shaped region about the seed: exact for caps and bands, an
under-approximation (never an over-approximation) for anything lobed.  Cuts are
invisible to a round trip and are not claimed.

The probe never warns.  A projection that answers nowhere yields the whole
sphere, and so does one that answers everywhere.
=#

const PROBE_TOL = 1e-4                    # rad; where the rim is placed to
const PROBE_RAYS = (16, 4096)             # fewest / most rays
const PROBE_COARSE_STEP = pi / 64         # rad; coarse walk along a ray
const PROBE_ROUNDTRIP_DEG = 1e-3          # deg; round trip slack (robin's inverse reaches 2e-5)
const PROBE_SEED_SAMPLES = 400            # Fibonacci points tried for a seed

"How many rays place a ring to `tol`: sagitta `π²/2n²` of the radius under `tol`."
probe_rays(tol) = clamp(ceil(Int, pi / sqrt(2 * tol)), PROBE_RAYS...)

_finite2(p) = isfinite(p[1]) && isfinite(p[2])

"Forward projection of a unit vector through Makie's transform interface; NaN when refused."
function _project_xyz(t, p)
    lon, lat = xyz_to_lonlat(p)
    q = try
        Makie.apply_transform(t, Point2d(lon, lat))
    catch
        return Point2d(NaN, NaN)
    end
    return Point2d(q[1], q[2])
end

function _inverse_of(t)
    inv = try
        Makie.inverse_transform(t)
    catch
        nothing
    end
    return inv
end

"""
    onmap(t, inv, p) -> Bool

The round-trip oracle: `p` (unit vector) projects finitely and inverts back to
within `PROBE_ROUNDTRIP_DEG`.
"""
function onmap(t, inv, p)
    q = _project_xyz(t, p)
    _finite2(q) || return false
    ll = try
        Makie.apply_transform(inv, q)
    catch
        return false
    end
    (isfinite(ll[1]) && isfinite(ll[2])) || return false
    return rad2deg(angular_distance(p, lonlat_to_xyz(ll[1], ll[2]))) < PROBE_ROUNDTRIP_DEG
end

function _probe_seed(t, inv)
    p0 = XHAT
    onmap(t, inv, p0) && return p0
    for p in fibonacci_sphere(PROBE_SEED_SAMPLES)
        onmap(t, inv, p) && return p
    end
    return nothing
end

"`n` roughly-equidistributed unit vectors (golden-angle spiral)."
function fibonacci_sphere(n::Integer)
    ga = pi * (3.0 - sqrt(5.0))
    pts = Vector{Vec3d}(undef, n)
    for i in 0:(n - 1)
        z = 1.0 - 2.0 * (i + 0.5) / n
        r = sqrt(max(0.0, 1.0 - z * z))
        θ = ga * i
        pts[i + 1] = Vec3d(r * cos(θ), r * sin(θ), z)
    end
    return pts
end

"""
    probe(t; tol = PROBE_TOL) -> SphereRegion

The star-shaped domain of `t` about a seed on the map, as a `SpherePolygon` of
great-circle arcs, or `whole_sphere()` when every ray reaches the antipode (or
the transform answers nowhere / has no inverse).
"""
function probe(t; tol::Real = PROBE_TOL)
    inv = _inverse_of(t)
    inv === nothing && return whole_sphere()
    seed = _probe_seed(t, inv)
    seed === nothing && return whole_sphere()
    e1 = _perp3(seed)
    e2 = _cross3(seed, e1)
    n = probe_rays(tol)
    nbis = max(1, ceil(Int, log2(PROBE_COARSE_STEP / tol)))
    dirs = [Vec3d(cos(2pi * k / n) * e1 + sin(2pi * k / n) * e2) for k in 0:(n - 1)]
    at(d, s) = Vec3d(cos(s) * seed + sin(s) * d)
    reach = Vector{Float64}(undef, n)
    reached_antipode = 0
    for (k, d) in enumerate(dirs)
        inside = 0.0
        outside = NaN
        s = PROBE_COARSE_STEP
        while s < pi
            if onmap(t, inv, at(d, s))
                inside = s
            else
                outside = s
                break
            end
            s += PROBE_COARSE_STEP
        end
        if isnan(outside)
            if onmap(t, inv, at(d, pi))
                reached_antipode += 1
                reach[k] = pi
                continue
            end
            outside = pi
        end
        for _ in 1:nbis
            m = 0.5 * (inside + outside)
            onmap(t, inv, at(d, m)) ? (inside = m) : (outside = m)
        end
        reach[k] = inside
    end
    reached_antipode == n && return whole_sphere()
    # Each sector between two neighbouring rays extends only as far as the
    # shorter of the two: a ray that misses a hole while its neighbour stops at
    # it would otherwise sweep the hole's tip into the map.  The polygon walks
    # from each ray's end across to the next ray at that distance, then out
    # along it.
    verts = Vec3d[]
    for k in 1:n
        k2 = mod1(k + 1, n)
        push!(verts, at(dirs[k], reach[k]))
        push!(verts, at(dirs[k2], min(reach[k], reach[k2])))
    end
    arcs = CircleArc[]
    m = length(verts)
    for i in 1:m
        p, q = verts[i], verts[mod1(i + 1, m)]
        dist = angular_distance(p, q)
        dist < 1e-9 && continue
        dist > pi - 1e-9 && continue        # antipodal pair: no unique great arc
        push!(arcs, great_arc(p, q))
    end
    isempty(arcs) && return whole_sphere()
    return SpherePolygon(arcs, seed)
end
