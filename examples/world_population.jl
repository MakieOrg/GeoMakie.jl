using Makie, CairoMakie, GeoMakie
using GeoJSON

source = "+proj=longlat +datum=WGS84"
dest = "+proj=natearth2"

fig = Figure()
ga = GeoAxis(
    fig[1, 1];
    source = source,
    dest = dest,
)

ga.xticklabelsvisible[] = false
ga.yticklabelsvisible[] = false

url = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"
land = download(url * "ne_110m_land.geojson")
land_geo = GeoJSON.read(read(land, String))
poly!(ga, land_geo, color=:black)

pop = download(url * "ne_10m_populated_places_simple.geojson")
pop_geo = GeoJSON.read(read(pop, String))
scatter!(ga, GeoMakie.geo2basic(pop_geo), color="lightgrey", markersize=1.2)

save("world_populations.png", fig; px_per_unit = 2)
