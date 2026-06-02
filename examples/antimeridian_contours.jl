# # Contours across the antimeridian
#
# `contour` and `contourf` compute their geometry in lon/lat space, after
# which the `GeoAxis` applies the projection to every vertex.  When a contour
# crosses the *antimeridian* of the destination projection — the meridian at
# `lon_0 ± 180` — an edge whose endpoints sit on opposite sides of the globe
# gets projected into a horizontal smear across the whole map.
#
# GeoMakie fixes this automatically: on a `GeoAxis`, the filled bands and the
# contour lines are split at the antimeridian (in lon/lat space) *before* the
# projection is applied.  Nothing special is needed — just use `contourf!` /
# `contour!` as usual.  This also handles **curvilinear** grids (2-D `x`/`y`
# coordinate matrices), such as the tripolar ocean grids in
# [Makie.jl#4885](https://github.com/MakieOrg/Makie.jl/issues/4885).

using GeoMakie, CairoMakie

# ## Rectilinear grid on a seam-crossing projection
#
# A simple lon/lat field.  We pick projections whose central meridian is *not*
# at 0°, so the contours visibly cross the antimeridian.
lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y / 90) for l in lons, y in lats]

fig = Figure(size = (1000, 800))

ax1 = GeoAxis(fig[1, 1]; dest = "+proj=longlat +lon_0=180", title = "contourf, lon₀ = 180°")
contourf!(ax1, lons, lats, field)

ax2 = GeoAxis(fig[1, 2]; dest = "+proj=longlat +lon_0=-150", title = "contour, lon₀ = -150°")
contour!(ax2, lons, lats, field)
fig

# ## Curvilinear grid that curves across the antimeridian
#
# Here the longitude coordinate is skewed by latitude, so the coordinate lines
# themselves bend across ±180°.  Both `x` and `y` are matrices.
nx, ny = 60, 40
LON = [l + 35 * sind(y) for l in range(-150, 150, nx), y in range(-80, 80, ny)]
LAT = [Float64(y) for l in range(-150, 150, nx), y in range(-80, 80, ny)]
Z = [cosd(l) + sind(2y) for l in range(-150, 150, nx), y in range(-80, 80, ny)]

ax3 = GeoAxis(fig[2, 1]; dest = "+proj=moll +lon_0=150", title = "curvilinear contourf")
contourf!(ax3, LON, LAT, Z)
fig

# ## Pole-enclosing bands
#
# Contour bands that wrap a pole are closed along the pole rather than across
# the seam.
plons = -180:5:180
plats = 55:2:90
pfield = [y + 8 * cosd(l) for l in plons, y in plats]

ax4 = GeoAxis(fig[2, 2]; dest = "+proj=longlat +lon_0=180", title = "pole-enclosing bands")
contourf!(ax4, plons, plats, pfield; levels = 8)
fig

# ## Closing the periodic-grid seam with `add_cyclic_point`
#
# Antimeridian splitting handles contours that cross the *projection's* seam,
# but it cannot invent data the grid doesn't have.  Many global grids store each
# longitude only once (e.g. `0:10:350`), so there is no cell bridging the last
# column back to the first, and `contourf` leaves a thin gap along that periodic
# boundary.  [`add_cyclic_point`](@ref) appends a wrapped copy of the first
# column (longitude + 360°), closing the seam — analogous to cartopy's
# [`add_cyclic_point`](https://cartopy.readthedocs.io/stable/gallery/scalar_data/wrapping_global.html).
clons = 0:10:350                              # note: 360° is *not* present
clats = -90:5:90
cfield = [sind(2l) * cosd(y) for l in clons, y in clats]

fig2 = Figure(size = (1000, 380))
ax_a = GeoAxis(fig2[1, 1]; dest = "+proj=moll +lon_0=0", title = "without cyclic point")
contourf!(ax_a, clons, clats, cfield)
ax_b = GeoAxis(fig2[1, 2]; dest = "+proj=moll +lon_0=0", title = "with add_cyclic_point")
lon_c, field_c = add_cyclic_point(clons, cfield)
contourf!(ax_b, lon_c, clats, field_c)
fig2

#=
```@cardmeta
Title = "Contours across the antimeridian"
Description = "Antimeridian-aware contour and contourf, including curvilinear grids"
Cover = fig
```
=#
