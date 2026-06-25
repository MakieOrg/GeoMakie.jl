#=
# Polar stereographic cap

A circular-boundary polar map (a stereographic, or other pole-centred azimuthal, projection
zoomed to a cap and clipped to a circle) is the natural way to view sea-ice, Antarctica, or a
tripolar-grid field near a pole. This reproduces cartopy's
[`always_circular_stereo`](https://cartopy.readthedocs.io/latest/gallery/lines_and_polygons/always_circular_stereo.html)
example using [`GeoPolarAxis`](@ref), which re-expresses a pole-centred azimuthal projection on a
Makie `PolarAxis` (`θ = lon`, `r = radial(lat)`) to get the circular clip, the polar graticule
(parallels as r-rings, meridians as θ-spokes) and the circular spine for free.
=#
using GeoMakie, CairoMakie
CairoMakie.activate!(type = :png, px_per_unit = 2) # hide

#=
## A south-polar cap with coastlines

Pass the cap latitude as `latcap`; its sign picks the pole (negative selects the south pole). The
disk is clipped at the cap, leaving the corners empty, for cartopy's `always_circular_stereo` look.
Plot with the usual verbs (`poly!`, `lines!`, `scatter!`, …) using geographic `(lon, lat)` data.
=#

fig = Figure(size = (500, 500))
gpa = GeoPolarAxis(fig[1, 1]; latcap = -65, title = "South polar stereographic")
poly!(gpa, GeoMakie.land(); color = (:gray70, 0.55), strokecolor = :black, strokewidth = 0.4)
fig

#=
## A smooth field on a cap

To plot a field, sample it on a `(lon, lat)` grid and use `contourf!` (clean vector output) or
`surface!`/`heatmap!` (drawn as a pcolormesh, i.e. raster, so prefer PNG). A field defined on the
sphere must be single-valued at the pole (every longitude at `lat = ±90` is the same point),
so build it as a function of the Cartesian point `(x, y, z)` rather than directly in `(lon, lat)`.
=#

## a C∞ field on the sphere: a smooth function of (x, y, z), sampled at (lon, lat)
xyz(lon, lat) = (cosd(lat) * cosd(lon), cosd(lat) * sind(lon), sind(lat))
function field(lon, lat)
    x, y, z = xyz(lon, lat)
    f = 0.3z
    for (clon, clat, a) in ((0.0, 72.0, 1.0), (130.0, 60.0, 0.8), (-110.0, 66.0, 0.9))
        cx, cy, cz = xyz(clon, clat)
        f += a * exp(-6 * ((x - cx)^2 + (y - cy)^2 + (z - cz)^2))
    end
    return f
end
lons = -180:4:180; lats = 50:2:90
zs = [field(lo, la) for lo in lons, la in lats]

#=
Use a non-default azimuthal projection (here Lambert azimuthal equal-area) via the `dest` keyword.
Below, the field is drawn with `contourf!` (vector) on the left and `surface!` (raster pcolormesh)
on the right, with coastlines overlaid and a shared `Colorbar`.
=#

caps = Figure(size = (840, 460))
gpa = GeoPolarAxis(caps[1, 1]; latcap = 50,
    dest = "+proj=laea +lat_0=90 +lon_0=0", title = "Lambert azimuthal (contourf)")
contourf!(gpa, lons, lats, zs; levels = 12)
lines!(gpa, GeoMakie.coastlines(); color = (:black, 0.6), linewidth = 0.4)

gpb = GeoPolarAxis(caps[1, 2]; latcap = 50, title = "Stereographic (surface)")
sf = surface!(gpb, lons, lats, zs)
lines!(gpb, GeoMakie.coastlines(); color = (:black, 0.6), linewidth = 0.4)
Colorbar(caps[1, 3], sf)
caps
