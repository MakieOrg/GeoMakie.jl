#=
# `GeoPolarAxis`: polar (pole-centred azimuthal) maps on a Makie `PolarAxis`

This reproduces cartopy's `always_circular_stereo` example: a polar map whose boundary is a
**circle** (a cap at a chosen latitude) with everything outside the circle clipped, plus a polar
graticule (parallels as r-rings, meridians as θ-spokes).

A pole-centred azimuthal projection is **separable** in polar coordinates:

  - `θ = lon`            (a pure rotation; the display orientation is set with `theta_0`/`direction`)
  - `r = radial(lat)`    (the projection's radial law, `hypot(project(lon₀, lat))`)

so we map `(lon, lat) → (θ, r)` directly and let Makie's `PolarAxis` supply the circular clip
(`rlimits`), the polar grid and the circular spine for free.

Because `θ = lon`, the only discontinuity is the **antimeridian** (`lon = ±180`): a constant-
longitude graticule line, exactly where GeoMakie's `AntimeridianClip` already tears (with a
pole-walk for pole-enclosing land like Antarctica). After that split every polygon is simple in
`(θ, r)`, so filled artists go through Makie's ordinary `poly!`/`contourf!` (which triangulate in
`(θ, r)`) and render as clean vector paths: no bespoke mesh, no rasterised-mesh artifacts.

The antimeridian split produces two pieces that abut along `lon = ±180`; on the disk `θ = +π` and
`θ = −π` are the *same* radial direction, so the **fill** is seamless (the cut is zero-width). The
**stroke** would still draw that seam edge as a radial line to the pole, so `_polar_stroke_points`
skips antimeridian-aligned edges, visually seaming the pieces back together.

`GeoPolarAxis` is a Makie `@Block` (a sibling of `GeoAxis`, both `<: Makie.AbstractAxis`) that wraps
a `PolarAxis` plus the projection: it uses `@forwarded_layout` to own a `PolarAxis` that fills its
cell, so it places, sizes and registers (as the current axis) like any other Makie axis. The
geographic plotting verbs (`lines!`, `scatter!`, `poly!`, `surface!`, `heatmap!`, `contourf!`) are
overloaded on it: they take geographic `(lon, lat)` inputs, map them to `(θ, r)` and forward to the
wrapped `PolarAxis`.
=#

"""
    GeoPolarAxis(figure_position; latcap, dest, kwargs...) -> GeoPolarAxis

A polar map `@Block` (sibling of [`GeoAxis`](@ref)) backed by a Makie `PolarAxis`, for
**pole-centred azimuthal** projections (`stere`, `aeqd`, `laea`, `gnom`, …). The map is a disk
clipped to the cap latitude `latcap`, with a circular spine and a polar graticule (parallels as
r-rings, meridians as θ-spokes), the cartopy `always_circular_stereo` look.

Plot onto it with the usual verbs, passing **geographic** `(lon, lat)` data:
`lines!`, `scatter!`, `poly!`, `surface!`, `heatmap!`, `contourf!`.

# Attributes
- `latcap`: the cap (boundary) latitude in degrees (default `60`). Its sign selects the pole:
  `latcap ≥ 0` is a north-polar cap (`lat ∈ [latcap, 90]`), `latcap < 0` a south-polar cap
  (`lat ∈ [-90, latcap]`).
- `dest`: the destination PROJ string. `automatic` → a polar stereographic at the matching pole.
  Use this for `laea`/`aeqd`/`gnom` or a rotated `lon_0`. Must be a pole-centred azimuthal projection.
- `latticks` / `lonticks`: latitudes (parallels, r-rings) and longitudes (meridians, θ-spokes) to
  label. `automatic` picks sensible defaults from the cap.
- `direction` / `theta_0`: the `PolarAxis` orientation. `automatic` derives them from the projection
  so the layout matches the true azimuthal projection (0°-meridian at the bottom for a north cap, at
  the top for a south cap); override to taste.
- grid styling (`rgridcolor`, `thetagridcolor`, `rgridwidth`, `thetagridwidth`, `spinecolor`,
  `spinewidth`): default to GeoMakie's `GeoAxis` graticule (faint black @ 12%, opaque spine), not
  `PolarAxis`'s much darker defaults.
- `title`, `titlesize`, `titlefont`, `titlegap`, `titlecolor`, `titlealign`, `titlevisible`:
  forwarded to the wrapped `PolarAxis`.

Because this is a Block, only declared attributes are accepted as keywords; for any other `PolarAxis`
setting, reach the wrapped axis via `gpa.axis`.
"""
Makie.@Block GeoPolarAxis <: Makie.AbstractAxis begin
    @forwarded_layout                  # a GridLayout this block forwards its size/protrusions to
    axis::Makie.PolarAxis              # the wrapped PolarAxis, created to fill `layout[1, 1]`
    transform::Proj.Transformation     # source (lon/lat) -> dest (azimuthal)
    @attributes begin
        # Layout (standard Block layout attributes; required by `@forwarded_layout`)
        "The horizontal alignment of the block in its suggested bounding box."
        halign = :center
        "The vertical alignment of the block in its suggested bounding box."
        valign = :center
        "The width setting of the block."
        width = Makie.Auto()
        "The height setting of the block."
        height = Makie.Auto()
        "Controls if the parent layout can adjust to this block's width."
        tellwidth::Bool = true
        "Controls if the parent layout can adjust to this block's height."
        tellheight::Bool = true
        "The align mode of the block in its parent GridLayout."
        alignmode = Makie.Inside()

        # Geographic projection
        "The cap (boundary) latitude in degrees; its sign selects the pole (`≥ 0` north, `< 0` south)."
        latcap = 60.0
        "Destination PROJ string (a pole-centred azimuthal projection). `automatic` → polar stereographic at the matching pole."
        dest = automatic
        "Source PROJ string for the incoming `(lon, lat)` data."
        source = "+proj=longlat +datum=WGS84"
        "Latitudes to label as r-rings (parallels). `automatic` picks defaults from the cap."
        latticks = automatic
        "Longitudes to label as θ-spokes (meridians). `automatic` labels every 45°."
        lonticks = automatic
        "PolarAxis θ direction (`+1`/`-1`). `automatic` derives it from the projection."
        direction = automatic
        "PolarAxis θ offset. `automatic` derives it from the projection."
        theta_0 = automatic

        # Graticule + spine styling (GeoAxis-like faint graticule, not PolarAxis's darker default)
        "Colour of the r-grid (parallels)."
        rgridcolor = RGBAf(0, 0, 0, 0.12)
        "Colour of the θ-grid (meridians)."
        thetagridcolor = RGBAf(0, 0, 0, 0.12)
        "Width of the r-grid lines."
        rgridwidth = 1.0
        "Width of the θ-grid lines."
        thetagridwidth = 1.0
        "Colour of the circular spine."
        spinecolor = RGBAf(0, 0, 0, 1)
        "Width of the circular spine."
        spinewidth = 1.0

        # Title (forwarded to the wrapped PolarAxis; defaults match PolarAxis so appearance is unchanged)
        "The axis title string."
        title = ""
        "The title's font size."
        titlesize::Float64 = @inherit(:fontsize, 16.0f0)
        "The font family of the title."
        titlefont = :bold
        "The gap between axis and title."
        titlegap::Float64 = 4.0
        "The color of the title."
        titlecolor::RGBAf = @inherit(:textcolor, :black)
        "The horizontal alignment of the title."
        titlealign::Symbol = :center
        "Controls if the title is visible."
        titlevisible::Bool = true
    end
end

Makie.get_scene(gpa::GeoPolarAxis) = Makie.get_scene(gpa.axis)

# GeoPolarAxis owns no limits of its own; the wrapped PolarAxis does. Forward the pre-display state
# update (which would otherwise hit `reset_limits!`/`gpa.limits` on the generic AbstractAxis path).
Makie.update_state_before_display!(gpa::GeoPolarAxis) = Makie.update_state_before_display!(gpa.axis)

# radius of the parallel `lat`: for a pole-centred azimuthal projection r depends only on latitude
_polar_radius(t::Proj.Transformation, lat) = (xy = t(0.0, Float64(lat)); hypot(xy[1], xy[2]))

# (lon, lat)° -> (θ = lon [rad], r). `r = hypot(project(lon, lat))` is the exact azimuthal radial
# law (independent of lon); `θ` comes straight from the longitude: no atan2, no branch cut.
@inline function _polar_θr(t::Proj.Transformation, lon, lat)
    xy = t(Float64(lon), Float64(lat))
    return Point2{Float64}(deg2rad(Float64(lon)), hypot(xy[1], xy[2]))
end

# Derive `(direction, theta_0)` from the projector so the polar layout matches the true azimuthal
# projection. The projected bearing of a meridian, `α(lon) = atan2(project(lon, latref))`, is affine
# in lon with unit slope: `α(lon) = α0 + direction·deg2rad(lon)`. Makie's `Polar` transform places θ
# at screen angle `direction·(θ + theta_0)` (the offset is applied *inside* the direction flip), so
# with `θ = deg2rad(lon)` matching `α` requires `direction·(deg2rad(lon) + theta_0) = α(lon)`, i.e.
# `theta_0 = direction·α0` (for a north cap `direction=+1` so this is just `α0`; for a south cap
# `direction=-1` the offset must be negated, else the disk is rotated 180°).
function _polar_orientation(t::Proj.Transformation, latref)
    α(lon) = (xy = t(Float64(lon), Float64(latref)); atan(xy[2], xy[1]))
    α0 = α(0.0)
    direction = _wrapλ(α(1.0) - α0) ≥ 0 ? 1 : -1
    return direction, direction * α0
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

# Build the wrapped PolarAxis from the attributes. The geographic quantities (transform, cap radius,
# orientation, ticks) are resolved once here from the cap/projection; the resolved `dest`/`source`
# strings are written back into their attributes so `gpa.dest[]` reads the actual PROJ string.
function Makie.initialize_block!(gpa::GeoPolarAxis)
    latcap = Float64(gpa.latcap[])
    pole = latcap ≥ 0 ? 90.0 : -90.0

    dest = gpa.dest[] === automatic ?
        "+proj=stere +lat_0=$(latcap ≥ 0 ? 90 : -90) +lon_0=0" : String(gpa.dest[])
    source = String(gpa.source[])
    gpa.dest[] = dest
    gpa.source[] = source

    t = create_transform(dest, source)
    gpa.transform = t
    rcap = _polar_radius(t, latcap)

    dir, th0 = _polar_orientation(t, (latcap + pole) / 2)
    direction = gpa.direction[] === automatic ? dir : gpa.direction[]
    theta_0 = gpa.theta_0[] === automatic ? th0 : gpa.theta_0[]

    lt = gpa.latticks[] === automatic ? _default_latticks(latcap, pole) : gpa.latticks[]
    rvals = Float64[_polar_radius(t, l) for l in lt]
    rlabels = String[_lat_label(l) for l in lt]

    lons = gpa.lonticks[] === automatic ? collect(-180.0:45.0:135.0) : collect(Float64, gpa.lonticks[])
    θvals = Float64[deg2rad(lo) for lo in lons]
    θlabels = String[_lon_label(lo) for lo in lons]

    gpa.axis = Makie.PolarAxis(gpa.layout[1, 1];
        rlimits = (0.0, rcap),
        rticks = (rvals, rlabels),
        thetaticks = (θvals, θlabels),
        direction = direction,
        theta_0 = theta_0,
        rgridcolor = gpa.rgridcolor[],
        thetagridcolor = gpa.thetagridcolor[],
        rgridwidth = gpa.rgridwidth[],
        thetagridwidth = gpa.thetagridwidth[],
        spinecolor = gpa.spinecolor[],
        spinewidth = gpa.spinewidth[],
        title = gpa.title[],
        titlesize = gpa.titlesize[],
        titlefont = gpa.titlefont[],
        titlegap = gpa.titlegap[],
        titlecolor = gpa.titlecolor[],
        titlealign = gpa.titlealign[],
        titlevisible = gpa.titlevisible[])

    return gpa
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

# Split polygonal geographic `geom` at the antimeridian (lon = ±180, the only seam once θ = lon),
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
# an image (`heatmap!`'s native path smears), so we draw it as a pcolormesh: a (θ, r) vertex grid
# with the data as per-vertex colour, warped per-vertex by the PolarAxis transform. (Same reason
# GeoAxis meshes its grids.) This rasterises in vector backends; that is inherent to raster data;
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
