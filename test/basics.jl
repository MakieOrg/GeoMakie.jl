@testset "Basics" begin
    lons = -180:180
    lats = -90:90
    field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

    fig = @test_nowarn Figure()
    ax = @test_nowarn GeoAxis(fig[1,1])
    el = @test_nowarn surface!(ax, lons, lats, field; shading = NoShading)
    @test true
    # display(fig)
end

@testset "geo2basic" begin
    @test GeoMakie.coastlines() isa Vector
    @test GeoMakie.coastlines()[1] isa GeometryBasics.LineString

    poly = GeoInterface.Polygon([[(0.0, 0.0), (3.0, 0.0), (3.0, 3.0), (0.0, 0.0)]])
    # geo2basic accepts anything GeoInterface understands, not just geometries
    @test GeoMakie.geo2basic(poly) isa GeometryBasics.Polygon
    @test GeoMakie.geo2basic(GeoInterface.Feature(poly)) isa GeometryBasics.Polygon
    @test GeoMakie.geo2basic([poly, poly]) isa Vector{<:GeometryBasics.Polygon}
    @test GeoMakie.geo2basic(poly for _ in 1:3) isa Vector{<:GeometryBasics.Polygon}
    # GeometryBasics has no linear ring or geometry collection type
    @test GeoMakie.geo2basic(GeoInterface.LinearRing([(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 0.0)])) isa GeometryBasics.LineString
    @test GeoInterface.trait(GeoMakie.geo2basic(GeoInterface.GeometryCollection([poly]))[1]) isa GeoInterface.PolygonTrait
end

# https://github.com/MakieOrg/GeoMakie.jl/issues/345
@testset "Natural Earth data at every scale" begin
    for scale in (110, 50, 10)
        @test GeoMakie.land(scale) isa Vector{<:GeometryBasics.MultiPolygon}
        @test GeoMakie.coastlines(scale) isa Vector{<:GeometryBasics.MultiLineString}
    end
end

@testset "Line Splitting" begin
    ga = @test_nowarn GeoAxis(Figure();dest = "+proj=wintri +lon_0=-160")
    @test split(GeoMakie.coastlines(), ga) isa Vector
    @test GeoMakie.coastlines(ga) isa Observable
    @test GeoMakie.coastlines(ga)[] isa AbstractVector
end
