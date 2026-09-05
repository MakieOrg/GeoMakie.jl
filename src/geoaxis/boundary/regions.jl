#=
# Regions on the unit sphere

A projection's domain is a region built from two primitives, `Zone` (a slab
`lo ≤ p·axis ≤ hi`, i.e. a cap or a latitude band about any axis) and `Wedge`
(an azimuthal sector about an axis; a sector of width 2π is a pure cut), combined
with `Intersection` and `RegionUnion`.  `SpherePolygon` is the shape the probe
returns and the shape a user-supplied outline becomes.  Every primitive carries
the tag its rim pieces will get (`:limb`, `:limit`, `:cut`).

The two operations the rest of the axis needs are
  * `clip(region, arc)`   – the parts of an arc inside the region, and
  * `rim(region)`         – the region's boundary as tagged pieces with provenance,
and both are closed-form: crossings come from `circle_roots`, membership from
`contains` at interval midpoints.  Nothing here calls PROJ.
=#

const MEMBER_TOL = 1e-9          # slack for on-boundary membership tests
const SEAM_EPS = 1e-4            # rad; rim pieces are inset this far from a cut seam
const ROOT_MERGE = 1e-7          # arc parameter; crossings closer than this merge
const MIN_PIECE = 1e-6           # rad; rim pieces shorter than this are dropped
const INSET_CAP_DEG = 0.1        # cap on the seam inset in arc parameter, degrees
const MAX_INSET = deg2rad(INSET_CAP_DEG)
const MERCATOR_BAND_DEG = 85.0511287798066   # atand(sinh(π)): the square Mercator band
const CONIC_CUTOFF_DEG = 30.0    # conics are cut this far into the opposite hemisphere
const TMERC_CUTOFF_DEG = 10.0    # half-width (deg from the meridian plane) of the tmerc band
const ANTIPODE_CAP_DEG = 179.9   # laea / aeqd: everything but a pinhole at the antipode
const STEREO_CAP_DEG = 150.0     # stere: beyond this the antipode blows up
const CHAIN_TOL = 5e-3           # rad; rim pieces chain when endpoints are this close
const ORIENT_NUDGE = 1e-3        # rad; interior probe offset when orienting a loop

abstract type SphereRegion end

"""
    Zone(axis, lo, hi; tag = :limb)

Points with `lo ≤ p·axis ≤ hi`.  `Zone(axis, cosd(r), 1)` is a cap of angular
radius `r`, `Zone(ẑ, sind(lat0), sind(lat1))` a latitude band.
"""
struct Zone <: SphereRegion
    axis::Vec3d
    lo::Float64
    hi::Float64
    tag::Symbol
end
Zone(axis, lo, hi; tag::Symbol = :limb) = Zone(_unit3(axis), float(lo), float(hi), tag)

"""
    Wedge(axis, seam, width; tag = :cut)

Points whose azimuth about `axis`, measured counter-clockwise from the direction
`seam`, lies in `[0, width]`.  `width == 2π` keeps the whole sphere but records a
cut along the seam half-meridian, which is what a `+lon_0` seam is.
"""
struct Wedge <: SphereRegion
    axis::Vec3d
    seam::Vec3d
    width::Float64
    tag::Symbol
end
function Wedge(axis, seam, width; tag::Symbol = :cut)
    a = _unit3(axis)
    s = _unit3(_v3(seam) - a * _dot3(seam, a))
    return Wedge(a, s, float(width), tag)
end

struct Intersection{T <: Tuple} <: SphereRegion
    parts::T
end
Intersection(parts...) = Intersection(parts)
Intersection(parts::AbstractVector) = Intersection(Tuple(parts))

struct RegionUnion{T <: Tuple} <: SphereRegion
    parts::T
end
RegionUnion(parts...) = RegionUnion(parts)
RegionUnion(parts::AbstractVector) = RegionUnion(Tuple(parts))

"""
    SpherePolygon(rim, inside; tag = :limb)

A region bounded by a closed chain of great-circle arcs, distinguished from its
complement by the point `inside`.
"""
struct SpherePolygon <: SphereRegion
    rim::Vector{CircleArc}
    inside::Vec3d
    tag::Symbol
end
SpherePolygon(rim, inside; tag::Symbol = :limb) = SpherePolygon(collect(CircleArc, rim), _unit3(inside), tag)

"""
    RimPiece(arc, tag, part, side)

One piece of a region's boundary.  `part` numbers the primitive (pre-order) the
piece came from, `side` is `±1` for the two sides of a cut seam (the arc has been
rotated `side · SEAM_EPS` about the wedge axis), `0` otherwise.  The frame chains
pieces on provenance, never on tolerance alone.
"""
struct RimPiece
    arc::CircleArc
    tag::Symbol
    part::Int
    side::Int8
end

whole_sphere() = Zone(ZHAT, -1.0, 1.0)
isfullsphere(r::Zone) = r.lo <= -1 + MEMBER_TOL && r.hi >= 1 - MEMBER_TOL
isfullsphere(r::Intersection) = all(isfullsphere, r.parts)
isfullsphere(r::RegionUnion) = any(isfullsphere, r.parts)
isfullsphere(::SphereRegion) = false

# ---- rotation --------------------------------------------------------------

rotate(z::Zone, R) = Zone(Vec3d(R * z.axis), z.lo, z.hi, z.tag)
rotate(w::Wedge, R) = Wedge(Vec3d(R * w.axis), Vec3d(R * w.seam), w.width, w.tag)
rotate(r::Intersection, R) = Intersection(map(p -> rotate(p, R), r.parts))
rotate(r::RegionUnion, R) = RegionUnion(map(p -> rotate(p, R), r.parts))
rotate(p::SpherePolygon, R) = SpherePolygon([rotate(a, R) for a in p.rim], Vec3d(R * p.inside), p.tag)

# ---- membership ------------------------------------------------------------

function Base.contains(z::Zone, p)
    d = _dot3(p, z.axis)
    return z.lo - MEMBER_TOL <= d <= z.hi + MEMBER_TOL
end

"Azimuth of `p` about the wedge axis, counter-clockwise from the seam, in `[0, 2π)`."
wedge_azimuth(w::Wedge, p) = mod(atan(_dot3(p, _cross3(w.axis, w.seam)), _dot3(p, w.seam)), 2pi)

function Base.contains(w::Wedge, p)
    w.width >= 2pi - MEMBER_TOL && return true
    # points on the axis have no azimuth and belong to every wedge
    abs(_dot3(p, w.axis)) >= 1 - MEMBER_TOL && return true
    az = wedge_azimuth(w, p)
    return az <= w.width + MEMBER_TOL || az >= 2pi - MEMBER_TOL
end

Base.contains(r::Intersection, p) = all(part -> contains(part, p), r.parts)
Base.contains(r::RegionUnion, p) = any(part -> contains(part, p), r.parts)

function Base.contains(poly::SpherePolygon, p)
    q = _unit3(p)
    d = angular_distance(poly.inside, q)
    d < 1e-12 && return true
    d > pi - 1e-9 && (q = _unit3(q + _perp3(q) * 1e-9))
    test = great_arc(poly.inside, q)
    n = 0
    for a in poly.rim
        roots, degenerate = circle_roots(test, a.axis, 0.0)
        degenerate && continue
        for (t, _) in roots
            on_arc_span(a, arcpoint(test, t)) && (n += 1)
        end
    end
    return iseven(n)
end

# ---- crossings and clipping ------------------------------------------------

# A crossing of an arc with a region boundary: parameter, inset scale, is it a cut seam.
const Crossing = Tuple{Float64, Float64, Bool}

function crossings!(out::Vector{Crossing}, z::Zone, a::CircleArc)
    for k in (z.lo, z.hi)
        abs(k) >= 1 - MEMBER_TOL && continue
        roots, _ = circle_roots(a, z.axis, k)
        for (t, s) in roots
            push!(out, (t, s, false))
        end
    end
    return out
end

"Direction of the wedge's end edge (azimuth `width` from the seam)."
wedge_end(w::Wedge) = Vec3d(rotation_about(w.axis, w.width) * w.seam)

function crossings!(out::Vector{Crossing}, w::Wedge, a::CircleArc)
    iscut = w.tag == :cut
    edges = w.width >= 2pi - MEMBER_TOL ? (w.seam,) : (w.seam, wedge_end(w))
    for d in edges
        n = _cross3(w.axis, d)
        roots, _ = circle_roots(a, n, 0.0)
        for (t, s) in roots
            # only the half-meridian through `d`, not its continuation past the axis
            _dot3(arcpoint(a, t), d) >= -MEMBER_TOL && push!(out, (t, s, iscut))
        end
    end
    return out
end

function crossings!(out::Vector{Crossing}, r::Union{Intersection, RegionUnion}, a::CircleArc)
    for part in r.parts
        crossings!(out, part, a)
    end
    return out
end

function crossings!(out::Vector{Crossing}, poly::SpherePolygon, a::CircleArc)
    for e in poly.rim
        roots, _ = circle_roots(a, e.axis, 0.0)
        for (t, s) in roots
            on_arc_span(e, arcpoint(a, t)) && push!(out, (t, s, false))
        end
    end
    return out
end

"""
    _split(r, arc, want) -> Vector{CircleArc}

Sub-arcs of `arc` whose interior is inside `r` (`want = true`) or outside it
(`want = false`).  Consecutive kept intervals merge unless separated by a cut
seam, and interval ends that lie on a cut seam are inset by `SEAM_EPS` (in
angle, capped at `MAX_INSET` in parameter) so their projection is unambiguous.
"""
function _split(r::SphereRegion, a::CircleArc, want::Bool)
    cs = crossings!(Crossing[], r, a)
    sort!(cs; by = first)
    # merge near-coincident crossings; a cut wins
    merged = Crossing[]
    for c in cs
        if !isempty(merged) && c[1] - merged[end][1] <= ROOT_MERGE
            m = merged[end]
            merged[end] = (m[1], max(m[2], c[2]), m[3] | c[3])
        else
            push!(merged, c)
        end
    end
    if isempty(merged)
        return contains(r, arcpoint(a, 0.5 * (a.t0 + a.t1))) == want ? [a] : CircleArc[]
    end
    # breakpoints (t, scale, iscut)
    if isfull(a)
        bps = copy(merged)
        push!(bps, (merged[1][1] + 2pi, merged[1][2], merged[1][3]))
    else
        bps = Crossing[(a.t0, 0.0, false)]
        append!(bps, merged)
        push!(bps, (a.t1, 0.0, false))
    end
    keep = [contains(r, arcpoint(a, 0.5 * (bps[i][1] + bps[i + 1][1]))) == want for i in 1:(length(bps) - 1)]
    out = CircleArc[]
    i = 1
    while i < length(bps)
        if !keep[i]
            i += 1
            continue
        end
        j = i
        while j + 1 < length(bps) && keep[j + 1] && !bps[j + 1][3]
            j += 1
        end
        ta, sa, ca = bps[i]
        tb, sb, cb = bps[j + 1]
        ca && (ta += min(SEAM_EPS * sa, MAX_INSET))
        cb && (tb -= min(SEAM_EPS * sb, MAX_INSET))
        (tb - ta) * sinrad(a) > MIN_PIECE && push!(out, CircleArc(a.axis, a.u, a.v, a.cosθ, ta, tb))
        i = j + 1
    end
    return out
end

"The parts of `arc` lying inside `r`."
clip(r::SphereRegion, a::CircleArc) = _split(r, a, true)

# ---- rim -------------------------------------------------------------------

"""
    rim(r) -> Vector{RimPiece}

The boundary of `r` as tagged arcs with provenance.  Cut seams appear twice,
once per side, each inset by `SEAM_EPS`.
"""
function rim(r::SphereRegion)
    out = RimPiece[]
    _rim!(out, r, Ref(0))
    return out
end

function _rim!(out, z::Zone, counter::Ref{Int})
    id = (counter[] += 1)
    z.lo > -1 + MEMBER_TOL && push!(out, RimPiece(full_circle(z.axis, z.lo), z.tag, id, 0))
    z.hi < 1 - MEMBER_TOL && push!(out, RimPiece(full_circle(z.axis, z.hi), z.tag, id, 0))
    return out
end

function _rim!(out, w::Wedge, counter::Ref{Int})
    id = (counter[] += 1)
    iscut = w.tag == :cut
    start = half_meridian(w.axis, w.seam)
    stop = half_meridian(w.axis, wedge_end(w))
    if iscut
        push!(out, RimPiece(rotate(start, rotation_about(w.axis, SEAM_EPS)), w.tag, id, 1))
        push!(out, RimPiece(rotate(stop, rotation_about(w.axis, -SEAM_EPS)), w.tag, id, -1))
    elseif w.width < 2pi - MEMBER_TOL
        push!(out, RimPiece(start, w.tag, id, 0))
        push!(out, RimPiece(stop, w.tag, id, 0))
    end
    return out
end

function _rim!(out, poly::SpherePolygon, counter::Ref{Int})
    id = (counter[] += 1)
    for a in poly.rim
        push!(out, RimPiece(a, poly.tag, id, 0))
    end
    return out
end

_others(parts::Tuple, i) = Tuple(parts[j] for j in eachindex(parts) if j != i)

function _rim!(out, r::Intersection, counter::Ref{Int})
    pieces = RimPiece[]
    for (i, part) in enumerate(r.parts)
        sub = RimPiece[]
        _rim!(sub, part, counter)
        others = _others(r.parts, i)
        for piece in sub
            if isempty(others)
                push!(pieces, piece)
            else
                for a in _split(Intersection(others), piece.arc, true)
                    push!(pieces, RimPiece(a, piece.tag, piece.part, piece.side))
                end
            end
        end
    end
    # a user limit lying on a seam duplicates that seam's inset side: keep the
    # limit (its projection is unambiguous) and drop the seam piece
    for piece in pieces
        k = findfirst(q -> _coincident(q.arc, piece.arc; tol = 1.5 * SEAM_EPS), out)
        if k === nothing
            push!(out, piece)
        elseif out[k].tag == :cut && piece.tag != :cut
            out[k] = piece
        end
    end
    return out
end

function _rim!(out, r::RegionUnion, counter::Ref{Int})
    for (i, part) in enumerate(r.parts)
        sub = RimPiece[]
        _rim!(sub, part, counter)
        others = _others(r.parts, i)
        for piece in sub
            if piece.tag == :cut || isempty(others)
                push!(out, piece)
            else
                for a in _split(RegionUnion(others), piece.arc, false)
                    push!(out, RimPiece(a, piece.tag, piece.part, piece.side))
                end
            end
        end
    end
    return out
end

"Two arcs occupying the same set of points (either direction)."
function _coincident(a::CircleArc, b::CircleArc; tol = 1e-9)
    abs(arclength(a) - arclength(b)) > tol && return false
    a0, a1, am = arcpoint(a, a.t0), arcpoint(a, a.t1), arcpoint(a, 0.5 * (a.t0 + a.t1))
    b0, b1, bm = arcpoint(b, b.t0), arcpoint(b, b.t1), arcpoint(b, 0.5 * (b.t0 + b.t1))
    norm(am - bm) > tol && return false
    return (norm(a0 - b0) <= tol && norm(a1 - b1) <= tol) || (norm(a0 - b1) <= tol && norm(a1 - b0) <= tol)
end

"""
    seams(r) -> Vector{CircleArc}

The cut seams of `r` (unrotated, one arc per seam), for splitting graticule
lines and data that cross them.
"""
function seams(r::SphereRegion)
    out = CircleArc[]
    for piece in rim(r)
        piece.tag == :cut || continue
        piece.side == 1 || continue
        push!(out, rotate(piece.arc, rotation_about(piece.arc.u, -SEAM_EPS * piece.side)))
    end
    return out
end

# ---- user-facing constructors ---------------------------------------------

"""
    Quadrangle(lons, lats)

The lon/lat rectangle `lons[1]..lons[2] × lats[1]..lats[2]` as a region tagged
`:limit`; degenerate bounds (a full 360° of longitude, ±90° latitude) contribute
nothing so the rim only carries edges the user actually asked for.
"""
function Quadrangle(lons, lats)
    parts = SphereRegion[]
    lo, hi = float(lons[1]), float(lons[2])
    if hi - lo < 360 - 1e-9
        push!(parts, Wedge(ZHAT, _dir(lo), deg2rad(hi - lo); tag = :limit))
    end
    la0, la1 = clamp(float(lats[1]), -90, 90), clamp(float(lats[2]), -90, 90)
    if la0 > -90 + 1e-9 || la1 < 90 - 1e-9
        push!(parts, Zone(ZHAT, la0 <= -90 + 1e-9 ? -1.0 : sind(la0), la1 >= 90 - 1e-9 ? 1.0 : sind(la1); tag = :limit))
    end
    isempty(parts) && return whole_sphere()
    length(parts) == 1 && return parts[1]
    return Intersection(parts)
end

Quadrangle(rect::Rect2) = Quadrangle((minimum(rect)[1], maximum(rect)[1]), (minimum(rect)[2], maximum(rect)[2]))
