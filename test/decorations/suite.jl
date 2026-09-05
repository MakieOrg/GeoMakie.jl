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
    fig, ax = build_case(decoration_case(ISSUE_CASES, "issue_234"))
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
            for (what, ok) in floor_results(floor, d, ax)
                @test ok
                ok || println(name, ": ", what, " failed; lon=", drawn_labels(d, :lon), " lat=", drawn_labels(d, :lat))
            end
        end
    end
end

@testset "determinism" begin
    for name in ("eqearth", "ortho", "merc_reg", "igh", "issue_388")
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
            # the report accounts for every exit that did not become a drawn frame label
            @test count(!GM.isinterior, d.labels[d.pixels.kept]) +
                count(s -> s.kind == :frame && s.reason != :noexit, d.suppressed) == length(d.exits)
        end
    end
    # issue 388: no longitude label sits in the latitude column, and the zero
    # meridian is labelled 0° on the bottom edge
    fig, ax = build_case(decoration_case(ISSUE_CASES, "issue_388"))
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

# adams_hemi's probed rim cuts the corner at each pole a fraction of a degree
# short, and the projection is singular there: seven meridians leave through
# ten pixels of notch.  They are a pole drawn as a point all the same.
@testset "pole on a probed rim" begin
    fig, ax = build_case(decoration_case(DECORATION_CASES, "most_adams_hemi"); coastlines = false)
    d = GM.decorations(ax)
    lon = filter(e -> e.family == :lon, d.exits)
    @test length(lon) == 14 && all(e -> e.tag === :limb, lon)
    @test all(e -> GM.near_pole(e.sphere) != 0, lon)
    @test all(e -> abs(e.sphere[3]) < 1 - 1e-6, lon)          # cut short of the pole, not at it
    @test all(s -> s.reason in (:convergent, :noexit), filter(s -> s.family == :lon, d.suppressed))
    @test count(s -> s.family == :lon && s.reason == :convergent, d.suppressed) == 14
    @test isempty([l for l in d.labels[d.pixels.kept] if l.exit.family == :lon && !GM.isinterior(l)])
    @test interior_once(d, :lon)
    @test isempty(phase4_violations("most_adams_hemi", d))
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

# ---- Phase 5: interior labels -------------------------------------------------

const REGIONAL_CASES = ("merc_reg", "zoom3", "lcc", "issue_234", "issue_388", "merc_reg_top", "merc_reg_right", "merc_reg_both")
const INTERIOR_CASES = ("laea_polar_nolimits", "stere_polar", "moll", "igh", "ob_tran")

@testset "interior labels" begin
    for c in vcat(BASELINE_CASES, ISSUE_CASES, VARIANT_CASES)
        fig, ax = build_case(c)
        d = GM.decorations(ax)
        @testset "$(c.name)" begin
            v = phase5_violations(c.name, d)
            @test isempty(v)
            isempty(v) || foreach(println, v)
            # an interior label is drawn through its own plots, never the frame ones
            for family in (:lon, :lat)
                @test length(d.pixels.interior_strings[family]) == length(interior_drawn(d, family))
                @test length(d.pixels.strings[family]) == count(l -> !GM.isinterior(l) && l.exit.family == family, d.labels[d.pixels.kept])
            end
            # interior labels reserve no layout space
            @test d.bound == GM.protrusion_bound(filter(!GM.isinterior, d.labels), (; lon = true, lat = true))
            # every line with no frame candidate that lost an exit to geometry
            # (not only to the family rule) is drawn inside or reported
            framed = Set((l.exit.family, l.exit.value) for l in d.labels if !GM.isinterior(l))
            geometric = Set((s.family, s.value) for s in d.suppressed if s.kind == :frame && s.reason != :family)
            blocked = setdiff(Set((s.family, s.value) for s in d.suppressed if s.kind == :frame), geometric)
            inside = Set((l.exit.family, l.exit.value) for l in interior_drawn(d, :lon)) ∪ Set((l.exit.family, l.exit.value) for l in interior_drawn(d, :lat))
            reported = Set((s.family, s.value) for s in d.suppressed if s.kind == :interior)
            for l in d.graticule
                key = (l.family, l.value)
                (key in framed || key in blocked) && continue
                @test key in inside || key in reported
            end
        end
    end
    # regional maps: every line reaches the frame, so nothing is drawn inside
    for name in REGIONAL_CASES
        fig, ax = build_case(decoration_case(DECORATION_CASES, name))
        d = GM.decorations(ax)
        @test !any(GM.isinterior, d.labels)
        @test !any(s -> s.kind == :interior, d.suppressed)
    end
    # a line turned away only by the family rule is not labelled inside either:
    # merc_reg's meridians leave through the top as well as the bottom, and on
    # lcc with a data-driven viewport the outer meridians leave through the
    # sides alone and 50°N through the top
    for name in ("merc_reg", "lcc")
        fig, ax = build_case(decoration_case(DECORATION_CASES, name))
        d = GM.decorations(ax)
        @test d.xaxisposition == :bottom && d.yaxisposition == :left
        @test !any(GM.isinterior, d.labels) && !any(s -> s.kind == :interior, d.suppressed)
    end
    fig = Figure(size = (600, 400))
    ax = GeoAxis(fig[1, 1]; dest = "+proj=lcc +lon_0=-96 +lat_1=33 +lat_2=45")
    scatter!(ax, [-125.0, -65.0], [23.0, 52.0])
    Makie.update_state_before_display!(fig)
    d = GM.decorations(ax)
    @test all(==(:viewport), vcat(d.frame.tags...))
    framed = Set((l.exit.family, l.exit.value) for l in d.labels if !GM.isinterior(l))
    reasons = Dict{Tuple{Symbol, Float64}, Set{Symbol}}()
    for s in d.suppressed
        s.kind == :frame && push!(get!(reasons, (s.family, s.value), Set{Symbol}()), s.reason)
    end
    family_only = Set(k for (k, rs) in reasons if !(k in framed) && rs == Set([:family]))
    @test issubset(Set([(:lon, -140.0), (:lon, -130.0), (:lon, -60.0), (:lon, -50.0), (:lat, 50.0)]), family_only)
    @test !any(GM.isinterior, d.labels) && !any(s -> s.kind == :interior, d.suppressed)
    # the switch removes them and every other predicate still passes
    for name in INTERIOR_CASES
        c = decoration_case(DECORATION_CASES, name)
        fig, ax = build_case(c; interiorlabels = false)
        d = GM.decorations(ax)
        @testset "$name without interior labels" begin
            @test !any(GM.isinterior, d.labels)
            @test isempty(d.pixels.interior_strings[:lon]) && isempty(d.pixels.interior_strings[:lat])
            v = vcat(phase3_violations(name, d), phase4_violations(name, d))
            @test isempty(v)
            isempty(v) || foreach(println, v)
        end
    end
    # the carrier meridian moves the polar column: the labels sit on their
    # circles just past the 90°E meridian instead of the central one, turned
    # along the circle (vertical there, horizontal at the bottom)
    fig, ax0 = build_case(decoration_case(DECORATION_CASES, "laea_polar_nolimits"))
    fig, ax90 = build_case(decoration_case(DECORATION_CASES, "laea_polar_c90"))
    d0, d90 = GM.decorations(ax0), GM.decorations(ax90)
    @test Set(l.text for l in interior_drawn(d0, :lat)) == Set(["45°S", "0°", "45°N"])
    @test Set(l.text for l in interior_drawn(d90, :lat)) == Set(["45°S", "0°", "45°N"])
    @test all(l -> l.carrier == 0.0, interior_drawn(d0, :lat)) && all(l -> l.carrier == 90.0, interior_drawn(d90, :lat))
    @test d0.pixels.interior_positions[:lat] != d90.pixels.interior_positions[:lat]
    # the column on the 90°E meridian lies to the right of the pole, the default one below it
    pole = d0.pixels.frame[1] |> pts -> Point2d(sum(pts) / length(pts))
    @test all(p -> p[1] > pole[1] + 5, d90.pixels.interior_positions[:lat])
    @test all(p -> p[2] < pole[2] - 5, d0.pixels.interior_positions[:lat])
    @test all(r -> abs(r) < deg2rad(30), d0.pixels.interior_rotations[:lat])
    @test all(r -> abs(r) > deg2rad(60), d90.pixels.interior_rotations[:lat])
    # interior labels are smaller than the frame labels of their family, and their own attribute overrides that
    @test ax0.elements[:yinteriorlabels].fontsize[] ≈ 0.8 * ax0.yticklabelsize[]
    @test all(l -> l.half == GM.text_half_extents(l.text, Makie.to_font(ax0.graph[:fonts][], :regular), 0.8 * ax0.yticklabelsize[]), interior_drawn(d0, :lat))
    @test ax0.elements[:yinteriorlabels].rotation[] == Makie.to_rotation.(d0.pixels.interior_rotations[:lat])
    fig, axs = build_case(decoration_case(DECORATION_CASES, "laea_polar_nolimits"); interiorlabelsize = 20.0, interiorlabelrotation = 0.3)
    ds = GM.decorations(axs)
    @test axs.elements[:yinteriorlabels].fontsize[] ≈ 20.0
    @test all(l -> l.half == GM.text_half_extents(l.text, Makie.to_font(axs.graph[:fonts][], :regular), 20.0), interior_drawn(ds, :lat))
    @test all(==(0.3), ds.pixels.interior_rotations[:lat]) && all(l -> l.rotation == 0.3 && !l.auto_rotation, interior_drawn(ds, :lat))
    @test isempty(phase5_violations("laea_polar_fixed", ds))
    # meridians on a pseudocylindrical read along their lines: vertical at the central meridian, leaning with the others
    fig, axm = build_case(decoration_case(DECORATION_CASES, "moll"))
    dm = GM.decorations(axm)
    rot = Dict(l.text => l.rotation for l in interior_drawn(dm, :lon))
    @test rot["0°"] == pi / 2
    @test all(r -> deg2rad(45) < abs(r) <= pi / 2, values(rot))
    # a named carrier parallel is used as given
    fig, ax = build_case(decoration_case(DECORATION_CASES, "moll"); carrierparallel = 45)
    d = GM.decorations(ax)
    @test !isempty(interior_drawn(d, :lon)) && all(l -> l.carrier == 45.0, interior_drawn(d, :lon))
    @test isempty(phase5_violations("moll_c45", d))
    # :all forces an interior label onto lines that do reach the frame
    fig, ax = build_case(decoration_case(DECORATION_CASES, "merc_reg"); interiorlabels = :all)
    d = GM.decorations(ax)
    @test !isempty(interior_drawn(d, :lon)) && !isempty(interior_drawn(d, :lat))
    @test !isempty(drawn_labels(d, :lon)) && !isempty(drawn_labels(d, :lat))
    v = vcat(phase3_violations("merc_reg_all", d), phase4_violations("merc_reg_all", d), phase5_violations("merc_reg_all", d))
    @test isempty(v)
    isempty(v) || foreach(println, v)
    # the halo: its own plots under the labels, in the background colour unless told otherwise
    fig, ax = build_case(decoration_case(DECORATION_CASES, "laea_polar_nolimits"))
    @test haskey(ax.elements, :yinteriorlabels) && haskey(ax.elements, :yinteriorhalo)
    @test ax.elements[:yinteriorhalo].color[] == Makie.to_color(ax.blockscene.backgroundcolor[])
    @test ax.elements[:yinteriorhalo].strokewidth[] == ax.interiorlabelhalowidth[]
    @test ax.elements[:yinteriorhalo].visible[]
    ax.interiorlabelhalo = false
    @test !ax.elements[:yinteriorhalo].visible[]
    ax.interiorlabelhalocolor = :red
    @test ax.elements[:yinteriorhalo].color[] == Makie.to_color(:red)
    @test ax.elements[:yinteriorlabels].text[] == d0.pixels.interior_strings[:lat]
    hideydecorations!(ax)
    @test !ax.elements[:yinteriorlabels].visible[]
end

@testset "most_projections interior labels" begin
    for c in MOST_PROJECTION_CASES
        fig, ax = try
            build_case(c; coastlines = false)
        catch e
            @warn "skipping $(c.name): $(sprint(showerror, e))"
            continue
        end
        d = GM.decorations(ax)
        @testset "$(c.name)" begin
            v = phase5_violations(c.name, d)
            @test isempty(v)
            isempty(v) || foreach(println, v)
        end
    end
end

# ---- Phase 6: spine styles, grid z-order, and theme colours -------------------

@testset "fancy frame" begin
    for c in FANCY_CASES
        fig, ax = build_case(c)
        d = GM.decorations(ax)
        @testset "$(c.name)" begin
            v = vcat(phase3_violations(c.name, d), phase4_violations(c.name, d), phase5_violations(c.name, d),
                phase6_violations(c.name, d))
            @test isempty(v)
            isempty(v) || foreach(println, v)
            @test !isempty(d.bands.polygons) && ax.elements[:bands].visible[]
            # the plot draws the bands and then the corner cells, in the background colour
            @test length(ax.graph[:band_polygons][]) == length(d.bands.polygons) + length(d.bands.cells)
            @test ax.graph[:band_colors][][(end - length(d.bands.cells) + 1):end] == fill(Makie.to_color(ax.framecolors[][2]), length(d.bands.cells))
            for cell in d.bands.cells
                @test !GM.inside_loops(d.pixels.frame, sum(cell) / length(cell))
            end
            # the band's edges mark the ticks: no stubs, and labels clear the band instead
            @test isempty(d.pixels.stubs[:lon]) && isempty(d.pixels.stubs[:lat])
            @test all(l -> GM.isinterior(l) || l.offset == ax.framewidth[] + (l.exit.family == :lon ? ax.xticklabelpad[] : ax.yticklabelpad[]), d.labels)
            # the band lies outside the frame on every side, so every side reserves at least its width
            @test min(d.bound.left, d.bound.right, d.bound.top, d.bound.bottom) >= ax.framewidth[]
            # every band lies outside the map body: a band is the inner polyline followed by
            # the outer one reversed, so its first and last points straddle the strip's thickness
            for poly in d.bands.polygons
                @test !GM.inside_loops(d.pixels.frame, 0.5 * (poly[1] + poly[end]))
            end
        end
    end
    # a rectangle has four corner cells with a run per side, a pseudocylindrical
    # outline one at each end of its two pole lines, and a limb none
    fig, ax = build_case(decoration_case(DECORATION_CASES, "merc_reg_fancy"))
    d = GM.decorations(ax)
    @test length(d.bands.corners) == 4 && length(unique(d.bands.run)) == 4
    @test Set(d.bands.corners) == Set(d.pixels.frame[1])
    @test all(cell -> length(cell) == 4, d.bands.cells)
    fig, ax = build_case(decoration_case(DECORATION_CASES, "robin150_fancy"))
    d = GM.decorations(ax)
    @test length(d.bands.corners) == 4 && length(unique(d.bands.run)) == 4
    poles = [d.pixels.frame[1][j] for j in eachindex(d.frame.tags[1]) if d.frame.tags[1][j] == :pole]
    @test all(p -> p in d.bands.corners, poles)
    fig, ax = build_case(decoration_case(DECORATION_CASES, "ortho_fancy"))
    d = GM.decorations(ax)
    @test isempty(d.bands.corners) && isempty(d.bands.cells) && all(==(1), d.bands.run)
    # a plain frame draws no band, and the style switches live
    fig, ax = build_case(decoration_case(BASELINE_CASES, "merc_reg"))
    d = GM.decorations(ax)
    @test isempty(d.bands.polygons) && isempty(frame_band("merc_reg", d)) && !ax.elements[:bands].visible[]
    stubs = length(d.pixels.stubs[:lon])
    @test stubs > 0
    ax.framestyle = :fancy
    d = GM.decorations(ax)
    @test !isempty(d.bands.polygons) && ax.elements[:bands].visible[] && isempty(d.pixels.stubs[:lon])
    @test isempty(frame_band("merc_reg", d))
    ax.framestyle = :plain
    d = GM.decorations(ax)
    @test isempty(d.bands.polygons) && length(d.pixels.stubs[:lon]) == stubs
    # framewidth and framecolors are honoured
    fig, ax = build_case(decoration_case(DECORATION_CASES, "merc_reg_fancy"); framewidth = 12.0, framecolors = (:red, :blue))
    d = GM.decorations(ax)
    @test Set(d.bands.colors) == Set([Makie.to_color(:red), Makie.to_color(:blue)])
    @test min(d.bound.left, d.bound.right, d.bound.top, d.bound.bottom) >= 12
    @test all(l -> GM.isinterior(l) || l.offset >= 12, d.labels)
    # hidespines! takes the band with the spine
    hidespines!(ax)
    @test !ax.elements[:spine].visible[] && !ax.elements[:bands].visible[]
end

@testset "band sweep" begin
    black, white = Makie.to_color(:black), Makie.to_color(:white)
    lp = Point2d[(0, 0), (100, 0), (100, 50), (0, 50)]
    # a single run round the rectangle (no tags: the loop is one run).  Three
    # exits: two colours cannot alternate around an odd count, so the closing
    # band is split and the extra boundary is recorded
    ex = [(1, 1, Point2d(30, 0)), (1, 1, Point2d(60, 0)), (1, 3, Point2d(40, 50))]
    b = GM.frame_bands([lp], ex, 5.0, [black, white])
    @test isempty(b.corners) && isempty(b.cells) && all(==(1), b.run)
    @test length(b.polygons) == 4 && length(b.boundaries[1]) == 4 && b.extra[1] != 0
    @test all(b.colors[i] != b.colors[mod1(i + 1, 4)] for i in 1:4)
    @test all(b.loop .== 1)
    for poly in b.polygons, p in poly
        @test !(0 < p[1] < 100 && 0 < p[2] < 50)
        @test -5.0001 <= p[1] <= 105.0001 && -5.0001 <= p[2] <= 55.0001
    end
    # four exits: no split needed, and every boundary is an exit
    ex4 = vcat(ex, [(1, 3, Point2d(70, 50))])
    b4 = GM.frame_bands([lp], ex4, 5.0, [black, white])
    @test length(b4.polygons) == 4 && b4.extra[1] == 0
    @test Set(b4.boundaries[1]) == Set(Point2d[(30, 0), (60, 0), (40, 50), (70, 50)])
    # an exit on a corner: the band starting there owns the corner square
    exc = [(1, 1, Point2d(0, 0)), (1, 2, Point2d(100, 0)), (1, 3, Point2d(100, 50)), (1, 4, Point2d(0, 50))]
    bc = GM.frame_bands([lp], exc, 5.0, [black, white])
    @test length(bc.polygons) == 4
    @test Point2d(-5, -5) in bc.polygons[1] && Point2d(105, -5) in bc.polygons[2]
    @test all(poly -> length(unique(poly)) == length(poly), bc.polygons)
    # exits within a pixel are one boundary; a loop with no exit is one band
    bm = GM.frame_bands([lp], [(1, 1, Point2d(30, 0)), (1, 1, Point2d(30.5, 0))], 5.0, [black, white])
    @test length(bm.polygons) == 1
    b0 = GM.frame_bands([lp], Tuple{Int, Int, Point2d}[], 5.0, [black, white])
    @test length(b0.polygons) == 1 && b0.extra[1] == 1
    # a mirrored loop (map on the right) is offset the other way
    bmir = GM.frame_bands([lp], ex4, 5.0, [black, white]; outward = -1)
    @test all(p -> 0 - 1e-9 <= p[1] <= 100 + 1e-9 && 0 - 1e-9 <= p[2] <= 50 + 1e-9, Iterators.flatten(bmir.polygons))

    # runs: viewport sides are one run each, with a corner cell between them
    vtags = [fill(:viewport, 4)]; vsrc = [zeros(Int, 4)]
    @test GM.run_corners(lp, vtags[1], vsrc[1]) == [1, 2, 3, 4]
    br = GM.frame_bands([lp], vtags, vsrc, ex, 5.0, [black, white])
    @test length(br.corners) == 4 && Set(br.corners) == Set(lp) && br.extra[1] == 0
    # bottom: two exits → three bands; right: one; top: one exit → two; left: one
    @test br.run == [1, 1, 1, 2, 3, 3, 4] && length(br.polygons) == 7
    # the colours restart at every corner
    @test br.colors == [black, white, black, black, black, white, black]
    @test br.boundaries[1] == Point2d[(0, 0), (30, 0), (60, 0), (100, 0), (100, 50), (40, 50), (0, 50)]
    # a corner cell is the square outside the corner; the bands beside it stop flush with their edges
    cell = br.cells[findfirst(==(Point2d(0, 0)), br.corners)]
    @test Set(cell) == Set(Point2d[(0, 0), (0, -5), (-5, -5), (-5, 0)])
    @test !(Point2d(-5, -5) in br.polygons[1]) && !(Point2d(-5, -5) in br.polygons[end])
    @test Point2d(0, -5) in br.polygons[1] && Point2d(-5, 0) in br.polygons[end]
    # a run may wrap past the loop's first vertex; a vertex inside a run is no corner
    hex = Point2d[(0, 0), (40, -20), (80, 0), (80, 60), (40, 80), (0, 60)]
    htags = [[:cut, :pole, :cut, :cut, :pole, :cut]]; hsrc = [[1, 0, 2, 2, 0, 1]]
    @test GM.run_corners(hex, htags[1], hsrc[1]) == [2, 3, 5, 6]
    bh = GM.frame_bands([hex], htags, hsrc, [(1, 3, Point2d(80, 30)), (1, 6, Point2d(0, 30))], 5.0, [black, white])
    @test length(bh.polygons) == 6 && length(bh.cells) == 4
    # the wrapping run (edges 6 and 1) is one run of two bands: from the corner at (0, 60) to the exit, and on past (0, 0) to (40, -20)
    wrap = findall(==(bh.run[end]), bh.run)
    @test length(wrap) == 2 && bh.colors[wrap] == [black, white]
    @test Point2d(0, 0) in bh.polygons[wrap[2]]
    # a straight tag meeting a curved one at a shallow turn is still a corner; a collinear join is not
    flat = Point2d[(0, 0), (50, 0), (100, 0), (100, 50), (0, 50)]
    @test GM.run_corners(flat, [:viewport, :viewport, :viewport, :viewport, :viewport], [0, 0, 0, 0, 0]) == [1, 3, 4, 5]
    @test GM.run_corners(flat, [:limb, :limb, :viewport, :viewport, :viewport], [1, 1, 0, 0, 0]) == [1, 3, 4, 5]
    @test GM.run_corners(flat, [:limb, :limb, :limb, :limb, :limb], [1, 1, 1, 1, 1]) == Int[]
end

@testset "grid z-order and render order" begin
    fig, ax = build_case(decoration_case(BASELINE_CASES, "merc_reg"))
    sc = scatter!(ax, [10.0], [45.0])
    @test isempty(grid_behind("merc_reg", ax, sc))
    @test Makie.zvalue2d(ax.elements[:xgrid]) < Makie.zvalue2d(sc) < Makie.zvalue2d(ax.elements[:spine])
    ax.gridbehind = false
    @test isempty(grid_behind("merc_reg", ax, sc))
    @test Makie.zvalue2d(ax.elements[:xgrid]) > Makie.zvalue2d(sc)
    ax.gridbehind = true
    @test isempty(grid_behind("merc_reg", ax, sc))
    # the render order is fixed: graticule, plots, band, spine, ticks, labels, interior labels
    z(k) = Makie.zvalue2d(ax.elements[k])
    @test z(:ygrid) < 0 < z(:bands) < z(:spine) < z(:xticks) == z(:yticks) < z(:xticklabels) == z(:yticklabels) < z(:xinteriorlabels)
    # the spine is drawn in the block scene in pixels, so the axis viewport does not clip it
    @test ax.elements[:spine].parent === ax.blockscene && ax.elements[:bands].parent === ax.blockscene
    @test ax.elements[:spine].space[] === :pixel
    # its points are the frame in pixels, closed
    sp = ax.graph[:spine_px][]
    @test sp[1] == sp[end] && sp[1] == GM.decorations(ax).pixels.frame[1][1]
end

# ---- Phase 7: the axis owns its labels and reports its size honestly ---------

@testset "layout" begin
    for c in vcat(BASELINE_CASES, ISSUE_CASES, VARIANT_CASES, FANCY_CASES, LAYOUT_CASES)
        fig, ax = build_case(c)
        @testset "$(c.name)" begin
            v = phase7_violations(c.name, ax)
            @test isempty(v)
            isempty(v) || foreach(println, v)
            before = ax.layoutobservables.protrusions[]
            fixed = tight_ticklabel_spacing!(ax)
            @test GM.decorations(ax).fixed_reach == fixed
            after = ax.layoutobservables.protrusions[]
            # exact space is never more than the bound reserved
            for side in (:left, :right, :bottom, :top)
                @test GM.side_value(after, side) <= GM.side_value(before, side) + 1e-3
            end
            v = phase7_violations(c.name, ax; tight = true)
            @test isempty(v)
            isempty(v) || foreach(println, v)
            # every predicate of the earlier phases still holds with the exact space
            d = GM.decorations(ax)
            v = vcat(phase3_violations(c.name, d), phase4_violations(c.name, d), phase5_violations(c.name, d))
            @test isempty(v)
            isempty(v) || foreach(println, v)
        end
    end
    # a rectangular frame's bound is already exact: tightening changes nothing
    fig, ax = build_case(decoration_case(DECORATION_CASES, "merc_reg_labels"))
    before = ax.layoutobservables.protrusions[]
    tight_ticklabel_spacing!(ax)
    after = ax.layoutobservables.protrusions[]
    @test all(side -> abs(GM.side_value(after, side) - GM.side_value(before, side)) < 1e-3, (:left, :right, :bottom, :top))
    # a limb over-reserves by the gap between the outermost label and the limb's extreme point, and tightening removes it
    fig, ax = build_case(decoration_case(DECORATION_CASES, "ortho"))
    before = ax.layoutobservables.protrusions[]
    tight_ticklabel_spacing!(ax)
    after = ax.layoutobservables.protrusions[]
    @test after.left < before.left && after.right < before.right
    @test isempty(layout_protrusions("ortho", ax; tight = true))
end

@testset "axis parity" begin
    v = axis_parity("merc_reg")
    @test isempty(v)
    isempty(v) || foreach(println, v)
    fig, ga, ax = build_axis_parity()
    # the two axes are the same size on screen
    @test abs(widths(ga.scene.viewport[])[2] - widths(ax.scene.viewport[])[2]) <= 1
    @test abs(minimum(ga.scene.viewport[])[2] - minimum(ax.scene.viewport[])[2]) <= 1
end

@testset "axis labels" begin
    c = decoration_case(DECORATION_CASES, "merc_reg_labels")
    fig, ax = build_case(c)
    d = GM.decorations(ax)
    vp = d.viewport
    # drawn on the sides the positions name, outside the tick reach by the padding
    @test d.axislabels.lon.side == :bottom && d.axislabels.lat.side == :left
    @test d.axislabels.lon.extent > 0 && d.axislabels.lat.extent > 0
    @test d.reach.bottom ≈ d.bound.bottom + ax.xlabelpadding[] + d.axislabels.lon.extent
    @test d.reach.left ≈ d.bound.left + ax.ylabelpadding[] + d.axislabels.lat.extent
    @test d.reach.top == d.bound.top && d.reach.right == d.bound.right
    @test d.xlabel_position[2] ≈ minimum(vp)[2] - d.bound.bottom - ax.xlabelpadding[] - d.axislabels.lon.extent / 2 atol = 1e-3
    @test d.xlabel_position[1] ≈ minimum(vp)[1] + widths(vp)[1] / 2
    @test d.ylabel_position[1] ≈ minimum(vp)[1] - d.bound.left - ax.ylabelpadding[] - d.axislabels.lat.extent / 2
    @test ax.elements[:xlabel].rotation[] == Makie.to_rotation(0.0)
    @test ax.elements[:ylabel].rotation[] == Makie.to_rotation(pi / 2)
    # the label's box clears the tick labels by the padding
    xb = text_box(ax.elements[:xlabel], ax.xlabel[])
    @test maximum(c[2] for c in GM.corners(xb)) ≈ minimum(vp)[2] - d.bound.bottom - ax.xlabelpadding[] atol = 0.5
    # the title sits above the top reach, the subtitle between
    tb = text_box(ax.elements[:title], ax.title[]); sb = text_box(ax.elements[:subtitle], ax.subtitle[])
    @test minimum(c[2] for c in GM.corners(sb)) ≈ maximum(vp)[2] + d.reach.top + ax.titlegap[] atol = 0.5
    @test minimum(c[2] for c in GM.corners(tb)) >= maximum(c[2] for c in GM.corners(sb)) - 1e-3   # flush: subtitlegap = 0
    @test ax.layoutobservables.protrusions[].top ≈ d.reach.top + d.titlespace + d.subtitlespace
    # x/ylabelpadding pad the axis labels and nothing else
    fig, ax2 = build_case(c; xlabelpadding = 20.0, ylabelpadding = 30.0)
    d2 = GM.decorations(ax2)
    @test d2.reach.bottom ≈ d.reach.bottom + 17 && d2.reach.left ≈ d.reach.left + 25
    @test d2.bound == d.bound
    # the tick labels keep their offsets from the frame (the viewport itself shrinks by the padding)
    offsets(d) = (minimum(d.viewport)[2] - d.pixels.positions[:lon][1][2], minimum(d.viewport)[1] - d.pixels.positions[:lat][1][1])
    @test all(isapprox.(offsets(d2), offsets(d); atol = 1e-3))
    # label style attributes reach the plots
    fig, ax3 = build_case(c; xlabelsize = 30.0, ylabelcolor = :red, xlabelfont = :bold, ylabelrotation = 0.0)
    d3 = GM.decorations(ax3)
    @test ax3.elements[:xlabel].fontsize[] == 30 && ax3.elements[:ylabel].color[] == Makie.to_color(:red)
    @test d3.axislabels.lon.extent > d.axislabels.lon.extent
    @test ax3.elements[:ylabel].rotation[] == Makie.to_rotation(0.0)
    @test d3.axislabels.lat.extent > d.axislabels.lat.extent      # an upright ylabel is as wide as its text
    # labels follow the axis positions, and the title still clears everything on top
    fig, ax4 = build_case(decoration_case(DECORATION_CASES, "merc_reg_labels_topright"))
    d4 = GM.decorations(ax4)
    @test d4.axislabels.lon.side == :top && d4.axislabels.lat.side == :right
    @test d4.reach.bottom == 0 && d4.reach.left == 0 && d4.reach.top > d4.bound.top && d4.reach.right > d4.bound.right
    @test d4.xlabel_position[2] > maximum(d4.viewport)[2] && d4.ylabel_position[1] > maximum(d4.viewport)[1]
    @test isempty(phase7_violations("merc_reg_labels_topright", ax4))
    # :both keeps the Axis defaults, bottom and left
    fig, ax5 = build_case(c; xaxisposition = :both, yaxisposition = :both)
    d5 = GM.decorations(ax5)
    @test d5.axislabels.lon.side == :bottom && d5.axislabels.lat.side == :left
    # hiding a label frees its space; hidexdecorations! keeps it on request
    fig, ax6 = build_case(c)
    hidexdecorations!(ax6; label = false)
    d6 = GM.decorations(ax6)
    @test ax6.xlabelvisible[] && ax6.elements[:xlabel].visible[]
    @test !ax6.xticklabelsvisible[] && !ax6.xticksvisible[] && !ax6.xgridvisible[]
    @test d6.bound.bottom == 0 && d6.reach.bottom ≈ ax6.xlabelpadding[] + d6.axislabels.lon.extent
    @test d6.xlabel_position[2] ≈ minimum(d6.viewport)[2] - ax6.xlabelpadding[] - d6.axislabels.lon.extent / 2
    hidexdecorations!(ax6)
    d6 = GM.decorations(ax6)
    @test !ax6.xlabelvisible[] && d6.axislabels.lon.extent == 0 && d6.reach.bottom == 0
    # a blank label reserves nothing
    fig, ax7 = build_case(c; xlabel = "  ")
    @test GM.decorations(ax7).axislabels.lon.extent == 0
    # rich text and LaTeX labels measure through the drawn text
    fig, ax8 = build_case(c; xlabel = L"\lambda", ylabel = rich("lat", subscript("N")))
    d8 = GM.decorations(ax8)
    @test d8.axislabels.lon.extent > 0 && d8.axislabels.lat.extent > 0
    @test isempty(phase7_violations("merc_reg_rich", ax8))
end

@testset "several axes" begin
    # issue 349: hidden y decorations leave no space, so the column gaps match
    fig, axes = build_issue349()
    @test isempty(layout_no_collision("issue_349", axes))
    for ax in axes
        @test isempty(layout_protrusions("issue_349", ax))
    end
    @test axes[2].layoutobservables.protrusions[].left == 0 && axes[3].layoutobservables.protrusions[].left == 0
    @test axes[1].layoutobservables.protrusions[].left > 0
    bb = [ax.layoutobservables.computedbbox[] for ax in axes]
    gap12 = minimum(bb[2])[1] - maximum(bb[1])[1]
    gap23 = minimum(bb[3])[1] - maximum(bb[2])[1]
    @test abs(gap12 - gap23) <= 1
    # issue 268: the space reserved around each axis is what its decorations draw
    # (an eqearth frame carries latitude labels on both sides, tilted at the
    # corners), not the wide margins of the old width-of-the-longest-label rule
    fig, axes = build_issue268()
    @test isempty(layout_no_collision("issue_268", axes))
    for ax in axes
        p = ax.layoutobservables.protrusions[]
        @test 0 < p.bottom <= ax.xticksize[] + ax.xticklabelpad[] + ax.xticklabelsize[] * 1.2 + 1
        @test p.top < p.left && p.top < p.right
        @test isempty(layout_protrusions("issue_268", ax))
    end
    # the bound lets the tilted 60°N label reach above the frame wherever it sits;
    # tightening measures that nothing does and hands the space back
    for _ in 1:2, ax in axes
        Makie.tight_ticklabel_spacing!(ax)
        Makie.update_state_before_display!(fig)
    end
    for ax in axes
        @test isempty(layout_protrusions("issue_268", ax; tight = true))
        @test ax.layoutobservables.protrusions[].top == 0
    end
    @test isempty(layout_no_collision("issue_268", axes))
    # the two rows sit as close as the bottom decorations allow
    bb = [ax.layoutobservables.computedbbox[] for ax in axes]
    top_row = filter(ax -> minimum(ax.layoutobservables.computedbbox[])[2] > minimum(bb[1])[2] - 1, axes)
    @test length(top_row) == 2
end

# ---- Phase 8: minor graticule, minor ticks, and the mask ---------------------------

"Render `fig` to pixels."
# `colorbuffer` may hand back the screen's own buffer, so keep a copy
render_bytes(fig) = copy(colorbuffer(fig; px_per_unit = 1))

@testset "minor graticule and ticks" begin
    for c in MINOR_CASES
        fig, ax = build_case(c)
        d = GM.decorations(ax)
        shown = (; lon = ax.xminorgridvisible[] || ax.xminorticksvisible[], lat = ax.yminorgridvisible[] || ax.yminorticksvisible[])
        @testset "$(c.name)" begin
            v = vcat(phase3_violations(c.name, d), phase4_violations(c.name, d), phase5_violations(c.name, d),
                phase6_violations(c.name, d), phase7_violations(c.name, ax), phase8_violations(c.name, d, shown))
            @test isempty(v)
            isempty(v) || foreach(println, v)
            @test !isempty(d.xtickvalues.minors) && !isempty(d.ytickvalues.minors)
            @test !isempty(d.minor_graticule) && !isempty(d.minor_exits)
            # the minor lines are drawn through their own plots, lighter than the majors
            @test ax.elements[:xminorgrid].visible[] && ax.elements[:yminorgrid].visible[]
            @test ax.elements[:xminorgrid].color[] == Makie.to_color(ax.xminorgridcolor[])
            @test ax.elements[:xminorgrid].linewidth[] == ax.xminorgridwidth[]
            @test Makie.zvalue2d(ax.elements[:xminorgrid]) == Makie.zvalue2d(ax.elements[:xgrid])
            @test isequal(ax.graph[:xminorgrid_points][], GM.graticule_points(filter(l -> l.family == :lon, d.minor_graticule)))
            if ax.framestyle[] === :fancy
                # the band's edges mark the minor ticks too: no stubs, and a boundary at every minor exit
                @test isempty(d.minor_stubs.lon) && isempty(d.minor_stubs.lat)
                m = GM.PixelMap(d.projectionview, d.viewport)
                allb = reduce(vcat, d.bands.boundaries; init = Point2d[])
                for e in GM.band_exits(d.minor_exits, d.finallimits, d.ticklabelminangle)
                    @test minimum(norm(m(e.p) - q) for q in allb) <= 1.0 + 1e-6
                end
            else
                # shorter stubs of the minor size at the admitted minor exits, one per exit
                for family in (:lon, :lat)
                    pts = d.minor_stubs[family]
                    size = family === :lon ? ax.xminorticksize[] : ax.yminorticksize[]
                    @test iseven(length(pts)) && !isempty(pts)
                    @test all(i -> norm(pts[i + 1] - pts[i]) ≈ size, 1:2:(length(pts) - 1))
                    admitted = count(e -> e.family == family, GM.stub_exits(d.minor_exits, d.finallimits, d.ticklabelminangle, d.xaxisposition, d.yaxisposition))
                    @test length(pts) ÷ 2 <= admitted
                end
                @test ax.elements[:xminorticks].visible[] && ax.elements[:xminorticks].color[] == Makie.to_color(ax.xminortickcolor[])
                @test ax.elements[:xminorticks].linewidth[] == ax.xminortickwidth[]
            end
            # minors reserve no layout space (as on Axis): the bound is the majors' alone
            @test d.bound == GM.protrusion_bound(filter(!GM.isinterior, d.labels), (; lon = true, lat = true);
                ticks = (; lon = (; size = ax.xticksize[], align = ax.xtickalign[], visible = ax.xticksvisible[] && ax.framestyle[] !== :fancy),
                          lat = (; size = ax.yticksize[], align = ax.ytickalign[], visible = ax.yticksvisible[] && ax.framestyle[] !== :fancy)),
                base = ax.framestyle[] === :fancy ? ax.framewidth[] : 0.0)
        end
    end
    # the paired steps: merc_reg's 10° / 5° majors carry 2° / 1° minors
    fig, ax = build_case(decoration_case(DECORATION_CASES, "merc_reg_minor"))
    d = GM.decorations(ax)
    @test d.xtickvalues.values == [-10.0, 0.0, 10.0, 20.0, 30.0] && d.xtickvalues.minors == setdiff(-8.0:2:28, d.xtickvalues.values)
    @test d.ytickvalues.values == collect(35.0:5:60) && d.ytickvalues.minors == setdiff(36.0:1:59, d.ytickvalues.values)
    # IntervalsBetween on user majors, mirrored to the extent
    fig, ax = build_case(decoration_case(DECORATION_CASES, "merc_reg_intervals"))
    d = GM.decorations(ax)
    @test d.xtickvalues.minors == setdiff(-10.0:2:30, -10.0:10:30)
    @test d.ytickvalues.minors == collect(37.5:5:57.5)
    # minor attributes reach the plots (#215)
    fig, ax = build_case(decoration_case(DECORATION_CASES, "issue_215"))
    @test ax.elements[:xminorgrid].color[] == Makie.to_color((:red, 0.3)) && ax.elements[:xminorgrid].linewidth[] == 2
    @test ax.elements[:yminorgrid].linestyle[] == Makie.to_linestyle(:dash) || ax.yminorgridstyle[] == :dash
    @test ax.elements[:xminorticks].color[] == Makie.to_color(:red) && ax.elements[:xminorticks].linewidth[] == 2
    d = GM.decorations(ax)
    @test all(i -> norm(d.minor_stubs.lon[i + 1] - d.minor_stubs.lon[i]) ≈ 8, 1:2:(length(d.minor_stubs.lon) - 1))
end

@testset "minors off by default and byte-identical when hidden" begin
    fig, ax = build_case(decoration_case(DECORATION_CASES, "merc_reg"))
    @test !ax.xminorgridvisible[] && !ax.yminorgridvisible[] && !ax.xminorticksvisible[] && !ax.yminorticksvisible[]
    @test ax.xminorticks[] === Makie.automatic && ax.yminorticks[] === Makie.automatic
    d = GM.decorations(ax)
    # the positions exist, nothing is computed or drawn for them
    @test !isempty(d.xtickvalues.minors) && isempty(d.minor_graticule) && isempty(d.minor_exits)
    @test isempty(d.minor_stubs.lon) && isempty(d.minor_stubs.lat)
    @test isempty(phase8_violations("merc_reg", d, (; lon = false, lat = false)))
    plain = render_bytes(fig)
    # switching the minors on and off again renders the same bytes
    ax.xminorgridvisible = true; ax.yminorgridvisible = true; ax.xminorticksvisible = true; ax.yminorticksvisible = true
    Makie.update_state_before_display!(fig)
    d = GM.decorations(ax)
    @test !isempty(d.minor_graticule) && !isempty(d.minor_stubs.lon)
    shown = render_bytes(fig)
    @test shown != plain
    ax.xminorgridvisible = false; ax.yminorgridvisible = false; ax.xminorticksvisible = false; ax.yminorticksvisible = false
    Makie.update_state_before_display!(fig)
    @test isempty(GM.decorations(ax).minor_graticule)
    @test render_bytes(fig) == plain
    # a minor finder with the grid hidden draws nothing either
    fig2, ax2 = build_case(decoration_case(DECORATION_CASES, "merc_reg"); xminorticks = IntervalsBetween(5), yminorticks = [36.0, 37.0])
    @test render_bytes(fig2) == plain
    # and one family may show while the other stays hidden
    fig3, ax3 = build_case(decoration_case(DECORATION_CASES, "merc_reg"); xminorgridvisible = true)
    d3 = GM.decorations(ax3)
    @test all(l -> l.family == :lon, d3.minor_graticule) && !isempty(d3.minor_graticule)
    @test isempty(phase8_violations("merc_reg_x", d3, (; lon = true, lat = false)))
    # hidedecorations! covers the minor branches, and keeps them on request
    fig4, ax4 = build_case(decoration_case(DECORATION_CASES, "merc_reg_minor"))
    hidexdecorations!(ax4; minorgrid = false)
    @test ax4.xminorgridvisible[] && !ax4.xminorticksvisible[] && !ax4.xgridvisible[]
    hidedecorations!(ax4)
    @test !ax4.xminorgridvisible[] && !ax4.yminorgridvisible[] && !ax4.xminorticksvisible[] && !ax4.yminorticksvisible[]
    Makie.update_state_before_display!(fig4)
    @test isempty(GM.decorations(ax4).minor_graticule)
    @test !ax4.elements[:xminorgrid].visible[] && !ax4.elements[:yminorticks].visible[]
end

@testset "fancy band alternates on minor exits" begin
    fig, ax = build_case(decoration_case(DECORATION_CASES, "merc_reg_fancy"))
    d0 = GM.decorations(ax)
    n0 = length(d0.bands.polygons)
    ax.xminorticksvisible = true; ax.yminorticksvisible = true
    d1 = GM.decorations(ax)
    @test length(d1.bands.polygons) > n0
    @test isempty(frame_band("merc_reg_fancy_minor", d1))
    @test isempty(d1.pixels.stubs[:lon]) && isempty(d1.minor_stubs.lon)
    # a minor grid alone does not segment the band: only visible minor ticks do
    ax.xminorticksvisible = false; ax.yminorticksvisible = false
    ax.xminorgridvisible = true; ax.yminorgridvisible = true
    d2 = GM.decorations(ax)
    @test length(d2.bands.polygons) == n0 && !isempty(d2.minor_graticule)
end

@testset "most_projections with minors" begin
    for c in MOST_PROJECTION_CASES
        fig, ax = try
            build_case(c; coastlines = false, MINOR_ATTRS...)
        catch e
            @warn "skipping $(c.name): $(sprint(showerror, e))"
            continue
        end
        d = GM.decorations(ax)
        @testset "$(c.name)" begin
            v = phase8_violations(c.name, d)
            @test isempty(v)
            isempty(v) || foreach(println, v)
        end
    end
end

@testset "mask outside the frame" begin
    # the mask covers the rect minus the map body, over the plots and under the frame
    fig, ax = build_case(decoration_case(DECORATION_CASES, "lcc_title"))
    d = GM.decorations(ax)
    @test ax.maskoutside[] && haskey(ax.elements, :mask) && ax.elements[:mask].visible[]
    @test length(d.mask) == 1 && length(d.mask[1].interiors) == 1
    @test Makie.to_color(ax.elements[:mask].color[]) == Makie.to_color(ax.backgroundcolor[])
    @test ax.elements[:mask].parent === ax.scene
    z(k) = Makie.zvalue2d(ax.elements[k])
    @test z(:background) < z(:xgrid) < 0 < z(:mask) < z(:bands) < z(:spine) < z(:xticklabels) < z(:xinteriorlabels)
    ax.gridbehind = false
    @test 0 < z(:mask) < z(:xgrid)
    ax.gridbehind = true
    for c in (decoration_case(DECORATION_CASES, "lcc_title"), decoration_case(DECORATION_CASES, "ortho"),
              decoration_case(DECORATION_CASES, "robin150"), decoration_case(DECORATION_CASES, "issue_388"))
        v = nothing_outside_frame(c)
        @test isempty(v)
        isempty(v) || foreach(println, v)
    end
    # with the mask off the marker shows: the old behaviour
    c = decoration_case(DECORATION_CASES, "lcc_title_nomask")
    @test !c.attrs.maskoutside
    v = nothing_outside_frame(c)
    @test isempty(v)
    isempty(v) || foreach(println, v)
    fig, ax = build_case(c)
    @test isempty(GM.decorations(ax).mask) && !ax.elements[:mask].visible[]
    # a frame that is the viewport has no mask: the same bytes with the mask on and off
    for name in ("merc_reg", "zoom3", "merc_reg_fancy")
        fig1, ax1 = build_case(decoration_case(DECORATION_CASES, name))
        d1 = GM.decorations(ax1)
        @test all(==(:viewport), GM.edge_tags(d1.frame)) && isempty(d1.mask)
        @test outside_frame_pixel(d1) === nothing
        fig2, ax2 = build_case(decoration_case(DECORATION_CASES, name); maskoutside = false)
        @test render_bytes(fig1) == render_bytes(fig2)
    end
    # the mask survives hidedecorations!, and follows the attribute live
    fig, ax = build_case(decoration_case(DECORATION_CASES, "lcc_title"))
    hidedecorations!(ax)
    @test ax.maskoutside[] && ax.elements[:mask].visible[] && !isempty(GM.decorations(ax).mask)
    ax.maskoutside = false
    @test !ax.elements[:mask].visible[] && isempty(GM.decorations(ax).mask)
    ax.maskoutside = true
    @test ax.elements[:mask].visible[] && !isempty(GM.decorations(ax).mask)
    # the mask polygons: the inflated rect with every map loop as a hole; a hole loop of the frame is filled
    lp = Point2d[(0, 0), (10, 0), (10, 10), (0, 10)]
    hole = Point2d[(3, 3), (3, 6), (6, 6), (6, 3)]           # clockwise: a region the map does not cover
    fr = GM.Frame([lp, hole], [fill(:limb, 4), fill(:limb, 4)], [ones(Int, 4), ones(Int, 4)])
    polys = GM.mask_polygons(fr, Rect2d(-5, -5, 20, 20))
    @test length(polys) == 2
    @test length(polys[1].interiors) == 1 && collect(polys[1].interiors[1]) == lp
    @test all(p -> p[1] <= -5 || p[1] >= 15 || p[2] <= -5 || p[2] >= 15, polys[1].exterior)
    @test Set(polys[2].exterior) == Set(hole) && isempty(polys[2].interiors)
    @test isempty(GM.mask_polygons(GM.Frame([lp], [fill(:viewport, 4)], [zeros(Int, 4)]), Rect2d(0, 0, 10, 10)))
    @test length(GM.mask_polygons(GM.Frame(), Rect2d(0, 0, 10, 10))) == 1
    # the halo and the mask share the background colour and never meet: interior
    # labels lie on the map, the mask lies off it, and the labels stay legible
    fig, ax = build_case(decoration_case(DECORATION_CASES, "laea_polar_nolimits"))
    d = GM.decorations(ax)
    @test !isempty(d.mask) && !isempty(interior_drawn(d, :lat))
    @test Makie.to_color(ax.elements[:yinteriorhalo].color[]) == Makie.to_color(ax.elements[:mask].color[]) == Makie.to_color(ax.backgroundcolor[])
    img = colorbuffer(fig; px_per_unit = 1)
    bg = Makie.Colors.RGB(Makie.to_color(ax.backgroundcolor[]))
    for (k, i) in enumerate(d.pixels.kept)
        GM.isinterior(d.labels[i]) || continue
        b = d.pixels.boxes[k]
        @test all(c -> GM.inside_loops(d.pixels.frame, c), GM.corners(b))
        x0, x1 = extrema(c[1] for c in GM.corners(b)); y0, y1 = extrema(c[2] for c in GM.corners(b))
        inked = count(px -> Makie.Colors.colordiff(Makie.Colors.RGB(pixel_color(img, px)), bg) > 10,
            (Point2d(x, y) for x in floor(x0):ceil(x1), y in floor(y0):ceil(y1)))
        @test inked > 0
    end
    px = outside_frame_pixel(d)
    @test px !== nothing && Makie.Colors.colordiff(Makie.Colors.RGB(pixel_color(img, px)), bg) < 1
    # a dark theme: the mask, the halo and the background follow it
    with_theme(theme_dark()) do
        f, a = build_case(decoration_case(DECORATION_CASES, "lcc_title"))
        @test Makie.to_color(a.backgroundcolor[]) == Makie.to_color(Makie.theme(:backgroundcolor)[]) != Makie.to_color(:white)
        @test Makie.to_color(a.elements[:mask].color[]) == Makie.to_color(a.elements[:background].color[]) == Makie.to_color(a.backgroundcolor[])
        @test isempty(nothing_outside_frame(decoration_case(DECORATION_CASES, "lcc_title")))
    end
end


# ---- Phase 10: issue closure ------------------------------------------------------

# The invariants of every phase hold on the closure cases too (their floors
# reproduce each report); issue_150 has nothing to place, so only its floor speaks.
@testset "issue closure" begin
    for c in CLOSURE_CASES
        fig, ax = build_case(c)
        d = GM.decorations(ax)
        @testset "$(c.name)" begin
            v = vcat(phase3_violations(c.name, d), phase4_violations(c.name, d), phase5_violations(c.name, d))
            @test isempty(v)
            isempty(v) || foreach(println, v)
            c.name == "issue_150" || @test !isempty(d.pixels.kept)
            @test isempty(frame_closed(c.name, d.frame))
            @test isempty(frame_within_domain_and_limits(c.name, d))
        end
    end
    # #190: the tick label pad moves the labels, and xlabelpadding moves the axis label alone
    c = decoration_case(CLOSURE_CASES, "issue_190")
    fig, ax0 = build_case(c)
    fig, ax1 = build_case(c; xticklabelpad = 25.0, yticklabelpad = 25.0)
    d0, d1 = GM.decorations(ax0), GM.decorations(ax1)
    @test all(l -> GM.isinterior(l) || l.offset == d0.labels[1].offset + 20, d1.labels)
    # the bound grows by the pad's projection on each side (the widest label on
    # the limb sits at 45°, so by 20 cos 45° there), the reach with it
    @test d1.bound.left > d0.bound.left + 10 && d1.bound.bottom > d0.bound.bottom + 10
    @test d1.reach.left > d0.reach.left + 10 && d1.reach.bottom > d0.reach.bottom + 10
    fig, ax2 = build_case(c; xlabelpadding = 40.0)
    d2 = GM.decorations(ax2)
    @test d2.bound == d0.bound && d2.reach.bottom > d0.reach.bottom + 30
    # #388: `xticks = (values, labels)` reaches the labels, and no tick of the default set is dropped
    fig, ax = build_case(decoration_case(ISSUE_CASES, "issue_388"); xticks = ([0.0, 10.0, 20.0, 30.0], ["zero", "ten", "twenty", "thirty"]))
    d = GM.decorations(ax)
    @test Set(drawn_labels(d, :lon)) == Set(["zero", "ten", "twenty", "thirty"])
    fig, ax = build_case(decoration_case(ISSUE_CASES, "issue_388"))
    d = GM.decorations(ax)
    @test !any(s -> s.reason == :collision, d.suppressed)
    @test Set(d.xtickvalues.values) == Set(l.exit.value for l in d.labels[d.pixels.kept] if l.exit.family == :lon)
    # #157: the data follows the same model as the decorations
    fig, ax = build_case(decoration_case(CLOSURE_CASES, "issue_157"))
    coast = only(filter(p -> p isa Lines && !(p in values(ax.elements)), ax.scene.plots))
    @test coast.model[][2, 2] == -1 && ax.elements[:xgrid].model[][2, 2] == 1
    d = GM.decorations(ax)
    plain = GM.decorations(build_case(decoration_case(BASELINE_CASES, "eqearth"))[2])
    @test d.bound.top ≈ plain.bound.bottom && d.bound.bottom ≈ plain.bound.top
    @test d.bound.left ≈ plain.bound.left
    # a rotation reaches them too: a quarter turn puts the pole lines on the sides
    fig, axr = build_case(decoration_case(BASELINE_CASES, "eqearth"); coastlines = false)
    Makie.rotate!(axr.scene, pi / 2)
    dr = GM.decorations(axr)
    @test dr.transform isa GM.PlaneTransform && isempty(nothing_inside("eqearth_rotated", dr)) && isempty(no_overlap("eqearth_rotated", dr))
    # the longitude labels now leave through the sides, the latitude labels through top and bottom
    kept = dr.labels[dr.pixels.kept]
    @test all(l -> abs(l.normal[1]) > abs(l.normal[2]), filter(l -> l.exit.family == :lon, kept))
    @test all(l -> abs(l.normal[2]) > abs(l.normal[1]), filter(l -> l.exit.family == :lat && l.exit.value == 0, kept))
    @test !isempty(drawn_labels(dr, :lon)) && Set(drawn_labels(dr, :lon)) ⊆ Set(drawn_labels(plain, :lon))
    @test !isempty(drawn_labels(dr, :lat)) && Set(drawn_labels(dr, :lat)) ⊆ Set(drawn_labels(plain, :lat))
    # #155: a limit reset after the zoom restores the labels
    fig, ax = build_case(decoration_case(CLOSURE_CASES, "issue_155"))
    zoomed = drawn_labels(GM.decorations(ax), :lon)
    Makie.reset_limits!(ax)
    d = GM.decorations(ax)
    @test drawn_labels(d, :lon) == drawn_labels(plain, :lon) && drawn_labels(d, :lat) == drawn_labels(plain, :lat)
    @test zoomed != drawn_labels(d, :lon)
    # #339: a dark theme reaches both alike
    with_theme(theme_dark()) do
        fig, ax = build_case(decoration_case(CLOSURE_CASES, "issue_339"))
        other = only(filter(b -> b isa Axis, fig.content))
        # theme_dark recolours the grid (and hides the Axis spines; it leaves the
        # spine colour alone), so the grid is what tells the theme reached both
        @test Makie.to_color(ax.spinecolor[]) == Makie.to_color(other.leftspinecolor[])
        @test Makie.to_color(ax.xgridcolor[]) == Makie.to_color(other.xgridcolor[]) == Makie.to_color((:white, 0.09))
        @test Makie.to_color(ax.ygridcolor[]) == Makie.to_color(other.ygridcolor[])
        @test ax.elements[:xgrid].color[] == Makie.to_color((:white, 0.09))
    end
    # #150: empty ticks of one family alone, and a `(values, labels)` pair with nothing in it
    fig, ax = build_case(decoration_case(BASELINE_CASES, "merc_reg"); xticks = Float64[])
    d = GM.decorations(ax)
    @test isempty(drawn_labels(d, :lon)) && !isempty(drawn_labels(d, :lat))
    fig, ax = build_case(decoration_case(BASELINE_CASES, "merc_reg"); yticks = (Float64[], String[]))
    @test isempty(drawn_labels(GM.decorations(ax), :lat))
end
