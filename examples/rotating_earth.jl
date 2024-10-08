# # Rotating Earth animation

using Makie, CairoMakie, GeoMakie

destnode = Observable("+proj=ortho")

fig = Figure()
ga = GeoAxis(
    fig[1, 1],
    dest = destnode,
)
surface!(ga, -180 .. 180, -90 .. 90, zeros(128, 128); color=rotr90(GeoMakie.earth()), interpolate = false, shading = NoShading)
xlims!(ga, -89, 89) # TODO: FIXME
fig

record(fig, "rotating_earth_ortho.mp4"; framerate=30) do io
    for lon in -90:0.5:90
        ga.title[] = string(lon) * "°"
        destnode[] = "+proj=ortho +lon_0=$lon"
        recordframe!(io)
    end
end
# ![](rotating_earth_ortho.mp4)
#
#=
```@cardmeta
Description = "Animating a rotating Earth"
```
=#
