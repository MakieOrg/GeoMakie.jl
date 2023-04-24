using Makie, GeoMakie, CairoMakie

lons = -180:180
lats = -90:90
# Create some field of values across `lons` and `lats`
# This grid can be of any density, but note that the
# time it takes to plot scales with the grid size!
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

# Surface example
fig = Figure()
ax = GeoAxis(fig[1,1])
contourf!(ax, lons, lats, field; shading = false)
fig
