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
    # also a pole point, and is never labelled
    fig, ax = build_case(decoration_case(DECORATION_CASES, "igh"))
    di = GM.decorations(ax)
    @test all(s -> s.reason in (:grazing, :convergent), filter(s -> s.family == :lon && s.value == 180.0, di.suppressed))
    @test !any(l -> l.exit.family == :lon && l.exit.value == 180.0, di.labels[di.pixels.kept])
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
