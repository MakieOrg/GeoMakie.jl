using GeoMakie, GeometryBasics, CairoMakie, Test
import Makie.SpecApi as S

Makie.set_theme!(Theme(
    Heatmap = (rasterize = 5,),
    Image   = (rasterize = 5,),
    Surface = (rasterize = 5,),
))


@testset "GeoMakie" begin
    @testset "MeshImage" begin
        include("meshimage.jl")
    end
    
    @testset "Basics" begin
        lons = -180:180
        lats = -90:90
        field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

        fig = Figure()
        ax = GeoAxis(fig[1,1])
        el = surface!(ax, lons, lats, field; shading = NoShading)
        @test true
        # display(fig)
    end

    @testset "geo2basic" begin
        @test GeoMakie.coastlines() isa Vector
        @test GeoMakie.coastlines()[1] isa GeometryBasics.LineString
    end

    @testset "Line Splitting" begin
        @test split(GeoMakie.coastlines(),"+lon_0=-160") isa Vector
        ga = GeoAxis(Figure();dest = "+proj=wintri +lon_0=-160")
        @test GeoMakie.coastlines(ga) isa Observable
        @test GeoMakie.coastlines(ga)[] isa AbstractVector
    end

    @testset "Legend" begin
        fig = Figure()
        ga = GeoAxis(fig[1, 1])
        lines!(ga, 1:10, 1:10; label = "series 1")
        scatter!(ga, 1:19, 2:20; label= "series 2")
        @test_nowarn Legend(fig[1, 2], ga)
        fig
    end

    @testset "Plotlists get transformed" begin
        fig = Figure()
        ax = GeoAxis(fig[1,1])
        plotspecs = [S.Lines(Point2f.(1:10, 1:10)), S.Scatter(Point2f.(1:10, 1:10))]

        p1 = plotlist!(ax, plotspecs)

        @test p1.transformation.transform_func[] isa GeoMakie.Proj.Transformation

        for plot in p1.plots
            @test plot.transformation.transform_func[] isa GeoMakie.Proj.Transformation
        end
    end
end
