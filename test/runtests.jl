using GeoMakie, Test

@testset "GeoMakie" begin
    lons = -180:180
    lats = -90:90
    field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

    fig = Figure()
    ax = GeoAxis(fig[1,1], coastlines=true)
    el = surface!(ax, lons, lats, field; shading = false)
    @test true
    # display(fig)
end
