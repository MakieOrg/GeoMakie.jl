# The probe: sound, silent, and good enough on everything the table does not know.

"""
Points claimed inside `region` that the oracle rejects, and the agreement rate.
The probe places its rim on the oracle's own round-trip contour, so a claim is
only counted false when the round trip misses by ten times that tolerance.
"""
function soundness(region, t; n = 2000)
    pts = GM.fibonacci_sphere(n)
    false_inside = 0; agree = 0
    for p in pts
        mine = contains(region, p)
        truth = onmap(t, p)
        (mine && !onmap(t, p; tol_deg = 10 * ORACLE_TOL_DEG)) && (false_inside += 1)
        agree += (mine == truth)
    end
    return (false_inside, agree / n)
end

@testset "probe recovers a cap" begin
    ortho = case_by_name(:ortho)
    r = @test_nowarn GM.probe(ortho.t)
    @test r isa GM.SpherePolygon
    fi, agree = soundness(r, ortho.t)
    @test fi <= 1
    @test agree >= 0.99
    cap = GM.analytic_region(GM.identify(ortho.t))
    pts = GM.fibonacci_sphere(3000)
    @test count(p -> contains(r, p) == contains(cap, p), pts) / length(pts) >= 0.99
end

@testset "probe is sound on tmerc" begin
    tm = case_by_name(:tmerc)
    r = @test_nowarn GM.probe(tm.t)
    fi, agree = soundness(r, tm.t)
    @test fi <= 1
end

@testset "probe answers everywhere and nowhere" begin
    t = GM.create_transform("+proj=longlat +datum=WGS84", "+proj=longlat +datum=WGS84")
    @test GM.isfullsphere(@test_nowarn GM.probe(t))
    @test GM.isfullsphere(@test_nowarn GM.probe(identity))
end

@testset "most_projections" begin
    ok = 0
    open0 = GM.CHAIN_OPEN[]
    for dest in MOST_PROJECTIONS
        t = try
            GM.create_transform(dest, "+proj=longlat +datum=WGS84")
        catch
            continue
        end
        r = @test_nowarn GM.boundary(t, dest)
        @test r isa GM.SphereRegion
        # soundness is only measurable where PROJ has an inverse to round-trip
        # through; PROJ's approximate inverses (cass) misplace a few points by
        # more than the slack, so a percent of the sample is allowed
        if any(p -> onmap(t, p), GM.fibonacci_sphere(50))
            fi, _ = soundness(r, t; n = 1000)
            @test fi <= 10
        end
        if !GM.isfullsphere(r)
            rl = @test_nowarn GM.project_rim(r, t)
            @test rl.bbox === nothing || all(isfinite, minimum(rl.bbox)) && all(isfinite, widths(rl.bbox))
        end
        ok += 1
    end
    @test ok >= 28
    @test GM.CHAIN_OPEN[] == open0
end
