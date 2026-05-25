############################################################
#                                                          #
#         Antimeridian splitting of filled polygons        #
#                                                          #
############################################################
#
# Polygon-cutting primitives used by the `Contourf`/`Contour`
# overrides on a `GeoAxis`.  When a contour crosses the antimeridian
# of the destination projection (the meridian at `lon_0 ± 180`), the
# polygon ring contains an edge whose two endpoints sit on opposite
# sides of the globe; after per-vertex projection that edge draws a
# horizontal smear across the canvas.
#
# The algorithm walks each ring once (O(N)) and splits crossing edges
# into pairs of antimeridian-boundary vertices, producing sub-rings
# that each lie entirely within `[lon_0 - 180, lon_0 + 180]`.  Holes
# are split independently and re-assigned to the new exterior pieces
# by a point-in-polygon test.
#
# Why hand-rolled rather than `GeometryOps.intersection`: the clip is
# always against a single vertical line and we need *both* halves.  A
# single-pass ring walker is much faster than the general
# Foster-Hormann clipper and stays in `Float32`/`Point2f` end-to-end.

# `PolygonOps` is reached through Makie, which already imports it.
const _PolyOps = Makie.PolygonOps

"""
    parse_lon0(s)

Pull the `+lon_0=<value>` argument out of a PROJ string.  Returns
`0.0` if not present.
"""
function parse_lon0(s::AbstractString)
    m = match(r"\+lon_0=([-+]?\d+(?:\.\d+)?)", s)
    return m === nothing ? 0.0 : parse(Float64, m.captures[1])
end

@inline _normalise_lon(lon::Real, lon0::Real) = lon0 + mod(lon - lon0 + 180.0, 360.0) - 180.0

"""
    crosses_antimeridian(ring, lon0)

`true` if any consecutive pair of vertices in `ring` (treated as
cyclic) has `|Δlon| > 180`, assuming longitudes are already normalised
into `[lon0 - 180, lon0 + 180)`.
"""
function crosses_antimeridian(ring::AbstractVector{<:GeometryBasics.Point2}, lon0::Real)
    n = length(ring)
    n < 2 && return false
    @inbounds for i in 1:n
        j = i == n ? 1 : i + 1
        if abs(ring[j][1] - ring[i][1]) > 180.0
            return true
        end
    end
    return false
end

function normalised_ring(ring::AbstractVector{<:GeometryBasics.Point2}, lon0::Real)
    out = Vector{Point2f}(undef, length(ring))
    @inbounds for i in eachindex(ring)
        p = ring[i]
        out[i] = Point2f(_normalise_lon(p[1], lon0), p[2])
    end
    return out
end

# Linearly interpolate latitude at the crossing of the antimeridian.
# `sign_dir` is +1 if the short path from `a` to `b` goes west
# (through `lon0 - 180`) and -1 if it goes east (through `lon0 + 180`).
@inline function _crossing_latitude(lon_a, lat_a, lon_b, lat_b, lon0, sign_dir)
    lon_b_shifted = lon_b + sign_dir * 360.0
    t = (lon0 + sign_dir * 180.0 - lon_a) / (lon_b_shifted - lon_a)
    return lat_a + t * (lat_b - lat_a)
end

"""
    split_ring(ring, lon0; close_at_poles=true)

Split a closed ring at the antimeridian `lon0 ± 180`.  Returns a
vector of sub-rings, each a `Vector{Point2f}`.  If the ring does not
cross, returns `[normalised_ring(ring, lon0)]`.

If `close_at_poles=true` and the ring is detected to enclose a pole
(net signed Δlon ≈ ±360°), the sub-rings are closed along the pole
rather than along the antimeridian.
"""
function split_ring(
        ring::AbstractVector{<:GeometryBasics.Point2}, lon0::Real;
        close_at_poles::Bool = true,
    )
    n = length(ring)
    n < 3 && return Vector{Vector{Point2f}}()

    norm = normalised_ring(ring, lon0)

    if !crosses_antimeridian(norm, lon0)
        return [norm]
    end

    # Pole detection via net signed Δlon (short path).
    net = 0.0
    @inbounds for i in 1:n
        j = i == n ? 1 : i + 1
        d = norm[j][1] - norm[i][1]
        d -= 360.0 * round(d / 360.0)
        net += d
    end
    encloses_pole = close_at_poles && abs(abs(net) - 360.0) < 1.0

    subrings = Vector{Vector{Point2f}}()
    current = Point2f[norm[1]]
    first_entry_sign::Int = 0   # 0 means current sub-ring started mid-piece

    @inbounds for i in 1:(n - 1)
        p_a = norm[i]
        p_b = norm[i + 1]
        dlon = p_b[1] - p_a[1]
        if abs(dlon) <= 180.0
            push!(current, p_b)
        else
            # short path goes the other way: sign_dir = -1 if dlon>0 (east-going long path)
            sign_dir = dlon > 0 ? -1 : +1
            lat_cross = _crossing_latitude(p_a[1], p_a[2], p_b[1], p_b[2], lon0, sign_dir)
            exit_lon = lon0 + sign_dir * 180.0
            entry_lon = lon0 - sign_dir * 180.0
            push!(current, Point2f(exit_lon, lat_cross))
            push!(subrings, current)
            current = Point2f[Point2f(entry_lon, lat_cross), p_b]
        end
    end

    # Closing edge n -> 1
    @inbounds begin
        p_a = norm[n]
        p_b = norm[1]
        dlon = p_b[1] - p_a[1]
        if abs(dlon) > 180.0
            sign_dir = dlon > 0 ? -1 : +1
            lat_cross = _crossing_latitude(p_a[1], p_a[2], p_b[1], p_b[2], lon0, sign_dir)
            exit_lon = lon0 + sign_dir * 180.0
            entry_lon = lon0 - sign_dir * 180.0
            push!(current, Point2f(exit_lon, lat_cross))
            push!(subrings, current)
            first_entry_sign = -sign_dir  # the first sub-ring's open end
            current = Point2f[]
        end
    end

    if !isempty(current)
        push!(subrings, current)
    end

    # If the ring started mid-piece (closing edge didn't cross), the
    # first and last sub-rings are halves of the same piece.  Merge.
    if length(subrings) >= 2 && first_entry_sign == 0
        tail = pop!(subrings)
        prepend!(subrings[1], tail)
    end

    # Close each sub-ring.
    out = Vector{Vector{Point2f}}()
    for sr in subrings
        length(sr) < 3 && continue
        if sr[1] != sr[end]
            push!(sr, sr[1])
        end
        push!(out, sr)
    end

    if encloses_pole
        out = _close_subrings_along_pole(out, lon0, net > 0 ? 90.0 : -90.0)
    end

    return out
end

# For pole-enclosing rings: detour each sub-ring through the pole so
# the closed ring's projected drawing wraps the pole correctly.
function _close_subrings_along_pole(
        subrings::Vector{Vector{Point2f}}, lon0::Real, pole_lat::Real,
    )
    out = Vector{Vector{Point2f}}()
    on_am(p) = abs(p[1] - (lon0 - 180.0)) < 1e-6 || abs(p[1] - (lon0 + 180.0)) < 1e-6
    for sr in subrings
        length(sr) < 3 && continue
        if length(sr) >= 2 && on_am(sr[1]) && on_am(sr[end - 1])
            new = Point2f[]
            append!(new, sr[1:(end - 1)])
            push!(new, Point2f(sr[end - 1][1], pole_lat))
            push!(new, Point2f(sr[1][1], pole_lat))
            push!(new, sr[1])
            push!(out, new)
        else
            push!(out, sr)
        end
    end
    return out
end

"""
    split_polygon(poly, lon0; close_at_poles=true)

Split a `GeometryBasics.Polygon` (with optional holes) at the
antimeridian.  Returns `Vector{Polygon{2, Float32}}` — one polygon per
piece of the split exterior, each carrying the holes that lie within
it.  If the polygon doesn't cross, returns the polygon (longitudes
normalised) in a one-element vector.
"""
function split_polygon(
        poly::GeometryBasics.Polygon, lon0::Real;
        close_at_poles::Bool = true,
    )
    exterior_pts = GeometryBasics.coordinates(poly.exterior)
    ext_split = split_ring(exterior_pts, lon0; close_at_poles)

    interior_splits = Vector{Vector{Vector{Point2f}}}()
    for hole in poly.interiors
        hole_pts = GeometryBasics.coordinates(hole)
        push!(interior_splits, split_ring(hole_pts, lon0; close_at_poles))
    end

    # Fast path: nothing crossed.
    if length(ext_split) == 1 && all(length(h) == 1 for h in interior_splits)
        ext = ext_split[1]
        holes_ls = [GeometryBasics.LineString(h[1]) for h in interior_splits]
        return [Polygon(GeometryBasics.LineString(ext), holes_ls)]
    end

    polys = Polygon{2, Float32}[]
    for ext in ext_split
        assigned_holes = Vector{Vector{Point2f}}()
        for hole_pieces in interior_splits
            for hp in hole_pieces
                rep = (hp[1] + hp[min(2, length(hp))]) / 2
                if _PolyOps.inpolygon(rep, ext) != 0
                    push!(assigned_holes, hp)
                end
            end
        end
        holes_ls = [GeometryBasics.LineString(h) for h in assigned_holes]
        push!(polys, Polygon(GeometryBasics.LineString(ext), holes_ls))
    end
    return polys
end

"""
    split_polys_and_colors(polys, colors, lon0; close_at_poles=true)

Apply `split_polygon` to each polygon in `polys`, expanding the
parallel `colors` vector so each split piece inherits its parent's
colour.  Returns `(new_polys, new_colors)`.
"""
function split_polys_and_colors(
        polys::AbstractVector{<:GeometryBasics.Polygon},
        colors::AbstractVector,
        lon0::Real;
        close_at_poles::Bool = true,
    )
    new_polys = Polygon{2, Float32}[]
    new_colors = eltype(colors)[]
    for (poly, col) in zip(polys, colors)
        pieces = split_polygon(poly, lon0; close_at_poles)
        for p in pieces
            push!(new_polys, p)
            push!(new_colors, col)
        end
    end
    return (new_polys, new_colors)
end

"""
    split_linestring_points(points, lon0)

Split a flat point list (with `NaN`-separated segments, as used by
Makie's `contour` plot's `contour_points`) at the antimeridian.  Each
crossing is replaced with two boundary vertices and a `NaN` separator
to start a new line segment.
"""
function split_linestring_points(
        points::AbstractVector{<:GeometryBasics.Point2}, lon0::Real,
    )
    isempty(points) && return Vector{Point2f}()
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
            exit_lon = lon0 + sign_dir * 180.0
            entry_lon = lon0 - sign_dir * 180.0
            push!(out, Point2f(exit_lon, lat_cross))
            push!(out, Point2f(NaN, NaN))
            push!(out, Point2f(entry_lon, lat_cross))
        end
        push!(out, p_norm)
    end
    return out
end
