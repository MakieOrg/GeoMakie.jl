
@testset "Legend" begin
    fig = Figure();
    ga = GeoAxis(fig[1, 1])
    lines!(ga, 1:10, 1:10; label = "series 1")
    scatter!(ga, 1:19, 2:20; label= "series 2")
    leg = @test_nowarn Legend(fig[1, 2], ga)
    # Test that the legend contains the correct labels
    leg_contents = contents(only(contents(leg.grid)))
    labels = [l.text[] for l in filter(x -> x isa Label, leg_contents)]
    @test isempty(setdiff(labels, ["series 1", "series 2"]))
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

@testset "Protrusions are correctly updated when visible = false" begin

    f, a, p = meshimage(-180..180, -90..90, GeoMakie.earth() |> rotr90; figure = (; figure_padding = 0), axis = (; type = GeoAxis, dest = "+proj=longlat +type=crs"))

    w = widths(a.finallimits[])
    colsize!(f.layout, 1, Aspect(1, w[1] / w[2]))
    resize_to_layout!(f)

    Makie.update_state_before_display!(f)
    original_prots = a.layoutobservables.protrusions[]
    Makie.hidedecorations!(a)
    Makie.update_state_before_display!(f)
    new_prots = a.layoutobservables.protrusions[]

    @test new_prots.left == 0
    @test new_prots.right == 0
    @test new_prots.top == 0
    @test new_prots.bottom == 0

end

@testset "Aspect ratio is equal to Axis with DataAspect" begin
    # Create two figures, one with regular axis and one with geoaxis
    # the transformation in both cases is the identity
    f1, a1, p1 = meshimage(-180..180, -90..90, GeoMakie.earth() |> rotr90; figure = (; figure_padding = 0), axis = (; aspect = DataAspect()));
    f2, a2, p2 = meshimage(-180..180, -90..90, GeoMakie.earth() |> rotr90; figure = (; figure_padding = 0), axis = (; type = GeoAxis, dest = "+proj=longlat +type=crs"));

    Makie.tightlimits!(a1)
    hidedecorations!(a1)
    hidedecorations!(a2)

    Makie.update_state_before_display!(f1)
    Makie.update_state_before_display!(f2)

    Makie.resize_to_layout!(f1)
    Makie.resize_to_layout!(f2)

    @test a1.scene.viewport[] == a2.scene.viewport[]
end