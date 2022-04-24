using GeoMakie, CairoMakie, Makie
using NASAEarthObservations, FileIO, ImageIO

# Get and load data
obs = observations("blackmarble/2016/global/BlackMarble_2016_01deg_geo.tif")
img = rotr90(load(joinpath(obs, "BlackMarble_2016_01deg_geo.tif")))

lons = LinRange(-180, 180, size(img, 1)+1)
lats = LinRange(-90+0.1, 90-0.1,  size(img, 2)+1)

fig = Figure(resolution = (800, 400), backgroundcolor = :black)
ga = GeoAxis(fig[1, 1]; title = "Earth at night", titlecolor = :white, backgroundcolor = (:black, 0.0))
hidedecorations!(ga) # hide ticks and ticklabels

imgplot = image!(lons, lats, img; interpolate = false)
# save at high resolution
save("blackmarble.png", fig; px_per_unit = 4)
