#=
# Rotating Earth animation

This example shows how to animate a rotating Earth, by 
using a `GeoAxis` and changing the `dest` attribute,
which specifies the destination projection.

```@cardmeta
Description = "Animating a rotating Earth"
Cover = fig
```
=#
using Makie, CairoMakie, GeoMakie
# First, we'll create an observable that will hold the destination projection.
# This can be passed to `GeoAxis`.  You can also mutate `geoaxis.dest` directly,
# but it can sometimes be more convenient to set up your observables ahead of time,
# for readability.
destnode = Observable("+proj=ortho")

fig = Figure()
ga = GeoAxis(
    fig[1, 1],
    dest = destnode,
)
surface!(ga, -180 .. 180, -90 .. 90, zeros(128, 128); color=rotr90(GeoMakie.earth()), interpolate = false, shading = NoShading)
xlims!(ga, -89, 89) # TODO: FIXME
fig
# Now that the figure is set up, we can record an animation.
record(fig, "rotating_earth_ortho.mp4"; framerate=30) do io
    for lon in -90:0.5:90
        ga.title[] = string(lon) * "°"
        destnode[] = "+proj=ortho +lon_0=$lon"
        recordframe!(io)
    end
end
# ![](./rotating_earth_ortho.mp4)
#

