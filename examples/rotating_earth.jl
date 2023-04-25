using Makie, CairoMakie, GeoMakie

destnode = Observable("+proj=ortho")

fig = Figure()
ga = GeoAxis(
    fig[1, 1],
    target_projection = destnode,
)
image!(-180..180, -90..90, rotr90(GeoMakie.earth()); interpolate = false)
## hidedecorations!(ga)

record(fig, "rotating_earth_ortho.mp4"; framerate=30) do io
    for lon in -90:0.5:90
        ga.title[] = string(lon) * "°"
        destnode[] = "+proj=ortho +lon_0=$lon"
        xlims!(ga, lon-90, lon+90)
        recordframe!(io)
    end
end
# ![](rotating_earth_ortho.mp4)