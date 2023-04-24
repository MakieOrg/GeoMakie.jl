# This example was contributed by Martijn Visser (@visr)
using Makie, CairoMakie, GeoMakie
using GeoMakie.GeoJSON
using GeometryBasics
using Downloads

source = "+proj=longlat +datum=WGS84"
dest = "+proj=natearth2"

url = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"
land = Downloads.download(url * "ne_110m_land.geojson")
land_geo = GeoJSON.read(read(land, String))
pop = Downloads.download(url * "ne_10m_populated_places_simple.geojson")
pop_geo = GeoJSON.read(read(pop, String))

begin
    fig = Figure(resolution = (1000,500))
    ga = GeoAxis(
        fig[1, 1];
        source_projection = source,
        target_projection = dest
    )

    ga.xticklabelsvisible[] = false
    ga.yticklabelsvisible[] = false
    poly!(ga, land_geo, color=:black)
    popisqrt = map(pop_geo) do geo
        popi = geo.pop_max
        popi > 0 ? sqrt(popi) : 0.0
    end
    mini, maxi = extrema(popisqrt)
    size = map(popisqrt) do popi
        normed = (popi .- mini) ./ (maxi - mini)
        return (normed * 20) .+ 1
    end
    scatter!(ga, pop_geo, color=popisqrt, markersize=size)
    fig
end
