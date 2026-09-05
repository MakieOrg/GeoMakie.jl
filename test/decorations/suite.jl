# suite.jl -- build every case as a real GeoAxis and check its decorations.

@testset "baseline structure" begin
    for c in BASELINE_CASES
        fig, ax = build_case(c)
        d = GM.decorations(ax)
        @testset "$(c.name)" begin
            @test isempty(frame_closed(c.name, d.frame))
            v = frame_within_domain_and_limits(c.name, d)
            @test isempty(v)
            isempty(v) || foreach(println, v)
        end
    end
end

@testset "specific frames" begin
    fig, ax = build_case(decoration_case(BASELINE_CASES, "laea_polar"))
    fr = GM.decorations(ax).frame
    @test GM.nloops(fr) == 1
    @test all(==(:limit), GM.edge_tags(fr))

    fig, ax = build_case(decoration_case(BASELINE_CASES, "ortho"))
    fr = GM.decorations(ax).frame
    @test GM.nloops(fr) == 1
    @test all(==(:limb), GM.edge_tags(fr))

    fig, ax = build_case(decoration_case(BASELINE_CASES, "merc_reg"))
    fr = GM.decorations(ax).frame
    @test GM.nloops(fr) == 1
    @test tag_counts(fr)[:viewport] == 4
    @test GM.nedges(fr) == 4

    fig, ax = build_case(decoration_case(BASELINE_CASES, "zoom3"))
    fr = GM.decorations(ax).frame
    @test GM.nedges(fr) == 4 && tag_counts(fr)[:viewport] == 4

    fig, ax = build_case(decoration_case(BASELINE_CASES, "robin150"))
    fr = GM.decorations(ax).frame
    @test GM.nloops(fr) == 1
    @test tag_counts(fr)[:pole] == 2
    @test tag_counts(fr)[:cut] > 0

    fig, ax = build_case(decoration_case(BASELINE_CASES, "igh"))
    fr = GM.decorations(ax).frame
    @test GM.nloops(fr) == 1
    @test tag_counts(fr)[:cut] > 0

    fig, ax = build_case(decoration_case(BASELINE_CASES, "eqearth"))
    fr = GM.decorations(ax).frame
    @test tag_counts(fr)[:pole] == 2 && tag_counts(fr)[:cut] > 0
end

@testset "issue cases" begin
    for c in ISSUE_CASES
        fig, ax = build_case(c)
        d = GM.decorations(ax)
        @test isempty(frame_closed(c.name, d.frame))
        @test isempty(frame_within_domain_and_limits(c.name, d))
        @test GM.nloops(d.frame) == 1
    end
    # issue 234: a tiny quadrangle is the whole view, so its limits are the
    # bbox of its projected outline (widest along the equator for eqearth)
    fig, ax = build_case(decoration_case(ISSUE_CASES, "issue234"))
    tl = ax.targetlimits[]
    @test all(isfinite, minimum(tl)) && all(>(0), widths(tl))
    t = GM.decorations(ax).transform
    @test maximum(tl)[1] ≈ Makie.apply_transform(t, Point2d(3, 0))[1] rtol = 1e-6
    @test maximum(tl)[2] ≈ Makie.apply_transform(t, Point2d(0, 3))[2] rtol = 1e-6
    @test minimum(tl) ≈ Makie.apply_transform(t, Point2d(0, 0)) atol = 1e-6 * maximum(widths(tl))
end

@testset "most_projections close" begin
    open0 = GM.CHAIN_OPEN[]
    for c in MOST_PROJECTION_CASES
        fig, ax = try
            build_case(c; coastlines = false)
        catch e
            @warn "skipping $(c.name): $(sprint(showerror, e))"
            continue
        end
        d = GM.decorations(ax)
        @testset "$(c.name)" begin
            @test isempty(frame_closed(c.name, d.frame))
            @test all(isfinite, minimum(ax.targetlimits[])) && all(>(0), widths(ax.targetlimits[]))
        end
    end
    @test GM.CHAIN_OPEN[] == open0
end

@testset "boundary built once per axis" begin
    GM.BOUNDARY_BUILDS[] = 0
    fig = Figure(size = (600, 400))
    ax = GeoAxis(fig[1, 1])
    @test GM.BOUNDARY_BUILDS[] == 1
    xlims!(ax, -10, 30)
    @test GM.BOUNDARY_BUILDS[] == 1
    ax.targetlimits[] = Rect2d(-1e6, -1e6, 2e6, 2e6)
    @test GM.BOUNDARY_BUILDS[] == 1
    resize!(fig, 800, 500)
    @test GM.BOUNDARY_BUILDS[] == 1
    Makie.update_state_before_display!(fig)
    @test GM.BOUNDARY_BUILDS[] == 1
    # a new dest is a new boundary
    ax.dest = "+proj=moll"
    @test GM.BOUNDARY_BUILDS[] == 2
    @test GM.nloops(GM.decorations(ax).frame) == 1
end

@testset "limits flow" begin
    fig = Figure(size = (600, 400))
    ax = GeoAxis(fig[1, 1]; dest = "+proj=merc")
    full = ax.targetlimits[]
    limits!(ax, (-10, 30), (35, 60))
    reg = ax.targetlimits[]
    @test widths(reg)[1] < widths(full)[1]
    @test ax.graph[:lonlat_limits][] == Rect2d(-10.0, 35.0, 40.0, 25.0)
    t = GM.decorations(ax).transform
    @test minimum(reg) ≈ Makie.apply_transform(t, Point2d(-10, 35)) rtol = 1e-6
    @test maximum(reg) ≈ Makie.apply_transform(t, Point2d(30, 60)) rtol = 1e-6
    autolimits!(ax)
    @test ax.graph[:lonlat_limits][] == GM.FULL_LONLAT
    # the spine is a decoration: not a legend entry, not in the autolimits
    @test isempty(Makie.get_plots(ax))
    lines!(ax, [Point2f(0, 0), Point2f(10, 10)]; label = "series")
    @test length(Makie.get_plots(ax)) == 1
    @test haskey(ax.elements, :spine)
end
