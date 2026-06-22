#=
# `GeoPolarAxis` — polar (pole-centred azimuthal) maps on a Makie `PolarAxis`

This reproduces cartopy's `always_circular_stereo` example: a polar map whose boundary is a
**circle** (a cap at a chosen latitude) with everything outside the circle clipped, plus a polar
graticule (parallels as r-rings, meridians as θ-spokes).

A pole-centred azimuthal projection IS a polar plot: `project(lon, lat) → (x, y)` with
`θ = atan2(y, x)`, `r = hypot(x, y)`. We therefore re-express the chosen PROJ azimuthal projection
in polar coordinates and let Makie's `PolarAxis` supply the circular clip, the polar grid and the
circular spine for free (`rlimits` clips to the cap circle).

`GeoPolarAxis` is a thin wrapper around a `PolarAxis` plus the projection. The geographic plotting
verbs (`lines!`, `scatter!`, `poly!`, `surface!`, `heatmap!`, `contourf!`) are overloaded on it:
they take geographic (lon, lat) inputs, map them to `(θ, r)` and forward to the wrapped axis.

## The atan2 branch cut

`θ = atan2(y, x)` is discontinuous across one meridian (where it flips ±π). This is harmless for
**lines** (a `PolarAxis` transforms each vertex to Cartesian and draws straight segments between
them, so a step from θ≈π to θ≈−π is a short, correct segment) but **fatal for fills**, which
triangulate in `(θ, r)` space: a triangle spanning the branch cut warps across the whole disk.

The fix for every filled artist (`poly!`, `surface!`, `heatmap!`, `contourf!`) is to build the
triangle mesh in **projected `(x, y)`** space — where the azimuthal projection is continuous and
there is no seam — and only then remap the mesh vertices to `(θ, r)`. The round-trip
`(x, y) → (θ, r) → (x, y)` is exact, so the `PolarAxis` recovers the original projected triangles.
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
- grid styling (`rgridcolor`, `thetagridcolor`, `rgridwidth`, `thetagridwidth`, `spinecolor`,
  `spinewidth`): default to GeoMakie's `GeoAxis` graticule (faint black @ 12%, opaque spine), not
  `PolarAxis`'s much darker defaults.
- any further keyword is forwarded to the underlying `PolarAxis` (`title`, `theta_0`, `direction`, …).

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

# (lon, lat)° -> (θ [rad], r) via the azimuthal projector
@inline function _polar_θr(t::Proj.Transformation, lon, lat)
    xy = t(Float64(lon), Float64(lat))
    return Point2{Float64}(atan(xy[2], xy[1]), hypot(xy[1], xy[2]))
end

# projected metres (x, y) -> (θ [rad], r)
@inline _xy_to_θr(p) = Point2f(atan(Float64(p[2]), Float64(p[1])), hypot(Float64(p[1]), Float64(p[2])))

# radius of the parallel `lat` — for a pole-centred azimuthal projection r depends only on latitude
_polar_radius(t::Proj.Transformation, lat) = (xy = t(0.0, Float64(lat)); hypot(xy[1], xy[2]))

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

    lt = latticks === automatic ? _default_latticks(latcap, pole) : latticks
    rvals = Float64[_polar_radius(t, l) for l in lt]
    rlabels = String[_lat_label(l) for l in lt]

    lons = lonticks === automatic ? collect(-180.0:45.0:135.0) : collect(Float64, lonticks)
    latref = (latcap + pole) / 2
    θvals = Float64[_polar_θr(t, lo, latref)[1] for lo in lons]
    θlabels = String[_lon_label(lo) for lo in lons]

    ax = Makie.PolarAxis(figpos;
        rlimits = (0.0, rcap),
        rticks = (rvals, rlabels),
        thetaticks = (θvals, θlabels),
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
# filled artists: build the mesh in projected (x, y), then remap vertices to (θ, r)
#-----------------------------------------------------------------------------------------------

@inline _proj_xy(t, p) = (xy = t(Float64(p[1]), Float64(p[2])); Point2f(xy[1], xy[2]))
_ring_finite(ring) = all(p -> isfinite(p[1]) && isfinite(p[2]), ring)

# The cap as a sphere-space small-circle clip about the pole (colatitude = 90 − |latcap|). Used to
# trim filled geometry to the disk *before* triangulating, so far-away land/bands aren't meshed only
# to be clipped by `rlimits` (and a pole-enclosing polygon like Antarctica still fills to r = 0).
function _cap_clip(gpa::GeoPolarAxis)
    pole = gpa.latcap ≥ 0 ? 90.0 : -90.0
    return CircleClip(0.0, pole, 90.0 - abs(gpa.latcap))
end

# Cap-clip + resample polygonal geographic `geom`; return (lon/lat polygons, group) where `group[i]`
# is the index of the input polygon piece `i` came from (so per-polygon colours map to pieces).
function _cap_split(gpa::GeoPolarAxis, geom; winding::Symbol = :spherical)
    clip = _cap_clip(gpa)
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

# Triangulate a single lon/lat polygon in projected (x, y) space; return (θr_vertices, faces) or
# `nothing` if the polygon projects to a non-finite/degenerate shape.
function _polar_fill_mesh(t, poly)
    extxy = Point2f[_proj_xy(t, p) for p in GeometryBasics.coordinates(poly.exterior)]
    (_ring_finite(extxy) && length(extxy) ≥ 3) || return nothing
    holesxy = Vector{Point2f}[]
    for h in poly.interiors
        hxy = Point2f[_proj_xy(t, p) for p in GeometryBasics.coordinates(h)]
        _ring_finite(hxy) && length(hxy) ≥ 3 && push!(holesxy, hxy)
    end
    pxy = isempty(holesxy) ? GeometryBasics.Polygon(extxy) : GeometryBasics.Polygon(extxy, holesxy)
    local m
    try
        m = GeometryBasics.triangle_mesh(pxy)
    catch
        return nothing
    end
    (m === nothing || isempty(GeometryBasics.faces(m))) && return nothing
    θr = Point2f[_xy_to_θr(v) for v in GeometryBasics.coordinates(m)]
    return (θr, GeometryBasics.faces(m))
end

# Merge per-polygon (θr, faces) meshes into one mesh, replicating each polygon's colour onto its
# vertices (when `colors` is per-polygon) so a single `mesh!` call carries the colormap.
function _merge_fill_meshes(meshes, colors)
    verts = Point2f[]
    faces = GeometryBasics.GLTriangleFace[]
    vcols = colors === nothing ? nothing : eltype(colors)[]
    off = 0
    for (i, mesh) in enumerate(meshes)
        mesh === nothing && continue
        θr, fcs = mesh
        append!(verts, θr)
        for f in fcs
            push!(faces, GeometryBasics.GLTriangleFace(f[1] + off, f[2] + off, f[3] + off))
        end
        vcols === nothing || append!(vcols, fill(colors[i], length(θr)))
        off += length(θr)
    end
    return GeometryBasics.Mesh(verts, faces), vcols
end

# Stroke (polygon outlines) as (θ, r) lines, one NaN-separated path over all rings.
function _polar_stroke_points(t, polys)
    out = Point2f[]
    for poly in polys
        for ring in (poly.exterior, poly.interiors...)
            isempty(out) || push!(out, Point2f(NaN, NaN))
            for p in GeometryBasics.coordinates(ring)
                push!(out, Point2f(_polar_θr(t, p[1], p[2])))
            end
        end
    end
    return out
end

function Makie.poly!(gpa::GeoPolarAxis, geom;
        color = :gray70, colormap = :viridis, colorrange = Makie.automatic,
        strokecolor = :black, strokewidth = 0, kwargs...)
    polys, group = _cap_split(gpa, geom)
    meshes = [_polar_fill_mesh(gpa.transform, p) for p in polys]
    pervertex = color isa AbstractVector && length(color) == maximum(group; init = 0)
    perpoly = pervertex ? color[group] : nothing
    merged, vcols = _merge_fill_meshes(meshes, perpoly)
    plt = Makie.mesh!(gpa.axis, merged;
        color = vcols === nothing ? color : vcols,
        colormap, colorrange, shading = Makie.NoShading, kwargs...)
    if strokewidth > 0
        Makie.lines!(gpa.axis, _polar_stroke_points(gpa.transform,
            [p for (p, m) in zip(polys, meshes) if m !== nothing]);
            color = strokecolor, linewidth = strokewidth)
    end
    return plt
end

#-----------------------------------------------------------------------------------------------
# fields: surface! / heatmap! reuse the GeoAxis grid mesher, then remap to (θ, r)
#-----------------------------------------------------------------------------------------------

# Remap a projected-(x,y) mesh (from `_geo_grid_mesh`) to (θ, r).
function _remap_mesh_θr(mesh)
    θr = Point2f[_xy_to_θr(v) for v in GeometryBasics.coordinates(mesh)]
    return GeometryBasics.Mesh(θr, GeometryBasics.faces(mesh))
end

function _polar_grid!(gpa::GeoPolarAxis, xs, ys, vals;
        colormap = :viridis, colorrange = Makie.automatic, nan_color = :transparent, kwargs...)
    mesh, cols = _geo_grid_mesh(gpa.dest, gpa.source, xs, ys, vals)
    return Makie.mesh!(gpa.axis, _remap_mesh_θr(mesh);
        color = cols, colormap, colorrange, nan_color, shading = Makie.NoShading, kwargs...)
end

function Makie.surface!(gpa::GeoPolarAxis, xs, ys, zs; color = nothing, kwargs...)
    vals = color isa AbstractMatrix ? _resample_to_grid(color, size(zs, 1), size(zs, 2)) : zs
    return _polar_grid!(gpa, xs, ys, vals; kwargs...)
end

Makie.heatmap!(gpa::GeoPolarAxis, xs, ys, zs; kwargs...) = _polar_grid!(gpa, xs, ys, zs; kwargs...)

#-----------------------------------------------------------------------------------------------
# contourf!: harvest the filled bands (lon/lat), then mesh-fill in projected (x, y)
#-----------------------------------------------------------------------------------------------

function Makie.contourf!(gpa::GeoPolarAxis, xs, ys, zs; kwargs...)
    # realise a throwaway contourf on a detached scene to harvest the band polygons + colours
    probe = Makie.contourf!(Makie.Scene(), xs, ys, zs; kwargs...)
    bands = probe.polys[]
    bandcols = probe.computed_colors[]
    clip = _cap_clip(gpa)
    project = _projector(gpa.transform)
    scale = resample_scale(project)
    # cap-clip + resample each band (contourf bands use planar winding), then mesh-fill in (x, y)
    meshes = Any[]
    colors = eltype(bandcols)[]
    for (band, col) in zip(bands, bandcols)
        for piece in _split_polygon(clip, _poly_rings(band), project, scale; winding = :planar)
            m = _polar_fill_mesh(gpa.transform, piece)
            m === nothing && continue
            push!(meshes, m); push!(colors, col)
        end
    end
    merged, vcols = _merge_fill_meshes(meshes, colors)
    return Makie.mesh!(gpa.axis, merged;
        color = vcols,
        colormap = probe.computed_colormap[],
        colorrange = probe.computed_colorrange[],
        shading = Makie.NoShading)
end

# also accept the (zs,) form, mirroring Makie's contourf
Makie.contourf!(gpa::GeoPolarAxis, zs::AbstractMatrix; kwargs...) =
    Makie.contourf!(gpa, axes(zs, 1), axes(zs, 2), zs; kwargs...)
