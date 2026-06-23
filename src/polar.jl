#=
# `GeoPolarAxis` — polar (pole-centred azimuthal) maps on a Makie `PolarAxis`

This reproduces cartopy's `always_circular_stereo` example: a polar map whose boundary is a
**circle** (a cap at a chosen latitude) with everything outside the circle clipped, plus a polar
graticule (parallels as r-rings, meridians as θ-spokes).

A pole-centred azimuthal projection is **separable** in polar coordinates:

  - `θ = lon`            — a pure rotation (the display orientation is set with `theta_0`/`direction`)
  - `r = radial(lat)`    — the projection's radial law, `hypot(project(lon₀, lat))`

so we map `(lon, lat) → (θ, r)` directly and let Makie's `PolarAxis` supply the circular clip
(`rlimits`), the polar grid and the circular spine for free.

Because `θ = lon`, the only discontinuity is the **antimeridian** (`lon = ±180`) — a constant-
longitude graticule line, exactly where GeoMakie's `AntimeridianClip` already tears (with a
pole-walk for pole-enclosing land like Antarctica). After that split every polygon is simple in
`(θ, r)`, so filled artists go through Makie's ordinary `poly!`/`contourf!` (which triangulate in
`(θ, r)`) and render as clean vector paths — no bespoke mesh, no rasterised-mesh artifacts.

The antimeridian split produces two pieces that abut along `lon = ±180`; on the disk `θ = +π` and
`θ = −π` are the *same* radial direction, so the **fill** is seamless (the cut is zero-width). The
**stroke** would still draw that seam edge as a radial line to the pole, so `_polar_stroke_points`
skips antimeridian-aligned edges, visually seaming the pieces back together.

`GeoPolarAxis` is a thin wrapper around a `PolarAxis` plus the projection. The geographic plotting
verbs (`lines!`, `scatter!`, `poly!`, `surface!`, `heatmap!`, `contourf!`) are overloaded on it:
they take geographic `(lon, lat)` inputs, map them to `(θ, r)` and forward to the wrapped axis.
=#

const _POLAR_SOURCE = "+proj=longlat +datum=WGS84"

"""
    GeoPolarAxis(figure_position; latcap, dest, kwargs...) -> GeoPolarAxis

A polar map on a Makie `PolarAxis`, for **pole-centred azimuthal**
projections (`stere`, `aeqd`, `laea`, `gnom`, …). The map is a disk clipped to the cap latitude
`latcap`, with a circular spine and a polar graticule (parallels as r-rings, meridians as
θ-spokes) — cartopy's `always_circular_stereo` look.

Plot onto it with the usual verbs, passing **geographic** `(lon, lat)` data:
`lines!`, `scatter!`, `poly!`, `surface!`, `heatmap!`, `contourf!`.

# Keywords
- `latcap` (required): the cap (boundary) latitude in degrees. Its sign selects the pole: `latcap ≥ 0`
  is a north-polar cap (`lat ∈ [latcap, 90]`), `latcap < 0` a south-polar cap (`lat ∈ [-90, latcap]`).
- `dest`: the destination PROJ string. Defaults to a polar stereographic at the matching pole.
  Use this for `laea`/`aeqd`/`gnom` or a rotated `lon_0`. Must be a pole-centred azimuthal projection.
- `latticks` / `lonticks`: latitudes (parallels, r-rings) and longitudes (meridians, θ-spokes) to
  label. `automatic` picks sensible defaults from the cap.
- `direction` / `theta_0`: the `PolarAxis` orientation. `automatic` derives them from the projection
  so the layout matches the true azimuthal projection (0°-meridian at the bottom for a north cap, at
  the top for a south cap); override to taste.
- grid styling (`rgridcolor`, `thetagridcolor`, `rgridwidth`, `thetagridwidth`, `spinecolor`,
  `spinewidth`): default to GeoMakie's `GeoAxis` graticule (faint black @ 12%, opaque spine), not
  `PolarAxis`'s much darker defaults.
- any further keyword is forwarded to the underlying `PolarAxis` (`title`, …).

The wrapped axis is available as `gpa.axis`.
"""
struct GeoPolarAxis
    axis::Makie.PolarAxis
    dest::String
    source::String
    transform::Proj.Transformation   # source (lon/lat) -> dest (azimuthal)
    latcap::Float64
end

Makie.get_scene(gpa::GeoPolarAxis) = Makie.get_scene(gpa.axis)

# radius of the parallel `lat` — for a pole-centred azimuthal projection r depends only on latitude
_polar_radius(t::Proj.Transformation, lat) = (xy = t(0.0, Float64(lat)); hypot(xy[1], xy[2]))

# (lon, lat)° -> (θ = lon [rad], r). `r = hypot(project(lon, lat))` is the exact azimuthal radial
# law (independent of lon); `θ` comes straight from the longitude — no atan2, no branch cut.
@inline function _polar_θr(t::Proj.Transformation, lon, lat)
    xy = t(Float64(lon), Float64(lat))
    return Point2{Float64}(deg2rad(Float64(lon)), hypot(xy[1], xy[2]))
end

# Derive `(direction, theta_0)` from the projector so the polar layout matches the true azimuthal
# projection: the projected bearing of a meridian, `α(lon) = atan2(project(lon, latref))`, is affine
# in lon — `α = direction·deg2rad(lon) + theta_0` — and PolarAxis applies exactly that to `θ = lon`.
function _polar_orientation(t::Proj.Transformation, latref)
    α(lon) = (xy = t(Float64(lon), Float64(latref)); atan(xy[2], xy[1]))
    α0 = α(0.0)
    direction = _wrapλ(α(1.0) - α0) ≥ 0 ? 1 : -1
    return direction, α0
end

# default parallels to label: nice round latitudes strictly between the cap and the pole
function _default_latticks(latcap, pole)
    lo, hi = minmax(latcap, pole)
    ticks = Makie.get_tickvalues(Makie.LinearTicks(5), lo, hi)
    return filter(l -> abs(l) < 90 && l != latcap, ticks)
end

_lat_label(l) = string(round(Int, l), "°", l ≥ 0 ? "N" : "S")
function _lon_label(l)
    l = mod(l + 180, 360) - 180
    l == 0 && return "0°"
    abs(l) == 180 && return "180°"
    return string(round(Int, abs(l)), "°", l > 0 ? "E" : "W")
end

function GeoPolarAxis(figpos;
        latcap,
        dest = "+proj=stere +lat_0=$(latcap ≥ 0 ? 90 : -90) +lon_0=0",
        source = _POLAR_SOURCE,
        latticks = automatic,
        lonticks = automatic,
        direction = automatic,
        theta_0 = automatic,
        rgridcolor = RGBAf(0, 0, 0, 0.12),
        thetagridcolor = RGBAf(0, 0, 0, 0.12),
        rgridwidth = 1.0,
        thetagridwidth = 1.0,
        spinecolor = RGBAf(0, 0, 0, 1),
        spinewidth = 1.0,
        kwargs...)
    t = create_transform(dest, source)
    pole = latcap ≥ 0 ? 90.0 : -90.0
    rcap = _polar_radius(t, latcap)

    dir, th0 = _polar_orientation(t, (latcap + pole) / 2)
    direction === automatic && (direction = dir)
    theta_0 === automatic && (theta_0 = th0)

    lt = latticks === automatic ? _default_latticks(latcap, pole) : latticks
    rvals = Float64[_polar_radius(t, l) for l in lt]
    rlabels = String[_lat_label(l) for l in lt]

    lons = lonticks === automatic ? collect(-180.0:45.0:135.0) : collect(Float64, lonticks)
    θvals = Float64[deg2rad(lo) for lo in lons]
    θlabels = String[_lon_label(lo) for lo in lons]

    ax = Makie.PolarAxis(figpos;
        rlimits = (0.0, rcap),
        rticks = (rvals, rlabels),
        thetaticks = (θvals, θlabels),
        direction, theta_0,
        rgridcolor, thetagridcolor, rgridwidth, thetagridwidth,
        spinecolor, spinewidth,
        kwargs...)

    return GeoPolarAxis(ax, String(dest), String(source), t, Float64(latcap))
end

#-----------------------------------------------------------------------------------------------
# input normalisation
#-----------------------------------------------------------------------------------------------

# Normalise line/point geographic input to a NaN-separated Vector{Point2d} of (lon, lat).
_lonlat_points(geom) = Point2d[Point2d(p[1], p[2]) for p in Makie.convert_arguments(Makie.PointBased(), geom)[1]]
_lonlat_points(lons::AbstractVector{<:Real}, lats::AbstractVector{<:Real}) = Point2d[Point2d(lo, la) for (lo, la) in zip(lons, lats)]

#-----------------------------------------------------------------------------------------------
# lines! / scatter!
#-----------------------------------------------------------------------------------------------

# map NaN-separated lon/lat points to (θ, r), preserving NaN breaks
function _polar_map_line(t, pts)
    out = Vector{Point2f}(undef, length(pts))
    @inbounds for i in eachindex(pts)
        p = pts[i]
        out[i] = (isnan(p[1]) || isnan(p[2])) ? Point2f(NaN, NaN) : Point2f(_polar_θr(t, p[1], p[2]))
    end
    return out
end

function Makie.lines!(gpa::GeoPolarAxis, args...; kwargs...)
    pts = _lonlat_points(args...)
    res = split_resample_line(pts, gpa.transform)        # antipode-clip + adaptive resample (lon/lat)
    return Makie.lines!(gpa.axis, _polar_map_line(gpa.transform, res); kwargs...)
end

function Makie.scatter!(gpa::GeoPolarAxis, args...; kwargs...)
    pts = _lonlat_points(args...)
    return Makie.scatter!(gpa.axis, _polar_map_line(gpa.transform, pts); kwargs...)
end

#-----------------------------------------------------------------------------------------------
# filled polygons: antimeridian-split (so each piece is simple in (θ, r)) then ordinary poly!
#-----------------------------------------------------------------------------------------------

# Split polygonal geographic `geom` at the antimeridian (lon = ±180 — the only seam once θ = lon),
# with a pole-walk for pole-enclosing land. Returns (lon/lat polygons, group) where `group[i]` is the
# index of the input polygon piece `i` came from (so per-polygon colours map onto the pieces).
function _anti_split(gpa::GeoPolarAxis, geom; winding::Symbol = :spherical)
    clip = AntimeridianClip(0.0)
    project = _projector(gpa.transform)
    scale = resample_scale(project)
    polys = GeometryBasics.Polygon{2, Float32}[]
    group = Int[]
    for (k, p) in enumerate(_collect_polys(geom))
        pieces = _split_polygon(clip, _poly_rings(p), project, scale; winding = winding)
        append!(polys, pieces)
        append!(group, fill(k, length(pieces)))
    end
    return polys, group
end

# map a lon/lat polygon (with holes) to a (θ, r) polygon
function _polar_polygon(t, poly)
    ext = Point2f[Point2f(_polar_θr(t, q[1], q[2])) for q in GeometryBasics.coordinates(poly.exterior)]
    isempty(poly.interiors) && return GeometryBasics.Polygon(ext)
    holes = [Point2f[Point2f(_polar_θr(t, q[1], q[2])) for q in GeometryBasics.coordinates(h)] for h in poly.interiors]
    return GeometryBasics.Polygon(ext, holes)
end

# Stroke (polygon outlines) as (θ, r) lines, one NaN-separated path over all rings. Edges that run
# along the antimeridian (lon = ±180) are NOT stroked: they are the artificial seam the antimeridian
# split inserts (the pole-walk for Antarctica, the cut for dateline-spanning land), and would draw a
# radial line to the pole / across the disk. Breaking there seams the split pieces back together,
# since lon = +180 and lon = −180 are the same radial direction. The fill already closes seamlessly.
_on_antimeridian(p) = abs(p[1]) > 179.5
function _polar_stroke_points(t, polys)
    out = Point2f[]
    for poly in polys
        for ring in (poly.exterior, poly.interiors...)
            cs = GeometryBasics.coordinates(ring)
            (isempty(out) || isnan(out[end][1])) || push!(out, Point2f(NaN, NaN))
            for i in eachindex(cs)
                p = cs[i]
                if i > 1 && _on_antimeridian(cs[i - 1]) && _on_antimeridian(p) && !isnan(out[end][1])
                    push!(out, Point2f(NaN, NaN))       # don't stroke the antimeridian seam edge
                end
                push!(out, Point2f(_polar_θr(t, p[1], p[2])))
            end
        end
    end
    return out
end

function Makie.poly!(gpa::GeoPolarAxis, geom;
        color = :gray70, colormap = :viridis, colorrange = Makie.automatic,
        strokecolor = :black, strokewidth = 0, kwargs...)
    polys, group = _anti_split(gpa, geom)
    θrpolys = [_polar_polygon(gpa.transform, p) for p in polys]
    pervertex = color isa AbstractVector && length(color) == maximum(group; init = 0)
    col = pervertex ? color[group] : color
    # fill via ordinary poly! (clean vector); stroke separately so the antimeridian seam is skipped
    plt = Makie.poly!(gpa.axis, θrpolys; color = col, colormap, colorrange, strokewidth = 0, kwargs...)
    strokewidth > 0 && Makie.lines!(gpa.axis, _polar_stroke_points(gpa.transform, polys);
        color = strokecolor, linewidth = strokewidth)
    return plt
end

#-----------------------------------------------------------------------------------------------
# fields
#-----------------------------------------------------------------------------------------------

# `contourf!` is vector-clean: it builds filled-band polygons, which (with θ = lon) are simple in
# (θ, r), so the native PolarAxis recipe draws them as paths. Just map the grid coordinates.
_polar_θ(lons) = Float64[deg2rad(Float64(lo)) for lo in lons]
_polar_r(t, lats) = Float64[_polar_radius(t, la) for la in lats]

Makie.contourf!(gpa::GeoPolarAxis, xs, ys, zs; kwargs...) =
    Makie.contourf!(gpa.axis, _polar_θ(xs), _polar_r(gpa.transform, ys), zs; kwargs...)

# `surface!`/`heatmap!` are *raster* fields. A pixel field can't follow a nonlinear (polar) axis as
# an image — `heatmap!`'s native path smears — so we draw it as a pcolormesh: a (θ, r) vertex grid
# with the data as per-vertex colour, warped per-vertex by the PolarAxis transform. (Same reason
# GeoAxis meshes its grids.) This rasterises in vector backends — that is inherent to raster data;
# use `contourf!` for a vector field. Heatmap cell EDGES (n+1) are collapsed to centres to match z.
function _polar_field_mesh!(gpa::GeoPolarAxis, xs, ys, vals;
        colormap = :viridis, colorrange = Makie.automatic, nan_color = :transparent, kwargs...)
    nx, ny = size(vals)
    xs = length(xs) == nx + 1 ? [(xs[i] + xs[i + 1]) / 2 for i in 1:nx] : xs
    ys = length(ys) == ny + 1 ? [(ys[j] + ys[j + 1]) / 2 for j in 1:ny] : ys
    θ = Float64[deg2rad(Float64(x)) for x in xs]
    r = Float64[_polar_radius(gpa.transform, y) for y in ys]
    verts = Vector{Point2f}(undef, nx * ny)
    cols = similar(vals, nx * ny)
    for (k, ci) in enumerate(CartesianIndices((nx, ny)))
        verts[k] = Point2f(θ[ci[1]], r[ci[2]])
        cols[k] = vals[ci]
    end
    faces = GeometryBasics.decompose(Makie.GLTriangleFace, GeometryBasics.Tesselation(Rect2f(0, 0, 1, 1), (nx, ny)))
    return Makie.mesh!(gpa.axis, GeometryBasics.Mesh(verts, faces);
        color = vec(cols), colormap, colorrange, nan_color, shading = Makie.NoShading, kwargs...)
end

function Makie.surface!(gpa::GeoPolarAxis, xs, ys, zs; color = nothing, kwargs...)
    vals = color isa AbstractMatrix ? _resample_to_grid(color, size(zs, 1), size(zs, 2)) : zs
    return _polar_field_mesh!(gpa, xs, ys, vals; kwargs...)
end

Makie.heatmap!(gpa::GeoPolarAxis, xs, ys, zs; kwargs...) = _polar_field_mesh!(gpa, xs, ys, zs; kwargs...)

# also accept the (zs,) form, mirroring Makie's field verbs
Makie.surface!(gpa::GeoPolarAxis, zs::AbstractMatrix; kwargs...) = Makie.surface!(gpa, axes(zs, 1), axes(zs, 2), zs; kwargs...)
Makie.heatmap!(gpa::GeoPolarAxis, zs::AbstractMatrix; kwargs...) = Makie.heatmap!(gpa, axes(zs, 1), axes(zs, 2), zs; kwargs...)
Makie.contourf!(gpa::GeoPolarAxis, zs::AbstractMatrix; kwargs...) = Makie.contourf!(gpa, axes(zs, 1), axes(zs, 2), zs; kwargs...)
