
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

@testset "Antimeridian-aware contour/contourf" begin
    lons = -180:180
    lats = -90:90
    field = [exp(cosd(l)) + 3(y / 90) for l in lons, y in lats]

    @testset "seam-crossing projections split the geometry" begin
        for dest in ("+proj=longlat +lon_0=180", "+proj=longlat +lon_0=-150", "+proj=moll +lon_0=150")
            fig = Figure()
            ax = GeoAxis(fig[1, 1]; dest)
            cfp = @test_nowarn contourf!(ax, lons, lats, field)
            clp = @test_nowarn contour!(ax, lons, lats, field)
            Makie.update_state_before_display!(fig)
            # the split nodes exist and produce at least as much geometry as the raw
            @test haskey(cfp.attributes.outputs, :split_polys)
            @test length(cfp.split_polys[]) >= length(cfp.polys[])
            @test haskey(clp.attributes.outputs, :split_lines)
            @test length(clp.split_lines[]) >= length(clp.masked_lines[])
            # every split polygon lies within [lon0 - 180, lon0 + 180]
            lon0 = GeoMakie.parse_lon0(dest)
            for p in cfp.split_polys[]
                for v in GeometryBasics.coordinates(p.exterior)
                    @test lon0 - 180 - 1 <= v[1] <= lon0 + 180 + 1
                end
            end
        end
    end

    @testset "curvilinear input" begin
        nx, ny = 40, 30
        LON = [l + 35 * sind(y) for l in range(-150, 150, nx), y in range(-80, 80, ny)]
        LAT = [Float64(y) for l in range(-150, 150, nx), y in range(-80, 80, ny)]
        Z = [cosd(l) + sind(2y) for l in range(-150, 150, nx), y in range(-80, 80, ny)]
        fig = Figure()
        ax = GeoAxis(fig[1, 1]; dest = "+proj=moll +lon_0=0")
        @test_nowarn contourf!(ax, LON, LAT, Z)
        @test_nowarn contour!(ax, LON, LAT, Z)
        Makie.update_state_before_display!(fig)
    end

    @testset "Oceananigans tripolar grid (Makie.jl#4885)" begin
        # A real curvilinear ocean grid that crosses the antimeridian. Guarded so
        # the suite still passes if Oceananigans can't be loaded in this env.
        loaded = try
            @eval using Oceananigans
            true
        catch err
            @warn "Skipping tripolar test: Oceananigans unavailable" err
            false
        end
        if loaded
            grid = Oceananigans.TripolarGrid(size = (20, 15, 1))
            λ, φ, _ = Oceananigans.nodes(grid, Oceananigans.Center(), Oceananigans.Center(), Oceananigans.Center())
            λ = Array(λ[1:grid.Nx, 1:grid.Ny, 1])
            φ = Array(φ[1:grid.Nx, 1:grid.Ny, 1])
            z = @. cosd(3λ) * cosd(φ)
            fig = Figure()
            ax = GeoAxis(fig[1, 1]; dest = "+proj=moll +lon_0=0")
            cfp = @test_nowarn contourf!(ax, λ, φ, z; levels = -1:0.2:1)
            @test_nowarn contour!(ax, λ, φ, z; levels = -1:0.2:1)
            Makie.update_state_before_display!(fig)
            @test length(cfp.split_polys[]) >= length(cfp.polys[])
            # add_cyclic_point should extend the grid by one column
            λc, φc, zc = add_cyclic_point(λ, φ, z)
            @test size(λc, 1) == size(λ, 1) + 1
            @test_nowarn contourf!(GeoAxis(fig[1, 2]; dest = "+proj=moll +lon_0=0"), λc, φc, zc; levels = -1:0.2:1)

            # lon_0 = 180 (the #4885 condition): the antimeridian now runs through
            # the visible map centre, so on the cyclic-closed grid the split must
            # actually fire (split_polys strictly more than the input polys) for the
            # curvilinear bands to render without smearing across the seam.
            ax180 = GeoAxis(fig[2, 1]; dest = "+proj=moll +lon_0=180")
            cfp180 = @test_nowarn contourf!(ax180, λc, φc, zc; levels = -1:0.2:1)
            @test_nowarn contour!(ax180, λc, φc, zc; levels = -1:0.2:1)
            Makie.update_state_before_display!(fig)
            @test length(cfp180.split_polys[]) > length(cfp180.polys[])
        end
    end

    @testset "unclosed global grid warns; closed grid / lon_0=0 stay quiet" begin
        # global but one cell short of closing (span 356°) -> footgun
        lons_open = collect(-180.0:4:176)
        lats2 = collect(-90.0:4:90)
        f = [cosd(3l) * cosd(y) for l in lons_open, y in lats2]

        # warns at lon_0 = 180 (the data seam lands at the visible map centre)
        let fig = Figure(), ax = GeoAxis(fig[1, 1]; dest = "+proj=moll +lon_0=180")
            @test_logs (:warn,) match_mode = :any contourf!(ax, lons_open, lats2, f)
        end
        # quiet at lon_0 = 0 (the seam hides on the map edge)
        let fig = Figure(), ax = GeoAxis(fig[1, 1]; dest = "+proj=moll +lon_0=0")
            @test_nowarn contourf!(ax, lons_open, lats2, f)
        end
        # quiet once the grid is closed with add_cyclic_point, even at lon_0 = 180
        lonc, fc = add_cyclic_point(lons_open, f)
        let fig = Figure(), ax = GeoAxis(fig[1, 1]; dest = "+proj=moll +lon_0=180")
            @test_nowarn contourf!(ax, lonc, lats2, fc)
        end
    end

    @testset "polar-stereographic cap" begin
        # A band that encircles the pole, on a grid stopping short of ±90.
        lonp = collect(-180.0:4:176)
        latp = collect(20.0:2:88)
        zp = [sind(y) + 0.25 * cosd(3l) * cosd(y) for l in lonp, y in latp]
        lonc, zc = add_cyclic_point(lonp, zp)
        fig = Figure()
        ax = GeoAxis(fig[1, 1]; dest = "+proj=stere +lat_0=90 +lon_0=0")
        cfp = @test_nowarn contourf!(ax, lonc, latp, zc; levels = range(-1, 1; length = 11))
        Makie.update_state_before_display!(fig)
        @test length(cfp.split_polys[]) >= length(cfp.polys[])
    end
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