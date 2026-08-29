using LinearAlgebra

# The pure functions behind a graticule: which interval it takes, which of its
# ends may be annotated, and where it stops around a pole.  Nothing here draws.

@testset "Geographic ladder" begin
    # The pairing is a table: no divisor takes 15 to 5 and 10 to 2.
    @test GeoMakie.GEOGRAPHIC_LADDER == ((2, 1), (5, 1), (10, 2), (15, 5), (30, 10), (60, 15), (90, 30))
    @test length(GeoMakie.GEOGRAPHIC_INTERVALS) == 21
    @test issorted(GeoMakie.GEOGRAPHIC_INTERVALS; by = first)
    @test all(pair -> 0 < pair[2] < pair[1], GeoMakie.GEOGRAPHIC_INTERVALS)

    @test GeoMakie.geographic_interval(22.5) == (major = 30.0, minor = 10.0)
    @test GeoMakie.geographic_interval(15) == (major = 15.0, minor = 5.0)
    @test GeoMakie.geographic_interval(10) == (major = 10.0, minor = 2.0)
    # Minutes and seconds are rungs of the same ladder.
    @test GeoMakie.geographic_interval(0.4) == (major = 30 / 60, minor = 10 / 60)
    @test GeoMakie.geographic_interval(1.0e-9) == (major = 2 / 3600, minor = 1 / 3600)
    # Past either end, and where there is nothing to measure.
    @test GeoMakie.geographic_interval(1000).major == 90.0
    @test GeoMakie.geographic_interval(NaN).major == 90.0
    @test GeoMakie.geographic_interval(Inf).major == 90.0

    # The other way up the ladder: no coarser than the limit.
    @test GeoMakie.geographic_interval_below(22.5) == (major = 15.0, minor = 5.0)
    @test GeoMakie.geographic_interval_below(15) == (major = 15.0, minor = 5.0)
    @test GeoMakie.geographic_interval_below(1000).major == 90.0
    @test GeoMakie.geographic_interval_below(1.0e-9).major == 2 / 3600
    @test GeoMakie.geographic_interval_below(NaN).major == 2 / 3600
end

@testset "Typographic interval" begin
    @test GeoMakie.typographic_interval(360, 720, 56) == 28.0
    @test GeoMakie.typographic_interval(-360, 720, 56) == 28.0
    # No room to measure against asks for the coarsest interval there is.
    @test GeoMakie.typographic_interval(360, 0, 56) == Inf
    @test GeoMakie.typographic_interval(360, NaN, 56) == Inf

    # A world map at the default font: thirty degrees, the graticule GMT draws.
    @test GeoMakie.graticule_interval(360, 180, 720, 440, 16, 16).major == 30.0
    # More room, finer graticule.
    @test GeoMakie.graticule_interval(360, 180, 2880, 1760, 16, 16).major < 30.0
    # A larger font asks for fewer labels.
    @test GeoMakie.graticule_interval(360, 180, 720, 440, 32, 32).major >= 30.0
    # X and Y share one interval: the direction with less room decides.  Here
    # that is X, at a quarter of the width for the same span.
    @test GeoMakie.graticule_interval(100, 100, 200, 800, 16, 16) ==
        GeoMakie.geographic_interval(100 * 56 / 200)

    # A polar view is a whole turn of longitude across fifty degrees of latitude:
    # equalizing on the turn alone would leave one parallel.
    polar = GeoMakie.graticule_interval(360, 55, 524, 524, 16, 16)
    @test polar.major <= 55 / GeoMakie.MIN_GRATICULE_LINES
end

@testset "Graticule tick values" begin
    @test GeoMakie.graticule_tickvalues(-180, 180, 30.0) == collect(-180.0:30.0:180.0)
    @test GeoMakie.graticule_tickvalues(180, -180, 30.0) == collect(-180.0:30.0:180.0)
    @test GeoMakie.graticule_tickvalues(-122.6, -122.2, 0.1) ≈ collect(-122.6:0.1:-122.2)
    # Finer than the ladder reaches: the fallback tick finder supplies the ticks.
    @test length(GeoMakie.graticule_tickvalues(0, 1.0e-5, 2 / 3600)) >= 2
    @test isempty(GeoMakie.graticule_tickvalues(NaN, 1, 30.0))
    # An interval of zero is how the axis asks for the fallback, for a view
    # finer than `LADDER_DEGREE_FLOOR`.
    @test length(GeoMakie.graticule_tickvalues(-122.6, -122.2, 0.0)) >= 3
    @test all(v -> -122.6 <= v <= -122.2, GeoMakie.graticule_tickvalues(-122.6, -122.2, 0.0))

    # Traced on the turn the map was cut on, labelled on the turn it is read on.
    @test GeoMakie.wrap_longitudes([-420.0, -390.0, -180.0, 0.0, 180.0]) ==
        [-60.0, -30.0, -180.0, 0.0, 180.0]
    @test GeoMakie.wrap_longitudes([200.0, 285.0]) == [-160.0, -75.0]
end

@testset "Degenerate poles" begin
    @test GeoMakie.proj_name("+proj=moll +lon_0=0") == "moll"
    @test GeoMakie.proj_name("EPSG:4326") == ""
    @test GeoMakie.proj_name(GeoMakie.GeoFormatTypes.ProjString("+proj=eck4")) == "eck4"

    @test GeoMakie.graticule_latitude_limit("+proj=moll") == 60.0
    @test GeoMakie.graticule_latitude_limit("+proj=eck4 +lon_0=150") == 60.0
    @test GeoMakie.graticule_latitude_limit("+proj=eqearth") == 90.0
    @test GeoMakie.graticule_latitude_limit(GeoMakie.GeoFormatTypes.EPSG(4326)) == 90.0

    @test GeoMakie.limit_graticule_latitudes(collect(-90.0:15.0:90.0), 60.0) ==
        collect(-60.0:15.0:60.0)
    # Zoomed above the limit there is nothing else to draw, and it gives way.
    @test GeoMakie.limit_graticule_latitudes([70.0, 75.0, 80.0], 60.0) == [70.0, 75.0, 80.0]
end

@testset "Grazing incidence" begin
    graze(line, edge) = (dir = Point2d(line), intersect_dir = Point2d(edge))
    at(degrees) = graze((cosd(degrees), sind(degrees)), (1, 0))

    @test GeoMakie.boundary_incidence(at(90)) ≈ pi / 2
    @test GeoMakie.boundary_incidence(at(0)) ≈ 0 atol = 1.0e-12
    # A line has no sense of direction: the reversed graticule meets the
    # boundary at the same angle.
    @test GeoMakie.boundary_incidence(at(170)) ≈ GeoMakie.boundary_incidence(at(10))

    @test GeoMakie.grazes_boundary(at(10), deg2rad(20))
    @test !GeoMakie.grazes_boundary(at(30), deg2rad(20))
    @test !GeoMakie.grazes_boundary(at(10), 0.0)
    # An end on a limb carries the boundary's normal rather than the graticule's
    # direction, and reports the right angle that exempts it.
    @test GeoMakie.boundary_incidence(graze((0, 1), (1, 0))) ≈ pi / 2
    # An unknown incidence is not evidence, and the label stays.
    @test isnothing(GeoMakie.boundary_incidence(graze((0, 0), (1, 0))))
    @test !GeoMakie.grazes_boundary(graze((1, 0), (0, 0)), deg2rad(20))
end

@testset "Suppression is reported" begin
    none = ("longitude" => GeoMakie.NO_TICKLABELS_DROPPED,)
    @test isnothing(GeoMakie.ticklabel_suppression_message(none; mingap = 2.0, minangle = 20.0))

    crowded = GeoMakie.ticklabel_suppression_message(
        ("longitude" => (crowding = 2, grazing = 0),
         "latitude" => (crowding = 1, grazing = 0)); mingap = 2.0, minangle = 20.0)
    @test crowded ==
        "2 longitude and 1 latitude annotations skipped due to crowding; " *
        "controlled by `ticklabelmingap`, currently 2.0 px."

    both = GeoMakie.ticklabel_suppression_message(
        ("longitude" => (crowding = 0, grazing = 1),
         "latitude" => (crowding = 3, grazing = 0)); mingap = 4.0, minangle = 25.0)
    @test occursin("3 latitude annotations skipped due to crowding", both)
    @test occursin("`ticklabelmingap`, currently 4.0 px", both)
    @test occursin("1 longitude annotation skipped due to grazing incidence", both)
    @test occursin("`ticklabelminangle`, currently 25.0 degrees", both)

    # Reported once, not on every redraw.
    reported = Ref{Union{Nothing,String}}(nothing)
    GeoMakie.report_ticklabel_suppression!(reported, crowded, false)
    @test reported[] == crowded
    GeoMakie.report_ticklabel_suppression!(reported, nothing, false)
    @test isnothing(reported[])
end

@testset "Polar cap" begin
    @test GeoMakie.polar_cap_meridian(0.0)
    @test GeoMakie.polar_cap_meridian(-180.0)
    @test GeoMakie.polar_cap_meridian(90.0)
    @test !GeoMakie.polar_cap_meridian(30.0)

    @test GeoMakie.polar_cap_range((-90.0, 90.0), [90.0], 85.0) == (-90.0, 85.0)
    @test GeoMakie.polar_cap_range((-90.0, 90.0), [-90.0, 90.0], 85.0) == (-85.0, 85.0)
    @test GeoMakie.polar_cap_range((-90.0, 90.0), Float64[], 85.0) == (-90.0, 90.0)
    @test GeoMakie.polar_cap_range((-90.0, 90.0), [90.0], nothing) == (-90.0, 90.0)
    # A view wholly inside the cap keeps its meridians.
    @test GeoMakie.polar_cap_range((86.0, 90.0), [90.0], 85.0) == (86.0, 90.0)

    @test GeoMakie.polar_cap_parallels((-90.0, 90.0), [90.0], 85.0) == [85.0]
    @test GeoMakie.polar_cap_parallels((-90.0, 90.0), [-90.0, 90.0], 85.0) == [-85.0, 85.0]
    @test isempty(GeoMakie.polar_cap_parallels((0.0, 80.0), [90.0], 85.0))
    @test isempty(GeoMakie.polar_cap_parallels((-90.0, 90.0), [90.0], nothing))

    # Drawing all the way round a pole is what makes it interior; a pole on the
    # boundary has drawing on one side of it only.
    enclosed(p) = norm(Point2d(p) - Point2d(0, 90)) <= 5
    edged(p) = enclosed(p) && p[2] <= 90
    @test GeoMakie.interior_poles(identity, enclosed, 1.0) == [90.0]
    @test isempty(GeoMakie.interior_poles(identity, edged, 1.0))
    @test isempty(GeoMakie.interior_poles(identity, p -> false, 1.0))
end
