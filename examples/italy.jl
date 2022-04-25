using CairoMakie, GeoMakie
using GeoJSON

# Acquire data
states = download("https://github.com/openpolis/geojson-italy/raw/master/geojson/limits_IT_provinces.geojson")
geo = GeoJSON.read(read(states, String))
basic = GeoMakie.geo2basic(geo)

fig = Figure()
ga = GeoAxis(fig[1, 1]; dest = "+proj=ortho +lon_0=12.5 +lat_0=42")
plot!.(ga, basic; strokecolor = :blue, strokewidth = 1, color = (:blue, 0.5), shading = false)
datalims!(ga)

fig
