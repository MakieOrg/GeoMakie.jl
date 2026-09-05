#=
# Analytic domains

The closed-form domain of every projection we know about, as a region on the
sphere for its reference parameters (`lon_0 = 0`, `lat_0 = 0`), plus the kind of
rotation that carries it onto the parameterised projection.  A projection's real
domain is `rotate(reference, R)` with `R` from `lon0_rotation`,
`centre_rotation` or `obtran_rotation`, all of which satisfy

    proj_parameterised(p) == proj_reference(R' * p).
=#

# ---- rotations relating a projection to its reference ---------------------

"Rotation carrying the `+lon_0=0` domain onto the `+lon_0=lon_0` one."
lon0_rotation(lon_0::Real) = Rz(lon_0)

"Rotation for an azimuthal projection centred on `(lon_0, lat_0)`; `R * x̂` is the centre."
centre_rotation(lon_0::Real, lat_0::Real) = Rz(lon_0) * Ry(-lat_0)

"""
Rotation for `+proj=ob_tran +o_lon_p=α +o_lat_p=β +lon_0=γ`: ob_tran evaluates
the inner projection at `F p` with `F = Rz(α) Ry(90 - β) Rz(-γ)`, so the domain
is `F' · (inner domain)`.
"""
obtran_rotation(o_lon_p::Real, o_lat_p::Real, lon_0::Real) =
    transpose(Rz(o_lon_p) * Ry(90 - o_lat_p) * Rz(-lon_0))

# ---- reference shapes ------------------------------------------------------

"Cap of angular radius `radius_deg` about `centre` (default the reference centre `x̂`)."
Cap(radius_deg::Real; centre = XHAT, tag = :limb) = Zone(centre, cosd(radius_deg), 1.0; tag)

"Latitude band `lat0..lat1` (no cut)."
LatBand(lat0::Real, lat1::Real; tag = :limb) = Zone(ZHAT, sind(lat0), sind(lat1); tag)

"The whole sphere with a seam at `lon_0 + 180`: every cylindrical / pseudocylindrical domain."
CutQuadrangle(lon_0::Real = 0.0) = Wedge(ZHAT, _dir(lon_0 + 180), 2pi; tag = :cut)

"""
Conic domain: the seam at `lon_0 + 180` and a cutoff parallel.  `cutoff < 0`
keeps `lat ≥ cutoff` (a northern conic), `cutoff > 0` keeps `lat ≤ cutoff`.
"""
function Conic(lon_0::Real, cutoff::Real)
    zone = cutoff < 0 ? Zone(ZHAT, sind(cutoff), 1.0) : Zone(ZHAT, -1.0, sind(cutoff))
    return Intersection(zone, CutQuadrangle(lon_0))
end

"""
Transverse Mercator band: the sphere minus caps of radius `δ` about the two
points 90° east and west of the central meridian on the equator (where PROJ's
extended tmerc blows up).  A single `Zone` about the east direction.
"""
TransverseBand(lon_0::Real, δ::Real = TMERC_CUTOFF_DEG) = Zone(_dir(lon_0 + 90), -cosd(δ), cosd(δ))

"""
Transverse Mercator domain: the band, cut along the far half of the equator
(from one singular point through `lon_0 + 180` to the other), which is the
transverse aspect's antimeridian and maps to the top and bottom edges.
"""
TransverseMercator(lon_0::Real = 0.0, δ::Real = TMERC_CUTOFF_DEG) =
    Intersection(TransverseBand(lon_0, δ), Wedge(_dir(lon_0 + 90), _dir(lon_0 + 180), 2pi; tag = :cut))

"Goode's interrupted homolosine: PROJ's six lobes, as a union of `Zone ∩ Wedge`."
function GoodeLobes()
    N = Zone(ZHAT, 0.0, 1.0)
    S = Zone(ZHAT, -1.0, 0.0)
    lobe(z, lo, hi) = Intersection(z, Wedge(ZHAT, _dir(lo), deg2rad(hi - lo); tag = :cut))
    return RegionUnion(lobe(N, -180, -40), lobe(N, -40, 180),
                       lobe(S, -180, -100), lobe(S, -100, -20), lobe(S, -20, 80), lobe(S, 80, 180))
end

# ---- the +proj token table -------------------------------------------------

const WGS84_A = 6378137.0
_p(params, k, default) = get(params, k, default)

"Satellite-view limb: the horizon seen from height `h` (with a hair of margin so the rim projects)."
function _satellite(params)
    R = _p(params, :R, _p(params, :a, WGS84_A))
    h = _p(params, :h, 35785831.0)
    return Cap(acosd(R / (R + h)) - 1e-3)
end

"Conic hemisphere from the standard parallels' sign; the cutoff lies in the other one."
function _conic(params)
    lat1 = _p(params, :lat_1, _p(params, :lat_0, 0.0))
    lat2 = _p(params, :lat_2, lat1)
    north = lat1 + lat2 >= 0
    return Conic(0.0, north ? -CONIC_CUTOFF_DEG : CONIC_CUTOFF_DEG)
end

_utm_lon0(params) = haskey(params, :zone) ? 6 * params[:zone] - 183 : 0.0

const _PSEUDOCYLINDRICAL = (
    :robin, :moll, :eqearth, :sinu, :wintri, :hammer, :aitoff, :natearth, :natearth2, :eqc,
    :eck1, :eck2, :eck3, :eck4, :eck5, :eck6, :wag1, :wag2, :wag3, :wag4, :wag5, :wag6, :wag7,
    :kav5, :kav7, :putp1, :putp2, :putp3, :putp3p, :putp4p, :putp5, :putp5p, :putp6, :putp6p,
    :mbt_s, :mbt_fps, :mbtfpp, :mbtfpq, :mbtfps, :cea, :mill, :gall, :patterson, :times, :vandg,
    :boggs, :collg, :crast, :denoy, :fahey, :fouc, :fouc_s, :gins8, :hatano, :loxim, :nell, :nell_h,
    :wink1, :wink2, :qua_aut, :bonne, :august, :weren, :urm5, :urmfps, :ortel, :apian, :bacon,
    :comill, :goode, :sinu, :moll, :nicol, :lask, :larr, :mbt_s, :wag7,
)

"""
    PROJ_TOKENS :: Dict{Symbol, Tuple{Function, Symbol}}

`+proj` token → `(builder(params) -> reference region, rotation kind)`.  Rotation
kinds: `:lon0` (`lon0_rotation`), `:centre` (`centre_rotation`), `:none`.
Tokens not listed fall through to the probe.
"""
const PROJ_TOKENS = Dict{Symbol, Tuple{Function, Symbol}}(
    :ortho => (p -> Cap(90.0), :centre),
    :airy => (p -> Cap(90.0), :centre),      # PROJ refuses beyond the hemisphere whatever +lat_b is
    :laea => (p -> Cap(ANTIPODE_CAP_DEG), :centre),
    :aeqd => (p -> Cap(ANTIPODE_CAP_DEG), :centre),
    :stere => (p -> Cap(STEREO_CAP_DEG), :centre),
    :geos => (_satellite, :centre),
    :nsper => (_satellite, :centre),
    :merc => (p -> Intersection(LatBand(-MERCATOR_BAND_DEG, MERCATOR_BAND_DEG), CutQuadrangle()), :lon0),
    :webmerc => (p -> Intersection(LatBand(-MERCATOR_BAND_DEG, MERCATOR_BAND_DEG), CutQuadrangle()), :lon0),
    :lcc => (_conic, :lon0),
    :aea => (_conic, :lon0),
    :eqdc => (_conic, :lon0),
    :tmerc => (p -> TransverseMercator(), :lon0),
    :etmerc => (p -> TransverseMercator(), :lon0),
    :utm => (p -> TransverseMercator(), :lon0),
    :igh => (p -> GoodeLobes(), :lon0),
    :longlat => (p -> whole_sphere(), :none),
    :latlong => (p -> whole_sphere(), :none),
    :lonlat => (p -> whole_sphere(), :none),
)
for tok in _PSEUDOCYLINDRICAL
    PROJ_TOKENS[tok] = (p -> CutQuadrangle(), :lon0)
end

"""
    analytic_region(id) -> Union{SphereRegion, Nothing}

The domain of an identified projection (see `identify`), or `nothing` when its
`+proj` token is not in `PROJ_TOKENS`.
"""
function analytic_region(id)
    id === nothing && return nothing
    method = id.method
    params = id.params
    if method == :ob_tran
        inner = get(PROJ_TOKENS, id.o_proj, nothing)
        inner === nothing && return nothing
        q = copy(params)
        delete!(q, :lon_0); delete!(q, :lat_0)
        base = _rotated(inner, q)
        return rotate(base, obtran_rotation(_p(params, :o_lon_p, 0.0), _p(params, :o_lat_p, 90.0), _p(params, :lon_0, 0.0)))
    end
    entry = get(PROJ_TOKENS, method, nothing)
    entry === nothing && return nothing
    if method == :utm
        q = copy(params); q[:lon_0] = _utm_lon0(params)
        return _rotated(entry, q)
    end
    return _rotated(entry, params)
end

function _rotated(entry, params)
    builder, kind = entry
    ref = builder(params)
    kind == :none && return ref
    kind == :lon0 && return rotate(ref, lon0_rotation(_p(params, :lon_0, 0.0)))
    return rotate(ref, centre_rotation(_p(params, :lon_0, 0.0), _p(params, :lat_0, 0.0)))
end
