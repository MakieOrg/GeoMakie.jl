
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

@testset "Common plot types" begin
    fig = Figure()
    ax = GeoAxis(fig[1,1])
    @testset "PointBased" begin
        @test_nowarn lines!(ax, 1:10, 1:10; label = "series 1")
        @test_nowarn scatter!(ax, 1:19, 2:20; label= "series 2")
    end

    @testset "Poly" begin
        @test_nowarn poly!(ax, Rect2f(0, 0, 1, 1))
    end

    @testset "GridBased" begin
        lons = -180:180
        lats = -90:90
        
        field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]
        
        @test_nowarn heatmap!(ax, lons, lats, field)
        @test_nowarn surface!(ax, lons, lats, field)
        @test_nowarn contour!(ax, lons, lats, field)
        @test_nowarn contourf!(ax, lons, lats, field)

    end
end