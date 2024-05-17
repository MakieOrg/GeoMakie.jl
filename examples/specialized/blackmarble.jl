# # NASA Black Marble

using GeoMakie, CairoMakie, Makie
CairoMakie.activate!(px_per_unit = 4) # hide

using Downloads

# Get and load data
file = Downloads.download("https://neo.sci.gsfc.nasa.gov/archive/blackmarble/2016/global/BlackMarble_2016_01deg_geo.tif")
img = rotr90(FileIO.load(file))

fig = Figure(size = (800, 400), backgroundcolor = :black)
ga = GeoAxis(fig[1, 1]; title = "Earth at night", titlecolor = :white, backgroundcolor = (:black, 0.0))
hidedecorations!(ga) # hide ticks and ticklabels

imgplot = image!(-180..180, -89.9..89.9, img; interpolate = false)

fig
# save at high resolution
# save("blackmarble.png", fig; px_per_unit = 2)
