# # Orthographic projection

using GeoMakie, CairoMakie

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
sp = surface!(ga, lons, lats, zeros(size(field)); color=field, shading = NoShading, colormap=:rainbow_bgyrm_35_85_c69_n256)
cb = Colorbar(fig[1, 2], sp)
fig
# We can also draw some coastlines here, and make sure they're always above the surface:
lp = lines!(
    ga, GeoMakie.coastlines(); 
    transformation = (; translation = (0, 0, 50))
)
fig
# Note the `transformation` keyword argument.
# Another syntax to do this post facto is by using the `translate!` function:
translate!(lp, (0, 0, -51))
fig
# Whoa!  It vanished!
translate!(lp, (0, 0, 50))
fig
# And it's back!  Note that `translate!` sets the _absolute_ translation.
# If you want to translate relatively, use `translate!(Accum, ...)` instead.
#
# make cover image #jl
mkpath("covers") #hide
save("covers/$(splitext(basename(@__FILE__))[1]).png", fig) #hide
nothing #hide
