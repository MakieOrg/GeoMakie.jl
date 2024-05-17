# # Projections

using GeoMakie, CairoMakie
CairoMakie.activate!(px_per_unit = 4) # hide

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y / 90) for l in lons, y in lats]

fig = Figure()
ax1 = GeoAxis(fig[1, 1], dest = "+proj=vitk1 +lat_1=45 +lat_2=55",title = "vitk1", xgridcolor=:red)
ax2 = GeoAxis(fig[1, 2]; dest="+proj=wintri", title = "wintri")

surface!(ax1, lons, lats, field; shading = NoShading, colormap = (:plasma, 0.45))
surface!(ax2, lons, lats, field; shading = NoShading, colormap = (:plasma, 0.45))

fig
