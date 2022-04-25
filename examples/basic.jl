using GeoMakie, GLMakie

lons = -180:180
lats = -90:90
# Create some field of values across `lons` and `lats`
# This grid can be of any density, but note that the
# time it takes to plot scales with the grid size!
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

# Surface example
fig = Figure()
ax = GeoAxis(fig[1,1])
surface!(ax, lons, lats, field; shading = false)
save("surf_example.png", fig; px_per_unit=2)
display(fig)

# Scatter example
slons = rand(lons, 2000)
slats = rand(lats, 2000)
sfield = [exp(cosd(l)) + 3(y/90) for (l,y) in zip(slons, slats)]

fig = Figure()
ax = GeoAxis(fig[1,1])
scatter!(slons, slats; color = sfield)
save("scatter_example.png", fig; px_per_unit=2)
display(fig)

# Poly example - not working yet!
#
