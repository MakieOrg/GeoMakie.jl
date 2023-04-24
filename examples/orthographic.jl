using Makie, GeoMakie, CairoMakie

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

fig = Figure()
ga = GeoAxis(
    fig[1, 1],
    target_projection="+proj=ortho",
    title = "Orthographic projection with proper limits"
)
# hidedecorations!(ga)
lines!(ga, GeoMakie.coastlines())
sp = surface!(ga, lons, lats, field; shading = false, colormap = :rainbow_bgyrm_35_85_c69_n256)
cb = Colorbar(fig[1, 2], sp)

fig
