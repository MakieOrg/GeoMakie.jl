# # Basic examples
using GeoMakie, CairoMakie # you could use GLMakie too

lons = -180:180
lats = -90:90
# Create some field of values across `lons` and `lats`
# This grid can be of any density, but note that the
# time it takes to plot scales with the grid size!
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

# Surface example
fig = Figure()
ax = GeoAxis(fig[1,1])
sp = surface!(ax, lons, lats, field; shading = NoShading)
fig


# To save your plot, run e.g. `save("surf_example.png", fig; px_per_unit=2)`.

# Each backend saves differently - GLMakie and WGLMakie save as images,
# but CairoMakie can be used to save PDFs and SVGs as well.

## Scatter example
slons = rand(lons, 2000)
slats = rand(lats, 2000)
sfield = [exp(cosd(l)) + 3(y/90) for (l,y) in zip(slons, slats)]

fig = Figure()
ax = GeoAxis(fig[1,1])
scatter!(slons, slats; color = sfield)
fig
# Again, to save, run e.g. `save("scatter_example.png", fig; px_per_unit=2)`.
#
# make cover image #jl
mkpath("covers") #hide
save("covers/$(splitext(basename(@__FILE__))[1]).png", fig) #hide
nothing #hide
