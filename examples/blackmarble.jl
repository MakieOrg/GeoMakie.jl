using GeoMakie, CairoMakie, Makie
using NASAEarthObservations, FileIO, ImageIO

# Get and load data
obs = observations("blackmarble/2016/global/BlackMarble_2016_01deg_geo.tif")
img = rotr90(load(joinpath(obs, "BlackMarble_2016_01deg_geo.tif")))

fig = Figure(resolution = (800, 400), backgroundcolor = :black)
ga = GeoAxis(fig[1, 1]; title = "Earth at night", titlecolor = :white, backgroundcolor = (:black, 0.0))
hidedecorations!(ga) # hide ticks and ticklabels

imgplot = image!(-180..180, -89.9..89.9, img; interpolate = false)
# save at high resolution
save("blackmarble.png", fig; px_per_unit = 2)
