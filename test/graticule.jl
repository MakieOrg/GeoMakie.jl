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
    # Finer than the ladder reaches: a tick finder takes over rather than
    # leaving the axis with one tick.
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
