using GeoMakie, CairoMakie

# Limited-domain projections (like orthographic) must have
# their limits correctly set!
# If the limits are too large, you may get a blank figure.
lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

fig = Figure()
ga = GeoAxis(
    fig[1, 1],
    target_projection="+proj=ortho",
    title = "Orthographic projection with proper limits",
    limits = ((-90, 90), (-90, 90))  # have to specify proper limits here - TODO bring back autolimit finding!
)

# TODO: bring back coastlines, or create it as a recipe...
lp = lines!(ga, GeoMakie.coastlines())
translate!(lp, 0, 0, 10)
sp = surface!(ga, lons, lats, field; shading = false, colormap = :rainbow_bgyrm_35_85_c69_n256)
cb = Colorbar(fig[1, 2], sp)

fig
