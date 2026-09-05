# placement.jl -- the family rule, oriented-box collisions, the priority
# order, the collision switch and the report, on their own and on an axis.

@testset "admits" begin
    down, up, left, right = Vec2d(0, -1), Vec2d(0, 1), Vec2d(-1, 0), Vec2d(1, 0)
    # a viewport edge takes the Axis convention on the sides the positions name
    @test GM.admits(:viewport, :lon, down, :bottom, :left)
    @test !GM.admits(:viewport, :lon, up, :bottom, :left)
    @test GM.admits(:viewport, :lon, up, :top, :left)
    @test GM.admits(:viewport, :lon, up, :both, :left) && GM.admits(:viewport, :lon, down, :both, :left)
    @test !GM.admits(:viewport, :lat, down, :bottom, :left)
    @test GM.admits(:viewport, :lat, left, :bottom, :left)
    @test !GM.admits(:viewport, :lat, right, :bottom, :left)
    @test GM.admits(:viewport, :lat, right, :bottom, :right)
    @test GM.admits(:viewport, :lat, right, :bottom, :both) && GM.admits(:viewport, :lat, left, :bottom, :both)
    @test !GM.admits(:viewport, :lon, left, :both, :both)
    # a slanted normal goes with its larger component
    @test GM.edge_side(Vec2d(0.3, -0.95)) === :bottom && GM.edge_side(Vec2d(-0.9, 0.4)) === :left
    # every other edge admits both families whatever the positions say
    for tag in (:limb, :limit, :cut, :pole), family in (:lon, :lat), n in (down, up, left, right)
        @test GM.admits(tag, family, n, :bottom, :left)
        @test GM.admits(tag, family, n, :top, :right)
    end
end

@testset "oriented boxes" begin
    a = GM.OBox(Point2d(0, 0), Vec2d(20, 5), 0.0)
    # a long thin box rotated by 45° pointing at a's corner clears it, while
    # its axis-aligned bounds already overlap a's
    b = GM.OBox(Point2d(36, 21), Vec2d(20, 5), pi / 4)
    @test !GM.collides(a, b)
    aabb(box) = (cs = GM.corners(box); (minimum(c[1] for c in cs), maximum(c[1] for c in cs), minimum(c[2] for c in cs), maximum(c[2] for c in cs)))
    ra, rb = aabb(a), aabb(b)
    @test ra[2] > rb[1] && ra[4] > rb[3]          # the axis-aligned bounds do overlap
    @test GM.collides(a, GM.OBox(Point2d(15, 15), Vec2d(20, 5), pi / 4))
    # the gap is clearance along a separating axis
    c = GM.OBox(Point2d(41, 0), Vec2d(20, 5), 0.0)
    @test !GM.collides(a, c) && GM.collides(a, c; gap = 2)
    @test GM.half_extent(GM.OBox(Point2d(0, 0), Vec2d(3, 4), pi / 2), Vec2d(1, 0)) ≈ 4
end

@testset "priority is total" begin
    @test GM.roundness(0) == GM.roundness(90) == GM.roundness(-90) == GM.roundness(180) == 0
    @test GM.roundness(45) < GM.roundness(30) < GM.roundness(10) < GM.roundness(1) < GM.roundness(7.3)
    fig, ax = build_case(decoration_case(DECORATION_CASES, "ortho"))
    d = GM.decorations(ax)
    ps = [l.priority for l in d.labels]
    @test length(unique(ps)) == length(ps)
    @test issorted(sort(ps))
    # what is kept does not depend on the order the exits arrived in
    kept = Set((l.exit.family, l.exit.value, l.exit.p) for l in d.labels[d.pixels.kept])
    rev = GM.pixels(d.frame, d.graticule, reverse(d.labels), ax.scene.camera.projectionview[], d.viewport,
        (; lon = (; size = 6.0, align = 0.0, visible = true), lat = (; size = 6.0, align = 0.0, visible = true)))
    kept_rev = Set((l.exit.family, l.exit.value, l.exit.p) for l in reverse(d.labels)[rev.kept])
    @test kept == kept_rev
end

@testset "convergent exits" begin
    ex(v, p) = GM.Exit(:lon, v, p, 1, 1, :cut, Vec2d(0, 1), 90.0, Vec2d(0, 1))
    tol = 1e-3
    three = [ex(0.0, Point2d(0, 0)), ex(30.0, Point2d(1e-4, 0)), ex(60.0, Point2d(0, 1e-4)), ex(90.0, Point2d(5, 5))]
    @test GM.convergent_exits(three, tol) == Set([1, 2, 3])
    # two meridians at one point can only be a pole; the same meridian twice
    # (both sides of a cut) is not
    two = [ex(0.0, Point2d(0, 0)), ex(30.0, Point2d(1e-4, 0)), ex(90.0, Point2d(5, 5))]
    @test GM.convergent_exits(two, tol) == Set([1, 2])
    same = [ex(0.0, Point2d(0, 0)), ex(0.0, Point2d(1e-4, 0))]
    @test isempty(GM.convergent_exits(same, tol))
    # different families at one point are a corner
    corner = [ex(0.0, Point2d(0, 0)), GM.Exit(:lat, 0.0, Point2d(0, 0), 1, 1, :viewport, Vec2d(-1, 0), 90.0, Vec2d(-1, 0))]
    @test isempty(GM.convergent_exits(corner, tol))
    # a pole on a probed rim: the exits sit a few pixels apart in dest space
    # but within a degree of the pole on the sphere
    sph(lon, lat) = Vec3d(cosd(lat) * cosd(lon), cosd(lat) * sind(lon), sind(lat))
    exs(v, p, q, tag = :limb) = GM.Exit(:lon, v, p, 1, 1, tag, Vec2d(0, -1), 90.0, Vec2d(0, -1), q)
    notch = [exs(-90.0, Point2d(-0.03, 0), sph(-90, -89.8)), exs(0.0, Point2d(0, 0), sph(0, -89.9)),
        exs(90.0, Point2d(0.03, 0), sph(90, -89.8)), exs(45.0, Point2d(3, 0), sph(45, 30))]
    @test GM.convergent_exits(notch, tol; poletol = 0.05) == Set([1, 2, 3])
    @test GM.convergent_exits(notch, tol; poletol = 0.04) == Set([1, 2, 3])     # 0.03 each side of 0°
    @test isempty(GM.convergent_exits(notch, tol; poletol = 0.005))
    # exits at opposite poles, or spread wide, do not converge
    far = [exs(0.0, Point2d(0, 0), sph(0, -89.9)), exs(30.0, Point2d(0.3, 0), sph(30, -89.9)), exs(60.0, Point2d(0, 5), sph(60, 89.9))]
    @test isempty(GM.convergent_exits(far, tol; poletol = 0.05))
    # on a pole line every exit is at the pole on the sphere: the line rule stands
    poleline = [exs(0.0, Point2d(0, 0), sph(0, 90), :pole), exs(30.0, Point2d(0.03, 0), sph(30, 90), :pole)]
    @test isempty(GM.convergent_exits(poleline, tol; poletol = 0.05))
    @test GM.near_pole(sph(10, 89.5)) == 1 && GM.near_pole(sph(10, -89.5)) == -1 && GM.near_pole(sph(10, 88)) == 0
    @test GM.near_pole(GM.NO_SPHERE_POINT) == 0
end

@testset "collision switch, gap and report" begin
    c = decoration_case(DECORATION_CASES, "merc_reg")
    dense = (; xticks = -10:1:30)
    fig, ax = build_case(c; dense...)
    d = GM.decorations(ax)
    ncand = count(l -> l.exit.family == :lon, d.labels)
    @test ncand == 41
    drops = [s for s in d.suppressed if s.reason == :collision]
    @test !isempty(drops)
    @test length(d.pixels.strings[:lon]) + length(drops) == ncand
    # user ticks are never coarsened: the tick values are all there
    @test d.xtickvalues.values == collect(-10.0:30.0)
    # the round values win
    @test all(s -> s in d.pixels.strings[:lon], ("10°W", "0°", "10°E", "20°E", "30°E"))
    @test isempty(no_overlap(c.name, d))
    # every drop names the label it hit, and the report says so
    @test all(s -> d.labels[s.hit].exit.family == :lon, drops)
    msg = GM.suppression_report(d.suppressed, 2.0, 20.0)
    @test occursin("longitude and 0 latitude labels skipped due to crowding; controlled by `ticklabelmingap`, currently 2.0 px", msg)
    @test_logs (:info, r"skipped due to crowding") GM.report_suppressions(d.suppressed, :info, 2.0, 20.0)
    @test_logs GM.report_suppressions(d.suppressed, :none, 2.0, 20.0)
    @test GM.suppression_report(GM.Suppressed[], 2.0, 20.0) === nothing
    # a wider gap drops more
    fig, ax = build_case(c; dense..., ticklabelmingap = 30.0)
    d30 = GM.decorations(ax)
    @test count(s -> s.reason == :collision, d30.suppressed) > length(drops)
    # the switch keeps everything, overlaps included
    fig, ax = build_case(c; dense..., ticklabelcollisions = false)
    dall = GM.decorations(ax)
    @test length(dall.pixels.strings[:lon]) == ncand
    @test !any(s -> s.reason == :collision, dall.suppressed)
    @test !isempty(no_overlap(c.name, dall))
end

@testset "grazing" begin
    # on the ortho limb every line is tangent in the plane; the sphere angle keeps them
    c = decoration_case(DECORATION_CASES, "ortho")
    fig, ax = build_case(c)
    d = GM.decorations(ax)
    @test all(e -> e.angle >= 20, d.exits)
    @test !any(s -> s.reason == :grazing, d.suppressed)
    # raising the minimum angle drops the obliquest crossings and says so
    fig, ax = build_case(c; ticklabelminangle = 60.0)
    d60 = GM.decorations(ax)
    g = [s for s in d60.suppressed if s.reason == :grazing]
    @test !isempty(g)
    @test occursin("grazing angle; controlled by `ticklabelminangle`, currently 60.0°", GM.suppression_report(d60.suppressed, 2.0, 60.0))
    # a meridian lying on a cut seam (igh's 180°) leaves at 0° where it is not
    # also a pole point, and is never labelled on the frame
    fig, ax = build_case(decoration_case(DECORATION_CASES, "igh"))
    di = GM.decorations(ax)
    @test all(s -> s.reason in (:grazing, :convergent), filter(s -> s.family == :lon && s.value == 180.0 && s.kind == :frame, di.suppressed))
    @test !any(l -> !GM.isinterior(l) && l.exit.family == :lon && l.exit.value == 180.0, di.labels[di.pixels.kept])
    @test any(e -> e.family == :lon && e.value == 180.0 && e.angle < 1, di.exits)
end

@testset "axis positions" begin
    for (name, xpos, ypos) in (("merc_reg", :bottom, :left), ("merc_reg_top", :top, :left),
                               ("merc_reg_right", :bottom, :right), ("merc_reg_both", :both, :both))
        fig, ax = build_case(decoration_case(DECORATION_CASES, name))
        d = GM.decorations(ax)
        sides = Set(GM.edge_side(l.exit.normal) for l in d.labels[d.pixels.kept])
        wantx = xpos === :both ? Set([:bottom, :top]) : Set([xpos])
        wanty = ypos === :both ? Set([:left, :right]) : Set([ypos])
        @test sides == union(wantx, wanty)
        @test isempty(family_rule(name, d))
        # the protrusion bound only reserves the sides that carry labels
        b = d.bound
        @test (b.top > 0) == (:top in wantx) && (b.bottom > 0) == (:bottom in wantx)
        @test (b.right > 0) == (:right in wanty) && (b.left > 0) == (:left in wanty)
        # the rejected exits are in the report
        @test count(s -> s.reason == :family, d.suppressed) == length(d.exits) - length(d.labels)
    end
end

# ---- Phase 5: interior labels -------------------------------------------------

@testset "boxes against lines" begin
    b = GM.OBox(Point2d(0, 0), Vec2d(10, 5), 0.0)
    @test GM.segment_crosses_box(b, Point2d(-20, 0), Point2d(20, 0))
    @test !GM.segment_crosses_box(b, Point2d(-20, 6), Point2d(20, 6))
    @test GM.segment_crosses_box(b, Point2d(0, 0), Point2d(0, 0))          # a point inside
    @test GM.segment_crosses_box(b, Point2d(9, 4), Point2d(30, 30))        # one end inside
    # a rotated box: a segment inside the axis-aligned bounds but clear of the box
    r = GM.OBox(Point2d(0, 0), Vec2d(10, 2), pi / 4)
    @test !GM.segment_crosses_box(r, Point2d(-8, 8), Point2d(-4, 4))
    @test GM.segment_crosses_box(r, Point2d(-8, 8), Point2d(8, 8))         # clips the far corner at (5.7, 8.5)
    @test GM.segment_crosses_box(r, Point2d(-8, -8), Point2d(8, 8))
    pts = [Point2d(-20, 0), Point2d(-5, 0), Point2d(NaN, NaN), Point2d(5, 0), Point2d(20, 0)]
    @test GM.polyline_crosses_box(b, pts, GM._aabb(pts))                   # the second run enters the box
    far = [Point2d(-20, 10), Point2d(20, 10)]
    @test !GM.polyline_crosses_box(b, far, GM._aabb(far))
    square = [Point2d[Point2d(-50, -50), Point2d(50, -50), Point2d(50, 50), Point2d(-50, 50)]]
    @test GM.box_within_loops(b, square)
    @test !GM.box_within_loops(GM.OBox(Point2d(45, 0), Vec2d(10, 5), 0.0), square)   # straddles the edge
    @test !GM.box_within_loops(GM.OBox(Point2d(70, 0), Vec2d(10, 5), 0.0), square)   # outside
    hole = [square[1], Point2d[Point2d(-5, -5), Point2d(5, -5), Point2d(5, 5), Point2d(-5, 5)]]
    @test !GM.box_within_loops(b, hole)
    @test GM.box_within_loops(GM.OBox(Point2d(30, 30), Vec2d(5, 5), 0.0), hole)
end

@testset "clipping a polyline to a rectangle" begin
    rect = Rect2d(Vec2d(-1, -1), Vec2d(2, 2))
    # a cut at either end: the made points sit between the samples they came from
    runs = GM.clip_polyline_rect(Point2d[(-2, 0), (0, 0), (2, 0), (3, 0)], rect, 1e-9)
    @test length(runs) == 1
    r, sc, ec, i0, i1 = runs[1]
    @test r == Point2d[(-1, 0), (0, 0), (1, 0)] && sc && ec && i0 ≈ 1.5 && i1 ≈ 2.5
    # a NaN splits runs; a run's own ends are whole samples
    runs = GM.clip_polyline_rect(Point2d[(0, -0.5), (0, 0), (NaN, NaN), (0.5, 0), (0.5, 0.5)], rect, 1e-9)
    @test [(i0, i1) for (_, _, _, i0, i1) in runs] == [(1.0, 2.0), (4.0, 5.0)]
    @test all(!sc && !ec for (_, sc, ec, _, _) in runs)
    # a segment crossing the rect with both ends outside
    runs = GM.clip_polyline_rect(Point2d[(-3, 0), (3, 0)], rect, 1e-9)
    @test length(runs) == 1 && runs[1][4] ≈ 1 + 1 / 3 && runs[1][5] ≈ 1 + 2 / 3
end

@testset "interior placements" begin
    ends = [(GM.NO_SPHERE_POINT, GM.NO_SPHERE_POINT)]
    # a parallel crossing the carrier meridian below the pole: the carrier runs
    # up (+y), the parallel runs right (+x)
    x = GM.CarrierCrossing(:lat, 45.0, 0.0, Point2d(0, -50), Vec2d(0, 1), Vec2d(1, 0))
    line = GM.GraticuleLine(:lat, 45.0, [Point2d[(-100, -50), (100, -50)]], [false], ends)
    half = Vec2d(10, 5)
    # on the line, a hair past the pad plus its own half width, reading along it
    b, t = GM.interior_box(x, 1, half, 2.0, Makie.automatic, line)
    @test b.centre ≈ Point2d(12.06, -50) && b.θ == 0 && t == Vec2d(1, 0)
    b2, _ = GM.interior_box(x, -1, half, 2.0, Makie.automatic, line)
    @test b2.centre ≈ Point2d(-12.06, -50)
    b3, _ = GM.interior_box(x, 1, half, 2.0, Makie.automatic, line; reach = 2.0)
    @test b3.centre ≈ Point2d(24.12, -50)
    @test GM.interior_box(x, 1, half, 2.0, Makie.automatic, line; reach = 20.0) === nothing   # the line ends first
    # shifted off the line, flush against it on either side
    bs, _ = GM.interior_box(x, 1, half, 2.0, Makie.automatic, line; shift = 1)
    @test bs.centre ≈ Point2d(12.06, -55.4)
    bs2, _ = GM.interior_box(x, 1, half, 2.0, Makie.automatic, line; shift = -1)
    @test bs2.centre ≈ Point2d(12.06, -44.6)
    # a vertical line reads bottom to top; a fixed rotation is used as given
    xm = GM.CarrierCrossing(:lon, 30.0, 0.0, Point2d(20, 0), Vec2d(1, 0), Vec2d(0, 1))
    vline = GM.GraticuleLine(:lon, 30.0, [Point2d[(20, -100), (20, 100)]], [false], ends)
    bv, _ = GM.interior_box(xm, 1, half, 2.0, Makie.automatic, vline)
    @test bv.θ == pi / 2 && bv.centre ≈ Point2d(20, 12.06)
    bd, _ = GM.interior_box(xm, -1, half, 2.0, Makie.automatic, vline)
    @test bd.θ == pi / 2 && bd.centre ≈ Point2d(20, -12.06)
    bf, _ = GM.interior_box(xm, 1, half, 2.0, 0.3, vline)
    @test bf.θ == 0.3
    # an oblique crossing walks further so the box still clears the carrier; too oblique is refused
    xo = GM.CarrierCrossing(:lat, 45.0, 0.0, Point2d(0, -50), Vec2d(sind(45), cosd(45)), Vec2d(1, 0))
    bo, _ = GM.interior_box(xo, 1, half, 2.0, Makie.automatic, line)
    @test bo.centre[1] ≈ (2.06 + GM.half_extent(GM.OBox(Point2d(0, 0), half, 0.0), Vec2d(cosd(45), -sind(45)))) / sind(45)
    xg = GM.CarrierCrossing(:lat, 45.0, 0.0, Point2d(0, -50), Vec2d(cosd(5), sind(5)), Vec2d(1, 0))
    @test GM.interior_box(xg, 1, half, 2.0, Makie.automatic, line) === nothing
    # a curved line: the box stays on the circle and follows the tangent where it sits
    circle = [Point2d(50 * sind(a), -50 * cosd(a)) for a in 0:5:355]
    cline = GM.GraticuleLine(:lat, 45.0, [circle], [true], ends)
    bc, tc = GM.interior_box(x, 1, half, 2.0, Makie.automatic, cline)
    @test abs(norm(bc.centre) - 50) < 0.5
    @test bc.θ ≈ atan(tc[2], tc[1]) && deg2rad(10) < bc.θ < deg2rad(20)
    @test GM.along_line(cline, Point2d(0, -50), Vec2d(1, 0), 50 * pi / 2) ≢ nothing
    q, _ = GM.along_line(cline, Point2d(0, -50), Vec2d(1, 0), 50 * pi / 2)
    @test q ≈ Point2d(50, 0) atol = 1
    @test GM.along_line(line, Point2d(0, -50), Vec2d(1, 0), 150) === nothing
    # upright rotations: (-90°, 90°], vertical up to rounding reads bottom to top
    @test GM.upright_rotation(pi / 2) == pi / 2 && GM.upright_rotation(-pi / 2) == pi / 2
    @test GM.upright_rotation(-pi / 2 + 1e-4) == pi / 2 && GM.upright_rotation(pi / 2 - 1e-4) == pi / 2
    @test GM.upright_rotation(pi / 4) ≈ pi / 4 && GM.upright_rotation(3pi / 4) ≈ -pi / 4 && GM.upright_rotation(-pi / 4) ≈ -pi / 4
    @test GM.tangent_rotation(Vec2d(-1, 0)) == 0 && GM.tangent_rotation(Vec2d(-1, -1)) ≈ pi / 4
    @test GM.INTERIOR_DIRECTIONS == (1, -1) && GM.INTERIOR_PLACEMENTS[1] == (1.0, 0)
    # the carriers: the drawn meridian nearest the central one, parallels outermost first, south before north
    lc = GM.label_carriers([180.0, -135.0, -90.0, -45.0, 0.0, 45.0, 90.0, 135.0], [-60.0, -30.0, 0.0, 30.0, 60.0, 90.0], 10.0, 0.0, Makie.automatic, Makie.automatic)
    @test lc.meridian == 0.0
    @test lc.parallels == [-60.0, 60.0, -30.0, 30.0, 0.0]
    @test GM.label_carriers([0.0, 90.0], [0.0], 170.0, 0.0, Makie.automatic, Makie.automatic).meridian == 90.0   # wrap-aware
    @test GM.label_carriers(Float64[], Float64[], 12.0, 3.0, Makie.automatic, Makie.automatic) == (; meridian = 12.0, parallels = [3.0])
    @test GM.label_carriers([0.0], [0.0], 0.0, 0.0, 90, -30) == (; meridian = 90.0, parallels = [-30.0])
end

@testset "interior candidates on an axis" begin
    # closed parallels: one candidate each, the frame record still names the missing exit
    fig, ax = build_case(decoration_case(DECORATION_CASES, "laea_polar_nolimits"))
    d = GM.decorations(ax)
    ints = filter(GM.isinterior, d.labels)
    @test Set(l.exit.value for l in ints) == Set(l.value for l in d.graticule if l.family == :lat)
    @test all(l -> l.exit.tag == :interior && l.exit.family == :lat && isnan(l.offset) == false && l.offset == ax.yticklabelpad[], ints)
    @test all(l -> l.priority[2] == 0.0, ints)
    # (the pole tick at 90° has no exit either, and no line to label)
    @test Set(s.value for s in d.suppressed if s.kind == :frame && s.reason == :noexit && s.family == :lat) ⊇ Set(l.exit.value for l in ints)
    # every crossing sits on the carrier meridian at its parallel
    for x in d.crossings.lat
        ll = Makie.apply_transform(Makie.inverse_transform(d.transform), x.p)
        @test abs(ll[1] - x.carrier) < 1e-6 && abs(ll[2] - x.value) < 1e-6
        @test norm(x.ctangent) ≈ 1 && norm(x.ltangent) ≈ 1
    end
    # meridians converging to a pole point: the candidate parallels are the drawn ones
    fig, ax = build_case(decoration_case(DECORATION_CASES, "moll"))
    d = GM.decorations(ax)
    @test first.(d.crossings.lon) == [-45.0, 45.0, 0.0]
    @test all(xs -> length(xs[2]) == length(d.xtickvalues.values), d.crossings.lon)
    ints = filter(GM.isinterior, d.labels)
    @test length(ints) == length(d.xtickvalues.values)
    # the report names an interior label that finds no place
    fig, ax = build_case(decoration_case(DECORATION_CASES, "moll"); yticklabelsize = 60.0, xticklabelsize = 60.0, ticklabelcollisions = false)
    d = GM.decorations(ax)
    sup = [s for s in d.suppressed if s.kind == :interior]
    if !isempty(sup)
        @test all(s -> s.reason in (:crossed, :outside, :collision, :nocrossing), sup)
        msg = GM.suppression_report(d.suppressed, 2.0, 20.0)
        any(s -> s.reason in (:crossed, :outside), sup) && @test occursin("interior labels skipped", msg)
    end
end
