# # Orthographic projection

using GeoMakie, CairoMakie
CairoMakie.activate!(px_per_unit = 4) # hide

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

fig = Figure()
ga = GeoAxis(
    fig[1, 1],
    dest="+proj=ortho",
    title = "Orthographic projection",
    xticklabelcolor=:red, xgridcolor=:red,
)
lp = lines!(ga, GeoMakie.coastlines(); transformation = (; translation = (0, 0, 1)))
sp = surface!(ga, lons, lats, zeros(size(field)); color=field, shading = NoShading, colormap=:rainbow_bgyrm_35_85_c69_n256)
cb = Colorbar(fig[1, 2], sp)
fig
#
# make cover image #jl
mkpath("covers") #hide
save("covers/$(splitext(basename(@__FILE__))[1]).png", fig) #hide
nothing #hide
