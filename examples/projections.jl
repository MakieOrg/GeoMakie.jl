using GeoMakie, CairoMakie, Makie

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y / 90) for l in lons, y in lats]

fig = Figure()
ax1 = GeoAxis(fig[1, 1], target_projection = "+proj=vitk1 +lat_1=45 +lat_2=55",
    coastlines = true, title = "vitk1")
ax2 = GeoAxis(fig[1, 2], target_projection = "+proj=wintri",
    coastlines = true, title = "wintri")

surface!(ax1, lons, lats, field; shading = false, colormap = (:plasma, 0.45))
surface!(ax2, lons, lats, field; shading = false)
hidedecorations!(ax1)

fig
