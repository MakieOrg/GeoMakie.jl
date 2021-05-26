using GeoMakie
using CairoMakie
using GeoMakie.GeoInterface
using GeoJSON
using Test
using Downloads

@testset "GeoMakie" begin
    source = LonLat()
    dest = WinkelTripel()
    states = Downloads.download("https://raw.githubusercontent.com/PublicaMundi/MappingAPI/master/data/geojson/us-states.json")
    states_geo = GeoJSON.read(read(states, String))
    lons = LinRange(-179.5, 179.5, 360 ÷ 2)
    lats = LinRange(-89.5, 89.5, 180 ÷ 2)
    field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]
    points = map(CartesianIndices(size(field))) do xy
        x, y = Tuple(xy)
        Point2f0(lons[x], lats[y])
    end

    proj = GeoMakie.proj(source, dest)
    limits = FRect2D(Makie.apply_transform(proj, points))
    fig = Figure()

    ax = Axis(fig[1,1])
    limits!(limits)
    ax.scene.transformation.transform_func[] = proj

    wireframe!(ax, lons, lats, field, color=(:gray, 0.2), transparency=true)
    n = length(GeoInterface.features(states_geo))
    lines!(ax, GeoMakie.coastlines())
    poly!(ax, states_geo, color= 1:n, strokecolor = :blue, strokewidth = 1)
    display(fig)
    @test true # :)
end
