using Test
using GeoMakie
using Makie
using Geodesy
using Colors

@testset "Lights — default install" begin
    fig = Figure()
    ga = GlobeAxis(fig[1, 1])

    lights = Makie.get_lights(ga.scene)
    @test length(lights) == 3
    @test all(l -> l isa DirectionalLight, lights)
    @test all(l -> l.camera_relative, lights)
end

@testset "Lights — construction-time override" begin
    fig = Figure()
    custom = [DirectionalLight(RGBf(1, 0, 0), Vec3f(-1, 0, 0))]
    ga = GlobeAxis(fig[1, 1]; lights = custom)

    lights = Makie.get_lights(ga.scene)
    @test length(lights) == 1
    @test lights[1] isa DirectionalLight
    @test lights[1].color == RGBf(1, 0, 0)
end

@testset "Lights — reactive replace" begin
    fig = Figure()
    ga = GlobeAxis(fig[1, 1])
    @test length(Makie.get_lights(ga.scene)) == 3   # default rig

    ga.lights[] = [DirectionalLight(RGBf(0, 1, 0), Vec3f(1, 0, 0))]
    lights = Makie.get_lights(ga.scene)
    @test length(lights) == 1
    @test lights[1].color == RGBf(0, 1, 0)
end

@testset "Lights — restore default" begin
    fig = Figure()
    ga = GlobeAxis(fig[1, 1])
    ga.lights[] = [DirectionalLight(RGBf(1, 0, 0), Vec3f(-1, 0, 0))]
    @test length(Makie.get_lights(ga.scene)) == 1

    ga.lights[] = automatic
    lights = Makie.get_lights(ga.scene)
    @test length(lights) == 3
    @test all(l -> l isa DirectionalLight, lights)
    @test all(l -> l.camera_relative, lights)
end

@testset "Lights — ambient extraction" begin
    fig = Figure()
    ga = GlobeAxis(fig[1, 1]; lights = [
        AmbientLight(RGBf(0.4, 0.0, 0.0)),
        DirectionalLight(RGBf(1, 1, 1), Vec3f(-1, 0, 0)),
        DirectionalLight(RGBf(0, 0, 1), Vec3f( 1, 0, 0)),
    ])

    lights = Makie.get_lights(ga.scene)   # excludes ambient
    @test length(lights) == 2
    @test all(l -> l isa DirectionalLight, lights)
    @test ga.scene.compute[:ambient_color][] == RGBf(0.4, 0.0, 0.0)
end

@testset "Lights — empty vector" begin
    fig = Figure()
    ga = GlobeAxis(fig[1, 1]; lights = Makie.AbstractLight[])
    @test isempty(Makie.get_lights(ga.scene))
    @test ga.scene.compute[:ambient_color][] == RGBf(0, 0, 0)
end

@testset "Lights — shaded surface plots" begin
    # Shaded plot under the default rig should construct + display without warnings.
    fig = Figure()
    ga = GlobeAxis(fig[1, 1])
    @test_nowarn surface!(ga, -180..180, -90..90, zeros(32, 32); color = rand(RGBf, 32, 32))
    @test_nowarn Makie.update_state_before_display!(ga)
end

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