#=
# Cutting lines at the boundary's seams

A projection with a cut (the `lon_0 ± 180` seam of every cylindrical and
pseudocylindrical map, the lobe seams of Goode's homolosine, the rotated seam
of an `ob_tran`) draws a line that crosses the seam as a stroke across the whole
map.  `CutAtSeams` is a GeometryOps correction that splits such lines where
they cross the seams of the axis' boundary region, on the sphere, so the seams
of a rotated or interrupted projection are exact rather than a `+lon_0` guess.

The crossing point is inserted on both pieces.  Each copy sits a hair off the
seam on its own piece's side, so PROJ (which wraps a point on the seam to one
edge of the map) puts each piece's end on the edge that piece runs to.  A
vertex lying exactly on a seam is nudged off it towards a neighbour for the
same reason.
=#

"""
Minimum separation (radians of arc) between the two copies of an inserted
crossing point, one on each side of the seam.  Well above PROJ's arithmetic
noise, well below any pixel.
"""
const CUT_NUDGE = 1e-8

"""
A vertex within this distance (radians of arc) of a seam plane counts as lying
on the seam: PROJ lets a point overshoot a seam by 1e-12 rad before wrapping
it, so which edge such a vertex lands on is anyone's guess.
"""
const ON_SEAM = 1e-12

"""
    CutAtSeams(seams, crs) <: GeometryOps.GeometryCorrection

Cuts `LineString`s and `MultiLineString`s where they cross one of `seams`
(great-circle arcs on the unit sphere, from `seams(region)`); other geometries
pass through unchanged.  `crs` is the CRS the coordinates are in: lon/lat
degrees (`nothing`, the default source CRS, `EPSG:4326`) are converted to the
sphere directly, anything else through PROJ.  Vertices other than the inserted
crossings (and any vertex lying on a seam, which is nudged off it) are
returned unchanged.
"""
struct CutAtSeams{T, I} <: GO.GeometryCorrection
    seams::Vector{CircleArc}
    to_sphere::T           # input coordinates → unit vector
    from_sphere::I         # unit vector → input coordinates (inserted crossings only)
    lonlat::Bool           # input is lon/lat degrees: a segment spanning half a turn is cut on the sphere chord
end

function CutAtSeams(seams::AbstractVector{CircleArc}, crs)
    if _is_lonlat_crs(crs)
        return CutAtSeams(collect(CircleArc, seams), _lonlat_to_sphere, _sphere_to_lonlat, true)
    end
    to_lonlat = create_transform(LONLAT_CRS, crs)
    from_lonlat = create_transform(crs, LONLAT_CRS)
    to_sphere = p -> begin
        ll = Makie.apply_transform(to_lonlat, Point2d(p[1], p[2]))
        _finite2(ll) ? lonlat_to_xyz(ll[1], ll[2]) : Vec3d(NaN, NaN, NaN)
    end
    from_sphere = x -> begin
        lon, lat = xyz_to_lonlat(x)
        q = Makie.apply_transform(from_lonlat, Point2d(lon, lat))
        (q[1], q[2])
    end
    return CutAtSeams(collect(CircleArc, seams), to_sphere, from_sphere, false)
end

_lonlat_to_sphere(p) = lonlat_to_xyz(Float64(p[1]), Float64(p[2]))
_sphere_to_lonlat(x) = xyz_to_lonlat(x)

"Is `crs` plain lon/lat degrees, so coordinates go to the sphere without PROJ?"
_is_lonlat_crs(::Nothing) = true
_is_lonlat_crs(crs::AbstractString) = is_lonlat_source(crs) || occursin(r"\+proj=(longlat|latlong|lonlat)\b", crs)
_is_lonlat_crs(crs::GeoFormatTypes.EPSG) = GeoFormatTypes.val(crs) == 4326
_is_lonlat_crs(crs::GeoFormatTypes.ProjString) = _is_lonlat_crs(GeoFormatTypes.val(crs))
_is_lonlat_crs(crs) = is_lonlat_source(crs)

GO.application_level(::CutAtSeams) = GI.LineStringTrait

(c::CutAtSeams)(::GI.AbstractLineStringTrait, geom; kw...) = GeometryBasics.MultiLineString(_cut_pieces(c, geom))
function (c::CutAtSeams)(::GI.MultiLineStringTrait, geom; kw...)
    parts = [_cut_pieces(c, l) for l in GI.getgeom(geom)]
    isempty(parts) && return GeometryBasics.MultiLineString(GeometryBasics.LineString{2, Float64}[])
    return GeometryBasics.MultiLineString(reduce(vcat, parts))
end
(c::CutAtSeams)(::GI.AbstractGeometryTrait, geom; kw...) = geom

"The `GeometryBasics.Point` type the pieces of `geom` are built from: its own point type, or `Point{N, Float64}`."
function _piece_point_type(geom)
    p = GI.getpoint(geom, 1)
    N = min(GI.ncoord(p), 3)
    T = p isa GeometryBasics.Point ? eltype(p) : Float64
    return GeometryBasics.Point{N, T}
end

_coords(p, N) = ntuple(i -> Float64(GI.getcoord(p, i)), N)
_lerp(a, b, s) = ntuple(i -> a[i] + (b[i] - a[i]) * s, length(a))
# `_finite3` is defined in decorations/graticule.jl
"Which side of the plane with normal `nrm` the unit vector `x` is on: `-1`, `1`, or `0` within `ON_SEAM` of it."
_side(x, nrm) = (d = _dot3(x, nrm); d < -ON_SEAM ? -1 : d > ON_SEAM ? 1 : 0)
"Is `x` at least `CUT_NUDGE` off the plane on side `want`?"
_clear_of(x, nrm, want::Int) = _finite3(x) && (d = _dot3(x, nrm); want < 0 ? d <= -CUT_NUDGE : d >= CUT_NUDGE)

"""
    _cut_pieces(c, linestring) -> Vector{GeometryBasics.LineString}

The line split at every seam crossing, each piece ending and the next
starting at (its own side's copy of) the crossing.
"""
function _cut_pieces(c::CutAtSeams, geom)
    n = GI.npoint(geom)
    PT = _piece_point_type(geom)
    T = eltype(PT)
    pts = [_coords(p, length(PT)) for p in GI.getpoint(geom)]
    pieces = Vector{PT}[]
    if n >= 2 && !isempty(c.seams)
        xyz = [c.to_sphere(p) for p in pts]
        _nudge_off_seams!(c, pts, xyz, T)
        cur = PT[PT(pts[1])]
        for i in 1:(n - 1)
            a, b = pts[i], pts[i + 1]
            for (_, pa, pb) in _crossings(c, a, b, xyz[i], xyz[i + 1], T)
                push!(cur, PT(pa))
                push!(pieces, cur)
                cur = PT[PT(pb)]
            end
            push!(cur, PT(b))
        end
        push!(pieces, cur)
    else
        push!(pieces, PT[PT(p) for p in pts])
    end
    return [GeometryBasics.LineString(p) for p in pieces]
end

"""
A vertex lying on a seam (within `ON_SEAM`) is moved a hair towards a
neighbour that is not, so every vertex has a side and PROJ wraps it with its
own segment.
"""
function _nudge_off_seams!(c::CutAtSeams, pts, xyz, T)
    n = length(pts)
    for i in 1:n
        _finite3(xyz[i]) || continue
        for seam in c.seams
            _side(xyz[i], seam.axis) == 0 || continue
            on_arc_span(seam, xyz[i]) || continue
            j = i > 1 && _finite3(xyz[i - 1]) && _side(xyz[i - 1], seam.axis) != 0 ? i - 1 :
                i < n && _finite3(xyz[i + 1]) && _side(xyz[i + 1], seam.axis) != 0 ? i + 1 : 0
            j == 0 && continue
            p = _sided_point(c, pts[j], pts[i], 1.0, seam.axis, _side(xyz[j], seam.axis) < 0, T)
            p === nothing && continue
            pts[i] = p
            xyz[i] = c.to_sphere(p)
        end
    end
    return pts
end

"""
    _crossings(c, a, b, xa, xb, T) -> Vector{(s, pa, pb)}

Every seam the segment `a → b` (unit vectors `xa`, `xb`) crosses, in order
along the segment: the parameter of the crossing and the two copies of the
crossing point in input coordinates, `pa` on `a`'s side of the seam and `pb`
on `b`'s, each still on its side once rounded to `T`.
"""
function _crossings(c::CutAtSeams, a, b, xa, xb, T)
    out = Tuple{Float64, typeof(a), typeof(a)}[]
    (_finite3(xa) && _finite3(xb)) || return out
    for seam in c.seams
        nrm = seam.axis
        sa, sb = _side(xa, nrm), _side(xb, nrm)
        (sa == 0 || sb == 0 || sa == sb) && continue
        # where the great-circle chord meets the seam plane; is that on the seam arc at all?
        da, db = abs(_dot3(xa, nrm)), abs(_dot3(xb, nrm))
        x = _unit3(xa * db + xb * da)
        on_arc_span(seam, x) || continue
        s = da / (da + db)
        refined = _refine_crossing(c, a, b, nrm, sa < 0, T)
        if refined === nothing
            pa, pb = _chord_crossing(c, a, b, x, nrm, sa < 0, s, T)
        else
            s, pa, pb = refined
        end
        pa === nothing && continue
        push!(out, (s, pa, pb))
    end
    sort!(out; by = first)
    return out
end

"Does the input-space straight line `a → b` mean what it says (not half a turn of longitude)?"
_lerp_ok(c::CutAtSeams, a, b) = !c.lonlat || abs(b[1] - a[1]) < 180

"""
Bisect the input-space segment for the seam-plane crossing, stopping when the
bracket is `CUT_NUDGE` wide on the sphere; the bracket ends are the two copies.
`nothing` when the straight line is not meaningful or leaves the map.
"""
function _refine_crossing(c::CutAtSeams, a, b, nrm, a_negative::Bool, T)
    _lerp_ok(c, a, b) || return nothing
    lo, hi = 0.0, 1.0
    xlo, xhi = c.to_sphere(a), c.to_sphere(b)
    for _ in 1:64
        angular_distance(xlo, xhi) <= CUT_NUDGE && break
        mid = 0.5 * (lo + hi)
        xm = c.to_sphere(_lerp(a, b, mid))
        _finite3(xm) || return nothing
        if (_dot3(xm, nrm) < 0) == a_negative
            lo, xlo = mid, xm
        else
            hi, xhi = mid, xm
        end
    end
    pa = _sided_point(c, a, b, lo, nrm, a_negative, T)
    pb = _sided_point(c, b, a, 1 - hi, nrm, !a_negative, T)
    (pa === nothing || pb === nothing) && return nothing
    return (0.5 * (lo + hi), pa, pb)
end

"""
The crossing copies from the sphere chord (a segment PROJ would not draw
straight anyway): the chord's crossing nudged off the seam plane to each side
and carried back to input coordinates; extra coordinates interpolated.
"""
function _chord_crossing(c::CutAtSeams, a, b, x, nrm, a_negative::Bool, s, T)
    extra = _lerp(a, b, s)
    δ = CUT_NUDGE
    pa = pb = nothing
    for _ in 1:40
        pa === nothing && (pa = _offset_point(c, x, nrm, a_negative ? -δ : δ, extra, a_negative, T))
        pb === nothing && (pb = _offset_point(c, x, nrm, a_negative ? δ : -δ, extra, !a_negative, T))
        (pa !== nothing && pb !== nothing) && return (pa, pb)
        δ *= 2
    end
    return (nothing, nothing)
end

function _offset_point(c::CutAtSeams, x, nrm, δ, extra, negative::Bool, T)
    p = c.from_sphere(_unit3(x + nrm * δ))
    q = ntuple(i -> Float64(T(i <= 2 ? p[i] : extra[i])), length(extra))
    y = c.to_sphere(q)
    _clear_of(y, nrm, negative ? -1 : 1) || return nothing
    return q
end

"""
The point of the input-space line `a → b` at parameter `s` (from `a`), rounded
to `T`, walked back towards `a` until it is clear of the seam plane on `a`'s
side (`negative`).  `nothing` when not even `a` is.
"""
function _sided_point(c::CutAtSeams, a, b, s, nrm, negative::Bool, T)
    step = 0.0
    want = negative ? -1 : 1
    for _ in 1:80
        sk = max(0.0, s - step)
        p = map(v -> Float64(T(v)), _lerp(a, b, sk))
        _clear_of(c.to_sphere(p), nrm, want) && return p
        sk <= 0 && break
        step = step == 0 ? 1e-12 : 2 * step
    end
    return nothing
end

"""
    split(geoms, ax::GeoAxis; crs = something(GeoInterface.crs(geoms), ax.source[]))

`geoms` (a geometry, a feature, a feature collection, a table, or an array of
any of these) with every line cut where it crosses a seam of `ax`'s projection
(see `CutAtSeams`).  `crs` is the CRS the coordinates are in: the keyword
when given, else the geometry's own CRS, else the axis' `source`.
"""
function Base.split(geoms, ax::GeoAxis; crs = something(GI.crs(geoms), ax.source[]))
    c = CutAtSeams(seams(ax.graph[:boundary][]), crs)
    return GO.apply(GO.WithTrait(c), GI.AbstractGeometryTrait, geoms; crs)
end

"""
    coastlines(ax::GeoAxis)

An `Observable` of the Natural Earth coastlines cut at the seams of `ax`'s
projection (see `split(geoms, ax)`), so a `+lon_0` other than zero, an oblique
`ob_tran` or an interrupted map draws no coastline across a seam.  It follows
`ax.dest`.
"""
coastlines(ax::GeoAxis) = lift(ax.blockscene, ax.dest, ax.outline) do _, _
    split(coastlines(), ax)
end
