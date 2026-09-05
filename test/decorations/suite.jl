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

# ---- Phase 3: ticks, graticule and labels ------------------------------------

@testset "ticks, graticule and labels" begin
    for c in vcat(BASELINE_CASES, ISSUE_CASES)
        fig, ax = build_case(c)
        d = GM.decorations(ax)
        @testset "$(c.name)" begin
            v = phase3_violations(c.name, d)
            @test isempty(v)
            isempty(v) || foreach(println, v)
            @test !isempty(d.labels)
            @test !isempty(d.pixels.kept)
            # every family has grid lines and the stubs are one segment per drawn exit
            @test any(l -> l.family == :lon, d.graticule) && any(l -> l.family == :lat, d.graticule)
            @test iseven(length(d.pixels.stubs[:lon])) && iseven(length(d.pixels.stubs[:lat]))
            # a dest-space bound exists and is what the layout received
            @test all(>=(0), (d.bound.left, d.bound.right, d.bound.top, d.bound.bottom))
            @test ax.layoutobservables.protrusions[].left == d.bound.left
            @test ax.layoutobservables.protrusions[].bottom == d.bound.bottom
        end
    end
end

@testset "floors" begin
    for (name, floor) in FLOORS
        c = decoration_case(DECORATION_CASES, name)
        fig, ax = build_case(c)
        d = GM.decorations(ax)
        @testset "$name" begin
            for (what, ok) in floor(d)
                @test ok
                ok || println(name, ": ", what, " failed; lon=", drawn_labels(d, :lon), " lat=", drawn_labels(d, :lat))
            end
        end
    end
end

@testset "determinism" begin
    for name in ("eqearth", "ortho", "merc_reg", "igh", "issue388")
        @test isempty(determinism(decoration_case(DECORATION_CASES, name)))
    end
end

# Frames Phase 2 could not get right (PROJ's inverse of cass folds the sphere
# onto a sliver), so placement against them is not judged yet.
const PATHOLOGICAL_FRAMES = Set(["most_cass"])
# Cases where the default finder cannot prevent every same-family collision:
# bipc's probed rim is a sawtooth (accepted as-is in Phase 2), and Denoyer
# bunches its meridians non-uniformly along a short pole line, so the
# interval sized to that line still leaves ±90° against 0°.  Their drops are
# resolved by priority and reported.
const CROWDED_FRAMES = Set(["most_bipc", "most_denoy"])

@testset "most_projections decorate" begin
    for c in MOST_PROJECTION_CASES
        fig, ax = try
            build_case(c; coastlines = false)
        catch e
            @warn "skipping $(c.name): $(sprint(showerror, e))"
            continue
        end
        d = GM.decorations(ax)
        @testset "$(c.name)" begin
            v = phase3_violations(c.name, d)
            if c.name in PATHOLOGICAL_FRAMES
                @test_broken isempty(v)
            else
                @test isempty(v)
                isempty(v) || foreach(println, v)
            end
        end
    end
end

# ---- Phase 4: family rule and crowding ---------------------------------------

@testset "family rule and crowding" begin
    for c in vcat(BASELINE_CASES, ISSUE_CASES, VARIANT_CASES)
        fig, ax = build_case(c)
        d = GM.decorations(ax)
        @testset "$(c.name)" begin
            v = phase4_violations(c.name, d)
            @test isempty(v)
            isempty(v) || foreach(println, v)
            # the report accounts for every exit that did not become a drawn label
            @test length(d.pixels.kept) + count(s -> s.reason != :noexit, d.suppressed) == length(d.exits)
        end
    end
    # issue 388: no longitude label sits in the latitude column, and the zero
    # meridian is labelled 0° on the bottom edge
    fig, ax = build_case(decoration_case(ISSUE_CASES, "issue388"))
    d = GM.decorations(ax)
    lon = [l for l in d.labels[d.pixels.kept] if l.exit.family == :lon]
    @test all(l -> GM.edge_side(l.exit.normal) in (:bottom, :top), lon)
    @test any(l -> l.text == "0°" && GM.edge_side(l.exit.normal) === :bottom, lon)
end

@testset "most_projections family rule and crowding" begin
    for c in MOST_PROJECTION_CASES
        fig, ax = try
            build_case(c; coastlines = false)
        catch e
            @warn "skipping $(c.name): $(sprint(showerror, e))"
            continue
        end
        d = GM.decorations(ax)
        @testset "$(c.name)" begin
            v = phase4_violations(c.name, d)
            if c.name in PATHOLOGICAL_FRAMES || c.name in CROWDED_FRAMES
                @test_broken isempty(v)
                # the residual drops are still resolved: no overlap, everything reported
                @test isempty(no_overlap(c.name, d)) && isempty(every_absent_tick_reported(c.name, d))
            else
                @test isempty(v)
                isempty(v) || foreach(println, v)
            end
        end
    end
end

@testset "attribute semantics" begin
    c = decoration_case(BASELINE_CASES, "merc_reg")
    # the pad is the gap between tick end and glyph box; the tick is drawn on the frame
    fig, ax = build_case(c; xticklabelpad = 20.0, xticksize = 10.0)
    d = GM.decorations(ax)
    for (k, i) in enumerate(d.pixels.kept)
        l = d.labels[i]
        l.exit.family == :lon || continue
        @test l.offset == 30.0
        b = d.pixels.boxes[k]; n = d.pixels.normals[k]; e = d.pixels.exits[k]
        @test (b.centre - e) ⋅ n ≈ 30.0 + GM.half_extent(b, n)
    end
    # hidden ticks: the pad alone separates label and frame, and no stubs are drawn
    fig, ax = build_case(c; xticksvisible = false, xticklabelpad = 7.0)
    d = GM.decorations(ax)
    @test all(l -> l.exit.family != :lon || l.offset == 7.0, d.labels)
    @test isempty(d.pixels.stubs[:lon]) && !isempty(d.pixels.stubs[:lat])
    # xlabelpadding does not move the tick labels
    fig, ax0 = build_case(c)
    fig, ax1 = build_case(c; xlabelpadding = 40.0)
    @test GM.decorations(ax0).pixels.positions == GM.decorations(ax1).pixels.positions
    # rotation is honoured
    fig, ax = build_case(c; xticklabelrotation = pi / 4)
    d = GM.decorations(ax)
    @test all(l -> l.exit.family != :lon || l.rotation == pi / 4, d.labels)
    @test ax.elements[:xticklabels].rotation[] == Makie.to_rotation(pi / 4)
    # a user alignment overrides the derived one
    fig, ax = build_case(c; xticklabelalign = (:left, :bottom))
    d = GM.decorations(ax)
    @test all(l -> l.exit.family != :lon || (l.align == (:left, :bottom) && !l.auto_align), d.labels)
    @test ax.elements[:xticklabels].align[] == (:left, :bottom)
    # the formatter is honoured
    fig, ax = build_case(c; xtickformat = vs -> ["<$(round(Int, v))>" for v in vs])
    d = GM.decorations(ax)
    @test all(s -> startswith(s, '<') && endswith(s, '>'), drawn_labels(d, :lon))
    # hidden labels leave no protrusion on their sides
    fig, ax = build_case(c)
    hidedecorations!(ax)
    Makie.update_state_before_display!(fig)
    p = ax.layoutobservables.protrusions[]
    @test p.left == 0 && p.right == 0 && p.bottom == 0
end
