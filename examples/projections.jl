using GeoMakie, CairoMakie, Makie

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y / 90) for l in lons, y in lats]

fig = Figure()
ax1 = GeoAxis(fig[1, 1], dest = "+proj=vitk1 +lat_1=45 +lat_2=55",
    coastlines = true, title = "vitk1")
ax2 = GeoAxis(fig[1, 2], dest = "+proj=wintri",
    coastlines = true, title = "wintri")

surface!(ax1, lons, lats, field; shading = false, colormap = (:plasma, 0.45))
surface!(ax2, lons, lats, field; shading = false)
hidedecorations!(ax1)
save("projections.png", fig; resolution = (900, 400), px_per_unit=3)
fig


# Limited-domain projections (like orthographic) must have
# their limits explicitly set for now.
# If the limits are too large, you may get a blank figure!
fig = Figure()
ga = GeoAxis(
    fig[1, 1],
    dest="+proj=ortho",
    limits = (-90,90,-90,90), # IMPORTANT - you MUST have proper limits!
    coastlines = true,
    title = "Orthographic projection with proper limits"
)
hidedecorations!(ga)
sp = surface!(ga, lons, lats, field; shading = false, colormap = (:plasma, 0.45))
cb = Colorbar(fig[1, 2], sp)
save("orthographic_with_limits.png", fig, px_per_unit=3)
fig
