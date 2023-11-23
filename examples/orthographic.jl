using GeoMakie, CairoMakie

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

fig = Figure()
ga = GeoAxis(
    fig[1, 1],
    dest="+proj=ortho",
    title = "Orthographic projection"
)
# hidedecorations!(ga)
lines!(ga, GeoMakie.coastlines(); transformation = (; translation = (0, 0, 1)))
sp = surface!(ga, lons, lats, zeros(size(field)); color=field, shading = NoShading, colormap=:rainbow_bgyrm_35_85_c69_n256)
cb = Colorbar(fig[1, 2], sp)

fig
