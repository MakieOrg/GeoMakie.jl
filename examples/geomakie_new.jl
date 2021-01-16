using GLMakie
using GeoMakie
using GeoMakie.GeoInterface
using GeoMakie.GeoJSON

begin
    source = LonLat()
    dest = WinkelTripel()
    states = download("https://raw.githubusercontent.com/PublicaMundi/MappingAPI/master/data/geojson/us-states.json")
    states_geo = GeoJSON.parse(read(states, String))
    lons = LinRange(-179.5, 179.5, 360 ÷ 2)
    lats = LinRange(-89.5, 89.5, 180 ÷ 2)
    field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]
    fig = Figure()
    ax = fig[1,1] = Axis(fig)
    ax.scene.transformation.transform_func[] = GeoMakie.proj(source, dest)
    wireframe!(ax, lons, lats, field, color=(:gray, 0.2), transparency=true)
    n = length(GeoInterface.features(states_geo))
    lines!(ax, GeoMakie.coastlines())
    poly!(ax, states_geo, color= 1:n, strokecolor = :blue, strokewidth = 1)
    display(fig)
end
