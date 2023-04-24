using Makie, GeoMakie, CairoMakie

# Limited-domain projections (like orthographic) must have
# their limits correctly set!
# If the limits are too large, you may get a blank figure.
lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

fig = Figure()
ga = GeoAxis(
    fig[1, 1],
    dest="+proj=ortho",
    lonlims = automatic,
    coastlines = true,
    title = "Orthographic projection with proper limits"
)
# hidedecorations!(ga)
sp = surface!(ga, lons, lats, field; shading = false, colormap = :rainbow_bgyrm_35_85_c69_n256)
cb = Colorbar(fig[1, 2], sp)

fig
