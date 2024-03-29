# # Rotating Earth animation

using Makie, CairoMakie, GeoMakie
CairoMakie.activate!(px_per_unit = 4) # hide

destnode = Observable("+proj=ortho")

fig = Figure()
ga = GeoAxis(
    fig[1, 1],
    dest = destnode,
)
surface!(ga, -180 .. 180, -90 .. 90, zeros(128, 128); color=rotr90(GeoMakie.earth()), interpolate = false)
fig

record(fig, "rotating_earth_ortho.mp4"; framerate=30) do io
    for lon in -90:0.5:90
        ga.title[] = string(lon) * "°"
        destnode[] = "+proj=ortho +lon_0=$lon"
        recordframe!(io)
    end
end
# ![](rotating_earth_ortho.mp4)
