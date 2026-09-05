
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
@testset "Tick specifications reach the labels" begin
    function labels_of(; kw...)
        fig = Figure(size = (600, 400))
        ax = GeoAxis(fig[1, 1]; dest = "+proj=merc", limits = ((-10, 30), (35, 60)), kw...)
        Makie.update_state_before_display!(fig)
        d = GeoMakie.decorations(ax)
        return d.pixels.strings[:lon], d.pixels.strings[:lat], ax
    end
    # (values, labels)
    lon, lat, _ = labels_of(; xticks = ([0, 10, 20], ["zero", "ten", "twenty"]))
    @test Set(lon) == Set(["zero", "ten", "twenty"])
    # a formatter function
    lon, _, _ = labels_of(; xtickformat = vs -> ["<$(round(Int, v))>" for v in vs])
    @test !isempty(lon) && all(s -> occursin(r"^<-?\d+>$", s), lon)
    # a format string
    lon, _, _ = labels_of(; xtickformat = "{:.1f}")
    @test !isempty(lon) && all(s -> occursin(r"^-?\d+\.\d$", s), lon)
    # any Makie finder
    lon, _, _ = labels_of(; xticks = Makie.WilkinsonTicks(5))
    @test !isempty(lon) && all(s -> endswith(s, '°') || endswith(s, 'E') || endswith(s, 'W'), lon)
    # a range: every value in the view is a tick; the ones that would collide are dropped and reported
    lon, _, ax = labels_of(; xticks = -180:2:180)
    d = GeoMakie.decorations(ax)
    @test d.xtickvalues.values == collect(-10.0:2:30)
    @test length(unique(lon)) + count(s -> s.reason == :collision && s.family == :lon, d.suppressed) == length(-10:2:30)
    @test "0°" in lon && "10°W" in lon && "30°E" in lon
    # the default formatter prints hemispheres
    lon, lat, _ = labels_of()
    @test "0°" in lon && "10°E" in lon && "10°W" in lon && "35°N" in lat
    # empty ticks: no labels, no error (#150)
    lon, lat, ax = labels_of(; xticks = Float64[])
    @test isempty(lon) && !isempty(lat)
    @test ax.layoutobservables.protrusions[].top == 0
    # the defaults are the geographic finder
    fig = Figure(); ax = GeoAxis(fig[1, 1])
    @test ax.xticks[] isa GeographicTicks && ax.yticks[] isa GeographicTicks
end

@testset "hidespines! and the Axis theme" begin
    fig = Figure(); ax = GeoAxis(fig[1, 1])
    @test haskey(ax.elements, :spine) && ax.elements[:spine].visible[]
    hidespines!(ax)
    @test !ax.elements[:spine].visible[] && !ax.elements[:bands].visible[]
    @test_throws ErrorException hidespines!(ax, :x)
    # hidedecorations! leaves the spine, as on Axis
    fig = Figure(); ax = GeoAxis(fig[1, 1])
    hidedecorations!(ax)
    @test ax.elements[:spine].visible[]
    # the Axis theme reaches the spine and the grid
    with_theme(Theme(Axis = (spinecolor = :red, spinewidth = 3, xgridcolor = :blue, ygridstyle = :dash))) do
        f = Figure(); ax = GeoAxis(f[1, 1])
        @test ax.spinecolor[] == Makie.to_color(:red) && ax.elements[:spine].color[] == Makie.to_color(:red)
        @test ax.spinewidth[] == 3 && ax.elements[:spine].linewidth[] == 3
        @test ax.xgridcolor[] == Makie.to_color(:blue) && ax.elements[:xgrid].color[] == Makie.to_color(:blue)
        @test ax.ygridstyle[] == :dash
    end
    # a GeoAxis theme entry, then a keyword, still win over the Axis theme
    with_theme(Theme(Axis = (spinecolor = :red,), GeoAxis = (spinecolor = :green,))) do
        f = Figure()
        @test GeoAxis(f[1, 1]).spinecolor[] == Makie.to_color(:green)
        @test GeoAxis(f[1, 2]; spinecolor = :blue).spinecolor[] == Makie.to_color(:blue)
    end
    # without a theme the defaults are the Axis defaults (#339)
    f = Figure(); ax = GeoAxis(f[1, 1]); a = Axis(f[1, 2])
    @test ax.spinecolor[] == a.leftspinecolor[] && ax.spinewidth[] == a.spinewidth[]
    @test ax.xgridcolor[] == a.xgridcolor[] && ax.ygridcolor[] == a.ygridcolor[]
    @test ax.xminorgridcolor[] == a.xminorgridcolor[]
    @test ax.framestyle[] === :plain && ax.gridbehind[]
    @test Makie.to_color(ax.backgroundcolor[]) == Makie.to_color(a.backgroundcolor[]) && ax.maskoutside[]
    @test !ax.xminorgridvisible[] && !ax.xminorticksvisible[] && ax.xminorticks[] === Makie.automatic
end

@testset "hidedecorations! parity" begin
    fig = Figure(size = (600, 400))
    ax = GeoAxis(fig[1, 1]; xlabel = "lon", ylabel = "lat", title = "t")
    Makie.update_state_before_display!(fig)
    @test haskey(ax.elements, :xlabel) && haskey(ax.elements, :ylabel) && haskey(ax.elements, :title)
    @test only(ax.elements[:xlabel].text[]) == "lon" && ax.elements[:xlabel].visible[]
    # hidexdecorations!(label = false) keeps the xlabel and hides the rest
    hidexdecorations!(ax; label = false)
    @test ax.xlabelvisible[] && ax.elements[:xlabel].visible[]
    @test !ax.xticklabelsvisible[] && !ax.xticksvisible[] && !ax.xgridvisible[]
    @test ax.ylabelvisible[] && ax.yticklabelsvisible[]
    hideydecorations!(ax; ticklabels = false, ticks = false)
    @test !ax.ylabelvisible[] && ax.yticklabelsvisible[] && ax.yticksvisible[] && !ax.ygridvisible[]
    # the minor branches, as on Axis
    ax.xminorgridvisible = true; ax.xminorticksvisible = true; ax.yminorgridvisible = true; ax.yminorticksvisible = true
    hidexdecorations!(ax; minorgrid = false)
    @test ax.xminorgridvisible[] && !ax.xminorticksvisible[]
    hideydecorations!(ax; minorticks = false)
    @test !ax.yminorgridvisible[] && ax.yminorticksvisible[]
    # hidedecorations! zeroes every protrusion but the title's
    hidedecorations!(ax)
    Makie.update_state_before_display!(fig)
    @test !ax.xlabelvisible[] && !ax.ylabelvisible[] && !ax.elements[:xlabel].visible[]
    p = ax.layoutobservables.protrusions[]
    @test p.left == 0 && p.right == 0 && p.bottom == 0
    @test p.top == GeoMakie.decorations(ax).titlespace > 0
    ax.title = ""
    @test ax.layoutobservables.protrusions[] == Makie.GridLayoutBase.RectSides{Float32}(0, 0, 0, 0)
    # tick stubs alone still reserve their length, as on Axis
    fig = Figure(size = (600, 400))
    ax = GeoAxis(fig[1, 1]; dest = "+proj=merc", limits = ((-10, 30), (35, 60)))
    Makie.update_state_before_display!(fig)
    hidedecorations!(ax; ticks = false)
    Makie.update_state_before_display!(fig)
    p = ax.layoutobservables.protrusions[]
    @test p.bottom == ax.xticksize[] && p.left == ax.yticksize[] && p.top == 0 && p.right == 0
    # tight_ticklabel_spacing! exists and returns what it reserved
    r = tight_ticklabel_spacing!(ax)
    @test r isa Makie.GridLayoutBase.RectSides
    @test r.bottom ≈ ax.xticksize[] atol = 1e-2
end
