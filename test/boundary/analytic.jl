# The analytic table, scored against the oracle on the case battery.

@testset "constants" begin
    @test GM.MERCATOR_BAND_DEG ≈ 85.0511287798066
    @test GM.CONIC_CUTOFF_DEG == 30.0
    @test GM.TMERC_CUTOFF_DEG == 10.0
    @test GM.ROOT_MERGE == 1e-7
    @test GM.MIN_PIECE == 1e-6
    @test GM.INSET_CAP_DEG == 0.1
    @test GM.SEAM_EPS == 1e-4
    @test GM.CHAIN_TOL == 5e-3
end

@testset "table" begin
    for tok in (:robin, :moll, :eqearth, :wintri, :eqc, :eck4, :wag4, :sinu, :hammer)
        @test haskey(GM.PROJ_TOKENS, tok)
        @test GM.PROJ_TOKENS[tok][2] == :lon0
    end
    for tok in (:ortho, :laea, :aeqd, :stere, :geos, :nsper)
        @test GM.PROJ_TOKENS[tok][2] == :centre
    end
    @test !haskey(GM.PROJ_TOKENS, :gnom)
    tm = GM.analytic_region(GM.parse_proj_string("+proj=utm +zone=33"))
    @test tm isa GM.Intersection
    @test contains(tm, GM.lonlat_to_xyz(15, 50))
    @test !contains(tm, GM.lonlat_to_xyz(105, 0))          # 90 deg east of 15
    @test GM.analytic_region(GM.parse_proj_string("+proj=longlat")) |> GM.isfullsphere
    @test GM.analytic_region(GM.parse_proj_string("+proj=nonexistent")) === nothing
    @test GM.analytic_region(nothing) === nothing
    ob = GM.analytic_region(GM.parse_proj_string("+proj=ob_tran +o_proj=eqc +o_lat_p=35 +o_lon_p=0 +lon_0=20"))
    @test ob isa GM.Wedge && ob.tag == :cut
    @test GM.analytic_region(GM.parse_proj_string("+proj=ob_tran +o_proj=nonexistent")) === nothing
end

# Per-case floors.  Policy rows exclude regions the oracle accepts on purpose
# (merc's polar caps, the conic cutoff, stere's far cap); everything else must
# agree with the oracle away from the rim.
const CONTAINS_FLOOR = Dict(:merc => 0.99, :lcc => 0.70, :stere_n => 0.90)
const COVERAGE_FLOOR = Dict(:merc => 0.9, :lcc => 0.6, :stere_n => 0.85, :tmerc => 0.9)

@testset "battery" begin
    for case in CASES
        id = GM.identify(case.t)
        region = GM.analytic_region(id)
        @test region !== nothing
        region === nothing && continue
        s = score_case(region, case)
        @testset "$(case.name)" begin
            @test s.contains_agree >= get(CONTAINS_FLOOR, case.name, 0.97)
            @test s.worst_false_inside <= 0.05
            @test s.clip_finite >= 0.999
            @test s.clip_coverage >= get(COVERAGE_FLOOR, case.name, 0.9)
            @test isnan(s.rim_onmap) || s.rim_onmap >= 0.99
        end
    end
end
