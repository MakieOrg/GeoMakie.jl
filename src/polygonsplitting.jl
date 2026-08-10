############################################################
#                                                          #
#         Antimeridian splitting of filled polygons        #
#                                                          #
############################################################
#
# Polygon- and line-cutting primitives used by the `Contourf`/`Contour`
# overrides on a `GeoAxis`.  When a contour crosses the antimeridian of the
# destination projection (the meridian at `lon_0 ± 180`), an edge whose two
# endpoints sit on opposite sides of the globe is, after per-vertex
# projection, drawn as a horizontal smear across the canvas.
#
# Filled bands (`split_polygon`) are cut by clipping the polygon against each
# 360°-wide longitude strip with `GeometryOps.intersection` and translating
# the clipped pieces back into `[lon_0 - 180, lon_0 + 180]`; abutting strip
# boundaries coincide after translation, so the pieces tile exactly (no gaps,
# no overlaps), and holes / multiple crossings are handled robustly.  Contour
# *lines* (`split_linestring_points`) are 1-D, so they are split with a cheap
# single pass that inserts boundary vertices and a `NaN` break at each crossing.

"""
    parse_lon0(s)

Pull the `lon_0=<value>` argument out of a PROJ string.  Returns `0.0` if not
present.  Matches both the user form (`+lon_0=150`) and the form found in a
resolved `Proj.Transformation` definition, which is a *pipeline* where the
parameter appears without the leading `+` (e.g. `... step proj=moll lon_0=150
x_0=0 ...`).
"""
function parse_lon0(s::AbstractString)
    m = match(r"lon_0=([-+]?\d+(?:\.\d+)?)", s)
    return m === nothing ? 0.0 : parse(Float64, m.captures[1])
end

@inline _normalise_lon(lon::Real, lon0::Real) = lon0 + mod(lon - lon0 + 180.0, 360.0) - 180.0

# Linearly interpolate latitude at the crossing of the antimeridian.
# `sign_dir` is +1 if the short path from `a` to `b` goes west
# (through `lon0 - 180`) and -1 if it goes east (through `lon0 + 180`).
@inline function _crossing_latitude(lon_a, lat_a, lon_b, lat_b, lon0, sign_dir)
    lon_b_shifted = lon_b + sign_dir * 360.0
    t = (lon0 + sign_dir * 180.0 - lon_a) / (lon_b_shifted - lon_a)
    return lat_a + t * (lat_b - lat_a)
end

# Translate a polygon's longitudes by `dx`, returning a fresh `Float32` polygon.
function _shift_polygon(poly::GeometryBasics.Polygon, dx::Real)
    ext = [Point2f(p[1] + dx, p[2]) for p in GeometryBasics.coordinates(poly.exterior)]
    holes = [
        GeometryBasics.LineString([Point2f(p[1] + dx, p[2]) for p in GeometryBasics.coordinates(h)])
            for h in poly.interiors
    ]
    return isempty(holes) ? Polygon(GeometryBasics.LineString(ext)) :
           Polygon(GeometryBasics.LineString(ext), holes)
end

# Pull-in distance (degrees) for seam vertices, see `_densify_seam_ring`.
const SEAM_EPS = 1.0f-3

# Post-process the ring edges that lie exactly on a seam meridian (`lon == lon0
# ± 180`).  Two things happen there:
#
#  1. **Densify.** A meridian projects to a *curve* (e.g. the elliptical edge of
#     a Mollweide map), so drawing the seam edge as one straight chord cuts
#     across it.  We resample seam edges in latitude (steps ≤ `dlat`) so the
#     projected boundary follows the curved meridian.
#
#  2. **Nudge.** A vertex sitting *exactly* on the projection's antimeridian
#     (`lon0 ± 180`) projects ambiguously — Proj may map it to either screen
#     edge — which makes the long seam edge zig-zag into a sawtooth.  We pull
#     seam vertices a hair (`SEAM_EPS`) toward `lon0` so they project cleanly to
#     one side.  The inset is ~10⁻³° (≈ 100 m), i.e. invisible, and the
#     antimeridian is the map edge anyway.
#
# Non-seam edges come straight from the (already dense) contour and are untouched.
function _densify_seam_ring(pts::AbstractVector{<:GeometryBasics.Point2}, lon0::Real, dlat::Real)
    n = length(pts)
    n < 2 && return collect(Point2f, pts)
    seam_lo = Float32(lon0 - 180.0)
    seam_hi = Float32(lon0 + 180.0)
    on_lo(x) = abs(x - seam_lo) < 1.0f-2
    on_hi(x) = abs(x - seam_hi) < 1.0f-2
    # nudged longitude for a seam vertex (pulled inside the antimeridian)
    seamlon(x) = on_lo(x) ? seam_lo + SEAM_EPS : (on_hi(x) ? seam_hi - SEAM_EPS : Float32(x))
    out = Point2f[]
    sizehint!(out, n)
    @inbounds for i in 1:(n - 1)
        p = pts[i]
        q = pts[i + 1]
        sx = seamlon(p[1])
        push!(out, Point2f(sx, p[2]))
        # edge running along a single seam meridian -> resample in latitude
        if (on_lo(p[1]) || on_hi(p[1])) && abs(p[1] - q[1]) < 1.0f-2 && abs(q[2] - p[2]) > dlat
            nseg = ceil(Int, abs(q[2] - p[2]) / dlat)
            for k in 1:(nseg - 1)
                t = Float32(k / nseg)
                push!(out, Point2f(sx, p[2] + t * (q[2] - p[2])))
            end
        end
    end
    p = pts[n]
    push!(out, Point2f(seamlon(p[1]), p[2]))
    return out
end

# Convert a `GeoInterface` polygon (a clip result) into a `Float32`
# `GeometryBasics.Polygon`, translating longitudes by `dx` and densifying any
# edge that lies along the seam meridian (see `_densify_seam_ring`).
function _gi_polygon_to_gb(p, dx::Real, lon0::Real, dlat::Real)
    ext = _densify_seam_ring(
        [Point2f(GI.x(pt) + dx, GI.y(pt)) for pt in GI.getpoint(GI.getexterior(p))], lon0, dlat,
    )
    GI.nhole(p) == 0 && return Polygon(GeometryBasics.LineString(ext))
    holes = [
        GeometryBasics.LineString(
            _densify_seam_ring([Point2f(GI.x(pt) + dx, GI.y(pt)) for pt in GI.getpoint(h)], lon0, dlat)
        ) for h in GI.gethole(p)
    ]
    return Polygon(GeometryBasics.LineString(ext), holes)
end

"""
    split_polygon(poly, lon0; close_at_poles=true)

Split a `GeometryBasics.Polygon` (with optional holes) at the antimeridian
`lon0 ± 180`, returning `Vector{Polygon{2, Float32}}` with every piece lying
inside `[lon0 - 180, lon0 + 180]`.

The polygon's longitudes may be *unwrapped* (any range — e.g. a curvilinear
ocean grid whose coordinate runs 70°…430°).  Rather than walk-and-cut the ring
(which mis-stitches bands that cross the seam several times or that are merely
shifted off `[-180, 180]`), we clip the polygon against each 360°-wide
longitude strip `[lon0 - 180 + 360k, lon0 + 180 + 360k]` and translate the
clipped piece back into `[lon0 - 180, lon0 + 180]`.  Because neighbouring strip
boundaries coincide after translation, the pieces tile the original exactly —
no gaps, no overlaps.  Clipping is done with `GeometryOps.intersection`, which
handles holes and arbitrary crossings robustly.

`close_at_poles` is accepted for backwards compatibility but currently unused;
pole-enclosing rings (longitude span ≥ 360°) are clipped like any other.
"""
function split_polygon(
        poly::GeometryBasics.Polygon, lon0::Real;
        close_at_poles::Bool = true,
        seam_dlat::Real = 1.0,
    )
    extpts = GeometryBasics.coordinates(poly.exterior)
    isempty(extpts) && return Polygon{2, Float32}[]
    lo = minimum(p[1] for p in extpts)
    hi = maximum(p[1] for p in extpts)

    # Pass-through: the polygon already lies entirely inside the projection
    # window `[lon0 - 180, lon0 + 180]`, so it neither wraps nor needs shifting.
    # Return the *original* object untouched — reconstructing/clipping it (which a
    # `hi` sitting exactly on `lon0 + 180` would otherwise trigger) can perturb
    # multi-hole contour bands and leave thin rendering seams.
    if lon0 - 180.0 - 1.0e-6 <= lo && hi <= lon0 + 180.0 + 1.0e-6
        return [poly]
    end

    kmin = floor(Int, (lo - (lon0 - 180.0)) / 360.0)
    kmax = floor(Int, (hi - (lon0 - 180.0)) / 360.0)

    # Fast path: the whole polygon fits inside a single 360° strip but is shifted
    # off the window — translate it into `[lon0 - 180, lon0 + 180]`.
    if kmin == kmax
        return [_shift_polygon(poly, -360.0 * kmin)]
    end

    pieces = Polygon{2, Float32}[]
    for k in kmin:kmax
        xlo = lon0 - 180.0 + 360.0 * k
        xhi = lon0 + 180.0 + 360.0 * k
        rect = Polygon([Point2f(xlo, -95), Point2f(xhi, -95), Point2f(xhi, 95), Point2f(xlo, 95), Point2f(xlo, -95)])
        local clipped
        try
            clipped = GO.intersection(poly, rect; target = GI.PolygonTrait())
        catch
            continue
        end
        for r in clipped
            gb = _gi_polygon_to_gb(r, -360.0 * k, lon0, seam_dlat)
            length(GeometryBasics.coordinates(gb.exterior)) >= 4 && push!(pieces, gb)
        end
    end
    return pieces
end

# Subdivide a ring so no edge is longer than `dl` degrees (linear in lon/lat).
# Only inserts points on long edges — existing vertices are kept exactly, so the
# band shape is unchanged.  This is what stops the projected fill from showing
# thin white seams: a contour band's edges come at the data-grid spacing (e.g.
# 4°), and projecting those long edges as straight chords leaves slivers between
# adjacent bands near the seam.  Densifying first makes the chords follow the
# projected meridians/parallels.
function _densify_ring(pts::AbstractVector{<:GeometryBasics.Point2}, dl::Real)
    n = length(pts)
    n < 2 && return collect(Point2f, pts)
    out = Point2f[]
    sizehint!(out, n)
    @inbounds for i in 1:(n - 1)
        a = pts[i]; b = pts[i + 1]
        push!(out, Point2f(a))
        d = max(abs(b[1] - a[1]), abs(b[2] - a[2]))
        if d > dl
            k = ceil(Int, d / dl)
            for j in 1:(k - 1)
                t = Float32(j / k)
                push!(out, Point2f(a[1] + t * (b[1] - a[1]), a[2] + t * (b[2] - a[2])))
            end
        end
    end
    push!(out, Point2f(pts[end]))
    return out
end

function _densify_poly(p::GeometryBasics.Polygon, dl::Real)
    ext = _densify_ring(GeometryBasics.coordinates(p.exterior), dl)
    isempty(p.interiors) && return Polygon(GeometryBasics.LineString(ext))
    holes = [GeometryBasics.LineString(_densify_ring(GeometryBasics.coordinates(h), dl)) for h in p.interiors]
    return Polygon(GeometryBasics.LineString(ext), holes)
end

"""
    split_polys_and_colors(polys, colors, lon0; close_at_poles=true, densify_dlat=1.0)

Apply `split_polygon` to each polygon in `polys`, expanding the
parallel `colors` vector so each split piece inherits its parent's
colour.  Returns `(new_polys, new_colors)`.

Every output piece is densified so no edge exceeds `densify_dlat` degrees
(`_densify_ring`).  This is essential: the bands come at the data-grid spacing,
and projecting their long straight edges per-vertex would leave thin white
seams between adjacent bands near the antimeridian.  Set `densify_dlat=Inf` to
disable.
"""
function split_polys_and_colors(
        polys::AbstractVector{<:GeometryBasics.Polygon},
        colors::AbstractVector,
        lon0::Real;
        close_at_poles::Bool = true,
        seam_dlat::Real = 1.0,
        densify_dlat::Real = 1.0,
    )
    new_polys = Polygon{2, Float32}[]
    new_colors = eltype(colors)[]
    for (poly, col) in zip(polys, colors)
        pieces = split_polygon(poly, lon0; close_at_poles, seam_dlat)
        for p in pieces
            push!(new_polys, isfinite(densify_dlat) ? _densify_poly(p, densify_dlat) : p)
            push!(new_colors, col)
        end
    end
    return (new_polys, new_colors)
end

# `true` if any consecutive (non-`NaN`) pair in the flat point list jumps
# more than 180° in longitude once normalised relative to `lon0`.  Used to
# short-circuit the (much more expensive) splitting pass.
function _flatlist_crosses(points::AbstractVector{<:GeometryBasics.Point2}, lon0::Real)
    prev_lon = NaN
    @inbounds for p in points
        if isnan(p[1]) || isnan(p[2])
            prev_lon = NaN
            continue
        end
        lon = _normalise_lon(p[1], lon0)
        if !isnan(prev_lon) && abs(lon - prev_lon) > 180.0
            return true
        end
        prev_lon = lon
    end
    return false
end

"""
    split_linestring_points(points, lon0)
    split_linestring_points(points, colors, lon0)

Split a flat point list (with `NaN`-separated segments, as used by
Makie's `contour` plot's `contour_points`/`masked_lines`) at the
antimeridian.  Each crossing is replaced with two boundary vertices and
a `NaN` separator to start a new line segment.

If a parallel per-vertex `colors` vector is supplied, it is co-split so
the returned colour vector stays the same length as the returned point
vector (the two inserted boundary vertices inherit the colours of the
edge endpoints, the `NaN` separator inherits the previous colour).
Returns `points` (one-arg) or `(points, colors)` (two-arg).

If nothing crosses, the longitudes are still normalised relative to
`lon0` so the line lies in `[lon0 - 180, lon0 + 180]`.
"""
function split_linestring_points(
        points::AbstractVector{<:GeometryBasics.Point2}, lon0::Real,
    )
    isempty(points) && return Vector{Point2f}()
    # Fast path: no crossing -> just normalise longitudes in place.
    if !_flatlist_crosses(points, lon0)
        return [(isnan(p[1]) || isnan(p[2])) ? Point2f(NaN, NaN) :
                Point2f(_normalise_lon(p[1], lon0), p[2]) for p in points]
    end
    out = Point2f[]
    sizehint!(out, length(points))
    prev_nan = true
    @inbounds for i in eachindex(points)
        p = points[i]
        if isnan(p[1]) || isnan(p[2])
            push!(out, Point2f(NaN, NaN))
            prev_nan = true
            continue
        end
        p_norm = Point2f(_normalise_lon(p[1], lon0), p[2])
        if prev_nan
            push!(out, p_norm)
            prev_nan = false
            continue
        end
        prev = out[end]
        dlon = p_norm[1] - prev[1]
        if abs(dlon) > 180.0
            sign_dir = dlon > 0 ? -1 : +1
            lat_cross = _crossing_latitude(prev[1], prev[2], p_norm[1], p_norm[2], lon0, sign_dir)
            # Nudge the inserted boundary vertices a hair (`SEAM_EPS`) inward,
            # toward `lon0`, so a vertex sitting exactly on the antimeridian
            # doesn't project ambiguously to either screen edge (same fix as
            # `_densify_seam_ring` applies to polygon seam vertices).
            exit_lon = lon0 + sign_dir * (180.0 - SEAM_EPS)
            entry_lon = lon0 - sign_dir * (180.0 - SEAM_EPS)
            push!(out, Point2f(exit_lon, lat_cross))
            push!(out, Point2f(NaN, NaN))
            push!(out, Point2f(entry_lon, lat_cross))
        end
        push!(out, p_norm)
    end
    return out
end

function split_linestring_points(
        points::AbstractVector{<:GeometryBasics.Point2},
        colors::AbstractVector, lon0::Real,
    )
    # If colours aren't a per-vertex vector (e.g. a scalar colour), nothing to
    # co-split: just split the geometry and pass the colour through untouched.
    if !(colors isa AbstractVector) || length(colors) != length(points)
        return (split_linestring_points(points, lon0), colors)
    end
    isempty(points) && return (Vector{Point2f}(), similar(colors, 0))
    # Fast path: no crossing.
    if !_flatlist_crosses(points, lon0)
        out = [(isnan(p[1]) || isnan(p[2])) ? Point2f(NaN, NaN) :
               Point2f(_normalise_lon(p[1], lon0), p[2]) for p in points]
        return (out, copy(colors))
    end
    out = Point2f[]
    cout = similar(colors, 0)
    sizehint!(out, length(points)); sizehint!(cout, length(points))
    prev_nan = true
    @inbounds for i in eachindex(points)
        p = points[i]
        col = colors[i]
        if isnan(p[1]) || isnan(p[2])
            push!(out, Point2f(NaN, NaN)); push!(cout, col)
            prev_nan = true
            continue
        end
        p_norm = Point2f(_normalise_lon(p[1], lon0), p[2])
        if prev_nan
            push!(out, p_norm); push!(cout, col)
            prev_nan = false
            continue
        end
        prev = out[end]
        prev_col = cout[end]
        dlon = p_norm[1] - prev[1]
        if abs(dlon) > 180.0
            sign_dir = dlon > 0 ? -1 : +1
            lat_cross = _crossing_latitude(prev[1], prev[2], p_norm[1], p_norm[2], lon0, sign_dir)
            # Nudge inserted boundary vertices inward by `SEAM_EPS` (see one-arg method).
            exit_lon = lon0 + sign_dir * (180.0 - SEAM_EPS)
            entry_lon = lon0 - sign_dir * (180.0 - SEAM_EPS)
            push!(out, Point2f(exit_lon, lat_cross)); push!(cout, prev_col)
            push!(out, Point2f(NaN, NaN)); push!(cout, prev_col)
            push!(out, Point2f(entry_lon, lat_cross)); push!(cout, col)
        end
        push!(out, p_norm); push!(cout, col)
    end
    return (out, cout)
end
