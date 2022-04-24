using GeoMakie, CairoMakie, Makie
using NASAEarthObservations, FileIO, ImageIO

# Get and load data
obs = observations("blackmarble/2016/global/BlackMarble_2016_01deg_geo.tif")
img = rotr90(load(joinpath(obs, "BlackMarble_2016_01deg_geo.tif")))

lons = LinRange(-180, 180, size(img, 1)+1)
lats = LinRange(-90, 90,  size(img, 2)+1)

fig = Figure(resolution = (800, 400))
ga = GeoAxis(fig[1, 1]; dest = "+proj=wintri", title = "Earth at night")
hidedecorations!(ga) # hide ticks and ticklabels

imgplot = image!(lons, lats, img; interpolate = false)
# save at high resolution
save("blackmarble.png", fig; px_per_unit = 4)
