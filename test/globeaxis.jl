using Test
using GeoMakie
using Makie
using Geodesy
@testset "Basic instantiation" begin
    fig = Figure()
    ga = @test_nowarn GlobeAxis(fig[1,1])
    @test_nowarn Makie.update_state_before_display!(ga)
    @test_nowarn lines!(ga, GeoMakie.coastlines())
    @test_nowarn surface!(ga, -180..180, -90..90, rand(100, 100); shading = NoShading)
    @test_nowarn scatter!(ga, 0, 0, 0)
    @test_nowarn Makie.update_state_before_display!(ga)
end

@testset "Camera control" begin
    f, a, p = @test_nowarn meshimage(-180..180, -90..90, GeoMakie.earth(); uv_transform = :rotr90, npoints = 100, z_level = 0, axis = (; type = GlobeAxis))
    @test_nowarn Makie.update_state_before_display!(a)

    f, a, p = @test_nowarn meshimage(
        -180..180, -90..90, GeoMakie.earth(); 
        uv_transform = :rotr90,
        npoints = 100, z_level = 0, axis = (; type = GlobeAxis, camera_longlat = (0, 0), camera_altitude = 1e7)
    )
    @test_nowarn Makie.update_state_before_display!(a)
    current_eyepos = cameracontrols(a.scene).eyeposition[]

    meshimage!(a, -180..180, -90..90, GeoMakie.earth(); uv_transform = :rotr90, npoints = 100, z_level = 2e8, reset_limits = false, xautolimits = false, yautolimits = false, zautolimits = false)
    @test_nowarn Makie.update_state_before_display!(a)
    @test cameracontrols(a.scene).eyeposition[] == current_eyepos
end