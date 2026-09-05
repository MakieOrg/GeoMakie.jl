# ticks.jl -- the geographic tick finders on their own: ladder walk, floor,
# per-direction interval, exactness, longitude wrap, formatters.

@testset "ladder walk" begin
    f = GeographicTicks(; target_em = 3.0)
    # a label wants target_em * fontsize pixels; 360° over 2000 px at 16 px asks
    # for 8.64° per label, so the ladder gives 10
    @test GM.interval(f, 360, 2000, 16) == 10.0
    # less room and the ladder walks coarser, never to a value off the ladder
    @test GM.interval(f, 360, 1000, 16) == 30.0
    @test GM.interval(f, 360, 500, 16) == 45.0
    @test GM.interval(f, 360, 200, 16) == 90.0
    @test GM.interval(f, 360, 10, 16) == 90.0            # never coarser than the ladder top
    # the default asks for 3.5 ems
    g = GeographicTicks()
    @test g.target_em == 3.5
    @test GM.interval(g, 360, 2000, 16) == 15.0
    for px in (50, 137, 400, 999, 3000, 12345)
        @test GM.interval(f, 360, px, 16) in f.ladder
        @test GM.interval(f, 7.3, px, 16) in f.ladder
    end
    # a finer ladder step is chosen only when every label still has its room
    step = GM.interval(f, 50, 600, 16)
    @test step in f.ladder
    @test 50 / step * f.target_em * 16 <= 600 + 1e-9
end

@testset "floor" begin
    f = GeographicTicks()
    # 3° of span with almost no room would ask for 90°; the floor walks the
    # ladder finer until at least `floor` lines fit, giving exactly 0,1,2,3
    @test GM.interval(f, 3, 60, 16) == 1.0
    vals, _ = GM.tickvalues(f, (0, 3), 60, 16)
    @test vals == [0.0, 1.0, 2.0, 3.0]
    # the floor counts lines with a fuzz, so a span a rounding error short of
    # 3° still gets the 1° step and its end multiple
    vals, _ = GM.tickvalues(f, (0, 2.9999999999999956), 300, 16)
    @test vals == [0.0, 1.0, 2.0, 3.0]
    f2 = GeographicTicks(; floor = 5)
    vals, _ = GM.tickvalues(f2, (0, 3), 60, 16)
    @test length(vals) >= 5
end

@testset "per-direction interval" begin
    f = GeographicTicks()
    # the same span gets a finer step along the longer carrier
    lon_step = GM.interval(f, 40, 800, 16)
    lat_step = GM.interval(f, 40, 200, 16)
    @test lon_step < lat_step
    # and a larger font coarsens
    @test GM.interval(f, 40, 800, 32) >= lon_step
end

@testset "a:s:b exactness" begin
    f = GeographicTicks()
    vals, minors = GM.tickvalues(f, (10, 12), 1400, 16)
    @test vals == collect(10.0:0.1:12.0)          # exact decimals, not 10.100000000000001
    @test all(v -> v == round(v; digits = 9), vals)
    @test first(vals) == 10.0 && last(vals) == 12.0
    @test all(m -> !(m in vals), minors)
    vals, _ = GM.tickvalues(f, (-10, 30), 400, 16)
    @test vals == [-10.0, 0.0, 10.0, 20.0, 30.0]
    # the extent's endpoints are included only when they are multiples
    vals, _ = GM.tickvalues(f, (-9.5, 30.5), 400, 16)
    @test vals == [0.0, 10.0, 20.0, 30.0]
    @test GM.ladder_multiples(0.2, 45, 46) == [45.0, 45.2, 45.4, 45.6, 45.8, 46.0]
end

@testset "(-180, 180] wrap" begin
    f = GeographicTicks()
    # a full turn yields one value per meridian, 180 once, never -180
    vals, _ = GM.tickvalues(f, (-180, 180), 600, 16; wrap = true)
    @test 180.0 in vals && !(-180.0 in vals)
    @test length(vals) == length(unique(vals)) == 360 / GM.interval(f, 360, 600, 16)
    @test all(v -> -180 < v <= 180, vals)
    # an extent past the antimeridian wraps its values
    vals, _ = GM.tickvalues(f, (150, 210), 600, 16; wrap = true)
    @test all(v -> -180 < v <= 180, vals)
    @test 180.0 in vals && -170.0 in vals && 160.0 in vals
    @test GM.wrap_longitude(-180) == 180.0 && GM.wrap_longitude(540) == 180.0 && GM.wrap_longitude(190) == -170.0
end

@testset "other tick specifications" begin
    vals, minors = GM.tickvalues(-180:2:180, (-10, 30), 400, 16)
    @test vals == collect(-180.0:2:180) && minors === nothing
    vals, _ = GM.tickvalues([0, 10, 20], (-10, 30), 400, 16)
    @test vals == [0.0, 10.0, 20.0]
    vals, _ = GM.tickvalues(([0, 10], ["a", "b"]), (-10, 30), 400, 16)
    @test vals == [0.0, 10.0]
    @test GM.ticklabels_of(([0, 10], ["a", "b"])) == ["a", "b"]
    @test_throws ErrorException GM.tickvalues(([0, 10], ["a"]), (-10, 30), 400, 16)
    vals, _ = GM.tickvalues(Makie.WilkinsonTicks(5), (-10, 30), 400, 16)
    @test !isempty(vals) && all(v -> -10 <= v <= 30, vals)
    # the finders serve Makie's own interface too
    @test Makie.get_tickvalues(GeographicTicks(), -10, 30) == [-10.0, -5.0, 0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0]
end

@testset "formatters" begin
    @test GM.longitude_format([-110, 0, 180, 45.5, -180]) == ["110°W", "0°", "180°", "45.5°E", "180°"]
    @test GM.latitude_format([-45, 0, 90, 58.5]) == ["45°S", "0°", "90°N", "58.5°N"]
    @test GM.longitude_format([-0.0]) == ["0°"]
    @test GM.longitude_format([10.1, 10.2, 10.3]) == ["10.1°E", "10.2°E", "10.3°E"]
    @test GM.short_decimal(0.1 + 0.2) == "0.3"
    # the axis' default when tickformat is automatic; a user format wins
    @test GM.format_tickvalues(Makie.automatic, GeographicTicks(), :lon, [0, 10], nothing) == ["0°", "10°E"]
    @test GM.format_tickvalues(v -> ["x$(x)" for x in v], GeographicTicks(), :lon, [0.0, 10.0], nothing) == ["x0.0", "x10.0"]
    @test GM.format_tickvalues("{:.1f}", GeographicTicks(), :lon, [0.0, 10.0], nothing) == ["0.0", "10.0"]
    @test GM.format_tickvalues(Makie.automatic, GeographicTicks(), :lon, [0, 10], ["a", "b"]) == ["a", "b"]
end

@testset "ArcMinuteTicks" begin
    f = ArcMinuteTicks()
    @test f.ladder[9] == 30 / 60 && f.ladder[end] == 1 / 3600
    step = GM.interval(f, 1, 800, 16)                 # a degree over 800 px: minutes
    @test step in f.ladder && step < 1
    vals, _ = GM.tickvalues(f, (10, 11), 800, 16)
    @test first(vals) == 10.0 && last(vals) == 11.0
    @test GM.longitude_dms_format([10.5, -10.25, 0, 10 + 1 / 60]) == ["10°30′E", "10°15′W", "0°", "10°1′E"]
    @test GM.latitude_dms_format([45, 45 + 30 / 3600]) == ["45°N", "45°0′30″N"]
    @test GM.format_tickvalues(Makie.automatic, f, :lon, [10.5], nothing) == ["10°30′E"]
    @test GM.format_tickvalues(Makie.automatic, f, :lat, [-0.5], nothing) == ["0°30′S"]
end

@testset "minors" begin
    f = GeographicTicks()
    # every ladder step carries a paired minor step that divides it
    for step in f.ladder
        @test haskey(f.minors, step)
        m = f.minors[step]
        @test m < step && abs(step / m - round(step / m)) < 1e-9
    end
    # the paired minors fill the extent between and beyond the majors, never on one
    vals, minors = GM.tickvalues(f, (-10, 30), 400, 16)
    @test vals == [-10.0, 0.0, 10.0, 20.0, 30.0]
    @test minors == [-8.0, -6.0, -4.0, -2.0, 2.0, 4.0, 6.0, 8.0, 12.0, 14.0, 16.0, 18.0, 22.0, 24.0, 26.0, 28.0]
    @test isempty(intersect(vals, minors))
    vals, minors = GM.tickvalues(f, (-9.5, 30.5), 400, 16)
    @test vals == [0.0, 10.0, 20.0, 30.0] && first(minors) == -8.0 && last(minors) == 28.0
    # a full turn: one minor per position, 180 once (as a major), never -180
    vals, minors = GM.tickvalues(f, (-180, 180), 600, 16; wrap = true)
    @test all(v -> -180 < v <= 180, minors) && isempty(intersect(vals, minors))
    @test length(minors) == length(unique(minors))
    @test 180.0 in vals && !(180.0 in minors) && !(-180.0 in minors)
    # `automatic` takes the paired minors; a finder without any gives none
    @test GM.minor_tickvalues(Makie.automatic, minors, vals, (-180, 180); wrap = true) == minors
    @test GM.minor_tickvalues(Makie.automatic, nothing, [0.0, 10.0], (0, 10)) == Float64[]
    # IntervalsBetween on user majors: Makie's values, mirrored past the ends, none on a major
    m = GM.minor_tickvalues(IntervalsBetween(2), nothing, [0.0, 10.0, 20.0], (-5, 25))
    @test m == [-5.0, 5.0, 15.0, 25.0]
    m = GM.minor_tickvalues(IntervalsBetween(5, false), nothing, [0.0, 10.0], (0, 10))
    @test m == [2.0, 4.0, 6.0, 8.0]
    # a vector of values is used as given, minus the majors and what lies outside the extent
    @test GM.minor_tickvalues([2.5, 5.0, 10.0, 12.5], nothing, [0.0, 10.0], (0, 11)) == [2.5, 5.0]
    # the arc-minute ladder pairs minutes with minutes
    a = ArcMinuteTicks()
    @test a.minors[30 / 60] == 10 / 60 && a.minors[1.0] == 30 / 60
    vals, minors = GM.tickvalues(a, (10, 11), 800, 16)
    @test !isempty(minors) && isempty(intersect(vals, minors)) && all(v -> 10 <= v <= 11, minors)
end
