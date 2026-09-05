# harness.jl -- shared ground truth and scoring for the boundary tests.
#
# The oracle is a round trip through PROJ: a point is on the map when it
# projects finitely and inverts back to itself.  It sees caps and bands (where
# PROJ refuses) but is blind to cuts (a seam point projects fine), so cuts are
# judged by `clip_finite` and the frame tests, not by `contains_agree`.

module BoundaryHarness

using GeoMakie, GeometryBasics, LinearAlgebra, Statistics
using GeoMakie: Proj
const GM = GeoMakie

export Case, CASES, case_by_name, onmap, oracle_inverse, ORACLE_TOL_DEG,
    GratLine, graticule_lines, sample_lonlat, grat_arc,
    score_case, rim_rings, PROJ_CALLS, CountedProj, count_proj_calls, inverse_xyz,
    MOST_PROJECTIONS

"""
    Case(name, proj, t, expected)

One projection under test; `t` is lon/lat -> `proj` (always_xy).
"""
struct Case
    name::Symbol
    proj::String
    t::Proj.Transformation
    expected::String
end

_case(name, proj, expected) =
    Case(name, proj, Proj.Transformation("EPSG:4326", proj; always_xy = true), expected)

const CASES = Case[
    _case(:ortho, "+proj=ortho +lat_0=45 +lon_0=10", "cap of radius 90 deg about (10,45)"),
    _case(:stere_n, "+proj=stere +lat_0=90", "cap of 150 deg about the north pole"),
    _case(:merc, "+proj=merc", "latitude band +/-85.0511 deg, cut at 180"),
    _case(:robin, "+proj=robin +lon_0=150", "whole sphere, cut at lon -30"),
    _case(:moll_obtran, "+proj=ob_tran +o_proj=moll +o_lon_p=45 +o_lat_p=45 +lon_0=180",
        "moll's cut domain rotated by obtran_rotation(45,45,180)"),
    _case(:lcc, "+proj=lcc +lat_1=30 +lat_2=60 +lon_0=-100 +lat_0=40", "cut at lon 80; cutoff parallel -30"),
    _case(:igh, "+proj=igh", "Goode lobes: north seam at -40; south seams at -100, -20, 80"),
    _case(:tmerc, "+proj=tmerc +lon_0=0", "sphere minus 10 deg caps about (+/-90, 0)"),
    _case(:geos, "+proj=geos +h=35785831 +lon_0=0", "cap of ~81.3 deg about (0,0)"),
]

case_by_name(nm::Symbol) = CASES[findfirst(c -> c.name === nm, CASES)]

"The first 30 entries of `examples/most_projections.jl`."
const MOST_PROJECTIONS = [
    "+proj=adams_hemi", "+proj=adams_ws1", "+proj=adams_ws2",
    "+proj=aea +lat_1=29.5 +lat_2=42.5", "+proj=aeqd", "+proj=airy", "+proj=aitoff",
    "+proj=apian", "+proj=august", "+proj=bacon", "+proj=bertin1953", "+proj=bipc +ns",
    "+proj=boggs", "+proj=bonne +lat_1=10", "+proj=cass", "+proj=cea",
    "+proj=chamb +lat_1=10 +lon_1=30 +lon_2=40", "+proj=collg", "+proj=comill",
    "+proj=crast", "+proj=denoy", "+proj=eck1", "+proj=eck2", "+proj=eck3",
    "+proj=eck4", "+proj=eck5", "+proj=eck6", "+proj=eqc", "+proj=eqdc +lat_1=55 +lat_2=60",
    "+proj=eqearth",
]

# ---- the oracle -------------------------------------------------------------

"Round-trip tolerance in degrees (robin's approximate inverse reaches 2e-5, tmerc's 5e-4)."
const ORACLE_TOL_DEG = 1e-3

const _INV_CACHE = IdDict{Any, Any}()
oracle_inverse(t) = get!(() -> Makie.inverse_transform(t), _INV_CACHE, t)

function onmap(t, lon::Real, lat::Real; tol_deg::Real = ORACLE_TOL_DEG)
    xy = GM.project_lonlat(t, float(lon), float(lat))
    (isfinite(xy[1]) && isfinite(xy[2])) || return false
    ll = try
        Makie.apply_transform(oracle_inverse(t), xy)
    catch
        return false
    end
    (isfinite(ll[1]) && isfinite(ll[2])) || return false
    d = rad2deg(GM.angular_distance(GM.lonlat_to_xyz(lon, lat), GM.lonlat_to_xyz(ll[1], ll[2])))
    return d < tol_deg
end
onmap(t, xyz; kw...) = (ll = GM.xyz_to_lonlat(xyz); onmap(t, ll[1], ll[2]; kw...))
onmap(c::Case, lon::Real, lat::Real; kw...) = onmap(c.t, lon, lat; kw...)
onmap(c::Case, xyz; kw...) = onmap(c.t, xyz; kw...)

"Inverse-project a dest point to the sphere; NaN vector when PROJ refuses."
function inverse_xyz(t, p)
    ll = try
        Makie.apply_transform(oracle_inverse(t), Point2d(p[1], p[2]))
    catch
        return GM.Vec3d(NaN, NaN, NaN)
    end
    (isfinite(ll[1]) && isfinite(ll[2])) || return GM.Vec3d(NaN, NaN, NaN)
    return GM.lonlat_to_xyz(ll[1], ll[2])
end

# ---- a counted transform ---------------------------------------------------

"Every forward call through a `CountedProj` bumps this."
const PROJ_CALLS = Ref(0)

struct CountedProj
    t::Proj.Transformation
end
function Makie.apply_transform(cp::CountedProj, p::Point2d)
    PROJ_CALLS[] += 1
    return Makie.apply_transform(cp.t, p)
end
Makie.apply_transform(cp::CountedProj, p::Point2{T}) where {T} = Makie.apply_transform(cp, Point2d(p))
Makie.inverse_transform(cp::CountedProj) = Makie.inverse_transform(cp.t)

function count_proj_calls(f)
    before = PROJ_CALLS[]
    r = f()
    return (r, PROJ_CALLS[] - before)
end

# ---- graticule ---------------------------------------------------------------

struct GratLine
    kind::Symbol   # :meridian | :parallel
    value::Float64
end

function graticule_lines(step::Real = 30; poles_at_80::Bool = false)
    lines = GratLine[]
    for lon in -180.0:float(step):(180.0 - step)
        push!(lines, GratLine(:meridian, lon))
    end
    for lat in -(90.0 - step):float(step):(90.0 - step)
        push!(lines, GratLine(:parallel, lat))
    end
    if poles_at_80
        push!(lines, GratLine(:parallel, -80.0)); push!(lines, GratLine(:parallel, 80.0))
    end
    return lines
end

function sample_lonlat(line::GratLine, n::Integer)
    if line.kind === :meridian
        return [(line.value, -90.0 + 180.0 * (i - 1) / (n - 1)) for i in 1:n]
    else
        return [(-180.0 + 360.0 * (i - 1) / (n - 1), line.value) for i in 1:n]
    end
end

"The graticule line as a `CircleArc`."
function grat_arc(line::GratLine)
    if line.kind === :meridian
        d = GM._dir(line.value)
        return GM.make_arc(GM._cross3(d, GM.ZHAT), 0.0, d, -pi / 2, pi / 2)
    else
        return GM.full_circle(GM.ZHAT, sind(line.value))
    end
end

# ---- scoring -----------------------------------------------------------------

const N_CONTAINS_PTS = 5000
const RIM_EXCLUDE_DEG = 0.5
const COVERAGE_TOL_DEG = 0.25
const RIM_NUDGE_DEG = 0.25
const RIM_SLOP_DEG = 0.01
const N_GRAT_DENSE = 720

"Dense samples (unit vectors) of every rim piece of `region`."
function rim_rings(region)
    out = Vector{GM.Vec3d}[]
    for piece in GM.rim(region)
        n = clamp(ceil(Int, GM.arclength(piece.arc) / deg2rad(0.25)) + 1, 8, 2048)
        push!(out, GM.sample(piece.arc, n))
    end
    return out
end

function _min_dist_deg(p, rings)
    best = Inf
    for ring in rings, q in ring
        best = min(best, GM.angular_distance(p, q))
    end
    return rad2deg(best)
end

"Nudge a rim piece's samples `deg` into the region (the side `contains` says is inside)."
function _nudged_inward(region, piece, deg)
    a = piece.arc
    tm = 0.5 * (a.t0 + a.t1)
    m = GM.arcpoint(a, tm)
    left = GM._cross3(m, GM.arc_tangent(a, tm))
    lin = contains(region, GM._unit3(m + GM.ORIENT_NUDGE * left))
    rin = contains(region, GM._unit3(m - GM.ORIENT_NUDGE * left))
    lin == rin && return GM.Vec3d[]          # a cut: both sides are inside
    s = lin ? 1.0 : -1.0
    n = clamp(ceil(Int, GM.arclength(a) / deg2rad(2.0)) + 1, 8, 512)
    out = GM.Vec3d[]
    for i in 1:n
        tt = a.t0 + (a.t1 - a.t0) * (i - 1) / (n - 1)
        p = GM.arcpoint(a, tt)
        l = GM._cross3(p, GM.arc_tangent(a, tt))
        push!(out, GM._unit3(p + s * deg2rad(deg) * l))
    end
    return out
end

"""
    score_case(region, case; pts, grat) -> NamedTuple

`contains_agree` (fraction of Fibonacci points, away from the rim, where
`contains` agrees with the oracle), `worst_false_inside` (largest distance from
the rim, in degrees, of a point claimed inside that the oracle rejects),
`clip_finite` (fraction of clipped graticule samples the oracle accepts),
`clip_coverage` (fraction of oracle-on-map graticule samples within
`COVERAGE_TOL_DEG` of a clipped piece) and `rim_onmap` (fraction of rim samples,
nudged inward, the oracle accepts).
"""
function score_case(region, case::Case; pts = GM.fibonacci_sphere(N_CONTAINS_PTS), grat = graticule_lines(30))
    rings = rim_rings(region)
    nagree = 0; nscored = 0; wfi = 0.0
    for p in pts
        mine = contains(region, p)
        truth = onmap(case.t, p)
        d = _min_dist_deg(p, rings)
        (mine && !truth) && (wfi = max(wfi, isfinite(d) ? d : 0.0))
        (isfinite(d) && d < RIM_EXCLUDE_DEG) && continue
        nscored += 1
        nagree += (mine == truth)
    end
    n_clip = 0; n_clip_on = 0; n_cov = 0; n_cov_hit = 0
    seams = GM.seams(region)
    on_seam(q) = any(s -> abs(GM._dot3(q, s.axis)) < 1e-6 && GM.on_arc_span(s, q; tol = 1e-6), seams)
    for line in grat
        pieces = GM.clip(region, grat_arc(line))
        samples = [GM.sample(a, clamp(ceil(Int, GM.arclength(a) / deg2rad(0.1)) + 1, 4, 4000)) for a in pieces]
        for pc in samples, q in pc
            ll = GM.xyz_to_lonlat(q)
            abs(abs(ll[2]) - 90) < 1e-9 && continue           # exact poles are their own story
            on_seam(q) && continue                             # a seam point has two images
            _min_dist_deg(q, rings) < RIM_SLOP_DEG && continue # ellipsoidal limbs sit a hair inside spherical ones
            n_clip += 1
            n_clip_on += onmap(case.t, q)
        end
        for ll in sample_lonlat(line, N_GRAT_DENSE)
            onmap(case.t, ll[1], ll[2]) || continue
            n_cov += 1
            n_cov_hit += _min_dist_deg(GM.lonlat_to_xyz(ll), samples) <= COVERAGE_TOL_DEG
        end
    end
    nud = GM.Vec3d[]
    for piece in GM.rim(region)
        append!(nud, _nudged_inward(region, piece, RIM_NUDGE_DEG))
    end
    rim_onmap = isempty(nud) ? NaN : count(q -> onmap(case.t, q), nud) / length(nud)
    return (; name = case.name,
        contains_agree = nscored == 0 ? NaN : nagree / nscored,
        worst_false_inside = wfi,
        clip_finite = n_clip == 0 ? NaN : n_clip_on / n_clip,
        clip_coverage = n_cov == 0 ? NaN : n_cov_hit / n_cov,
        rim_onmap)
end

end # module

using .BoundaryHarness
