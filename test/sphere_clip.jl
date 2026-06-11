using Test
using GeoMakie, CairoMakie, GeometryBasics
const G = GeoMakie
const _LL = "+proj=longlat +datum=WGS84"
_t(d) = G.create_transform(d, _LL)

@testset "clip_strategy dispatch" begin
    ct(d) = G.clip_strategy(_t(d))
    @test ct("+proj=moll") isa G.AntimeridianClip
    @test ct("+proj=moll +lon_0=180") isa G.AntimeridianClip
    @test ct("+proj=eqc") isa G.AntimeridianClip
    @test ct("+proj=ortho") isa G.CircleClip
    @test ct("+proj=spilhaus") isa G.PolygonClip
    @test ct("+proj=igh") isa G.PolygonClip
    @test ct("+proj=igh_o") isa G.PolygonClip
    @test ct("+proj=longlat +over") isa G.NoClip
end

@testset "great-circle intersect (d3 oracle)" begin
    seg(a, b) = G._ixseg(G._cartr(a[1] * pi / 180, a[2] * pi / 180), G._cartr(b[1] * pi / 180, b[2] * pi / 180))
    ix(a1, a2, b1, b2) = (x = G._gc_intersect(seg(a1, a2), seg(b1, b2));
                          x === nothing ? nothing : round.(G._sphr(x) .* (180 / pi), digits = 5))
    @test ix([-10, -10], [10, 10], [-10, 10], [10, -10]) == (0.0, 0.0)
    @test ix([0, 0], [40, 0], [20, -20], [20, 20]) == (20.0, 0.0)
    @test ix([0, 0], [10, 0], [50, 0], [60, 0]) === nothing
    # degenerate (zero-length) segment must NOT produce a spurious intersection
    @test G._gc_intersect(seg([5, 5], [5, 5]), seg([0, 0], [10, 0])) === nothing
end

@testset "resampler direction symmetry" begin
    proj = G._projector(_t("+proj=moll"))
    a = G.resample_sphere([G.Point2d(-30, 10), G.Point2d(40, -20)], proj)
    b = reverse(G.resample_sphere([G.Point2d(40, -20), G.Point2d(-30, 10)], proj))
    @test length(a) == length(b)
    @test all(((p, q),) -> isapprox(p[1], q[1]; atol = 1e-6) && isapprox(p[2], q[2]; atol = 1e-6), zip(a, b))
end

@testset "split_geometry produces no smear" begin
    LAND = GeoMakie.land()
    for dest in ["+proj=moll", "+proj=moll +lon_0=180", "+proj=ortho +lon_0=20 +lat_0=20",
                 "+proj=spilhaus", "+proj=igh", "+proj=igh_o"]
        t = _t(dest); proj = G._projector(t)
        sp = G.split_geometry(LAND, t)
        @test !isempty(sp)
        nonfin = count(sp) do p
            any(q -> !all(isfinite, proj(q[1], q[2])), GeometryBasics.coordinates(p.exterior))
        end
        @test nonfin == 0
    end
end

@testset "boundary_points finite" begin
    for dest in ["+proj=moll", "+proj=moll +lon_0=180", "+proj=ortho", "+proj=eqc",
                 "+proj=spilhaus", "+proj=igh"]
        b = G.boundary_points(dest)
        @test !isempty(b)
        @test all(p -> isfinite(p[1]) && isfinite(p[2]), b)
    end
end

@testset "GeoAxis recipe overrides render" begin
    LAND = GeoMakie.land(); C = GeoMakie.coastlines()
    lons = -180.0:4.0:180.0; lats = -90.0:4.0:90.0
    data = [sind(3l) * cosd(2p) for l in lons, p in lats]
    for dest in ["+proj=moll +lon_0=180", "+proj=spilhaus", "+proj=igh"]
        fig = Figure(); ga = GeoAxis(fig[1, 1]; dest = dest)
        @test_nowarn poly!(ga, LAND)
        @test_nowarn lines!(ga, C)
        @test_nowarn surface!(ga, lons, lats, zeros(length(lons), length(lats)); color = data, shading = NoShading)
        @test_nowarn heatmap!(ga, lons, lats, data)
        @test_nowarn meshimage!(ga, -180 .. 180, -90 .. 90, GeoMakie.earth() |> rotr90)
        @test_nowarn Makie.update_state_before_display!(fig)
    end
end
