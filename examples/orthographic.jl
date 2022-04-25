
# Limited-domain projections (like orthographic) must have
# their limits correctly set!
# If the limits are too large, you may get a blank figure.
fig = Figure()
ga = GeoAxis(
    fig[1, 1],
    dest="+proj=ortho",
    lonlims = Makie.automatic,
    coastlines = true,
    title = "Orthographic projection with proper limits"
)
hidedecorations!(ga)
sp = surface!(ga, lons, lats, field; shading = false, colormap = :rainbow_bgyrm_35_85_c69_n256)
cb = Colorbar(fig[1, 2], sp)

fig
