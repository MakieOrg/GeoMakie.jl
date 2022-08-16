using CairoMakie, GeoMakie
using GeoMakie.GeoJSON
using Downloads
using GeometryBasics
using GeoInterface

# Acquire data
it_states = Downloads.download("https://github.com/openpolis/geojson-italy/raw/master/geojson/limits_IT_provinces.geojson")
geo = GeoJSON.read(read(it_states, String))
basic = GeoMakie.geoJSONtraitParse.(GeoInterface.geometry.(geo))

fig = Figure()
ga = GeoAxis(fig[1, 1]; dest = "+proj=ortho +lon_0=12.5 +lat_0=42", lonlims=(12, 13), latlims = (40, 44))
plot!.(ga, basic; strokecolor = :blue, strokewidth = 1, color = (:blue, 0.5), shading = false);
datalims!(ga)

fig
