using GeoMakie
using Test

@testset "GeoMakie.jl" begin
    # Write your own tests here.
end

state_data = download("https://raw.githubusercontent.com/PublicaMundi/MappingAPI/master/data/geojson/us-states.json")
