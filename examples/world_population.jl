# This example was contributed by Martijn Visser (@visr)
using Makie, CairoMakie, GeoMakie
using GeoMakie.GeoJSON
using GeometryBasics
using Downloads

source = "+proj=longlat +datum=WGS84"
dest = "+proj=natearth2"

fig = Figure(resolution = (1000,500))
ga = GeoAxis(
    fig[1, 1];
    source = source,
    dest = dest,
)

ga.xticklabelsvisible[] = false
ga.yticklabelsvisible[] = false

url = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"
land = Downloads.download(url * "ne_110m_land.geojson")
land_geo = GeoJSON.read(read(land, String))
land_geo = GeoMakie.geoJSONtraitParse.(GeoInterface.geometry.(land_geo))
poly!(ga, land_geo, color=:black)

pop = Downloads.download(url * "ne_10m_populated_places_simple.geojson")
pop_geo = GeoJSON.read(read(pop, String))
pop_geo = GeoMakie.geoJSONtraitParse.(GeoInterface.geometry.(pop_geo))
scatter!(ga, pop_geo, color="lightgrey", markersize=1.2)

fig