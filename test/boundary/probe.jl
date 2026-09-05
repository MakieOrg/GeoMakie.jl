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

# PROJ hands back an inverse for forward-only projections that answers Inf
# everywhere, so nothing round-trips even though the forward is finite.
function forward_only(t; n = 50)
    pts = GM.fibonacci_sphere(n)
    return !any(p -> onmap(t, p), pts) && any(p -> GM._finite2(GM._project_xyz(t, p)), pts)
end

"Points claimed inside `region` whose forward is not finite."
function false_finite(region, t; n = 2000)
    return count(p -> contains(region, p) && !GM._finite2(GM._project_xyz(t, p)), GM.fibonacci_sphere(n))
end

"Every arc of a probed polygon starts where the previous one ended."
function rim_closed(r::GM.SpherePolygon; tol = 1e-9)
    arcs = r.rim
    return all(eachindex(arcs)) do i
        a, b = arcs[i], arcs[mod1(i + 1, length(arcs))]
        GM.angular_distance(GM.arcpoint(a, a.t1), GM.arcpoint(b, b.t0)) < tol
    end
end

@testset "probe reads a forward-only hemisphere" begin
    dest = "+proj=airy"
    t = GM.create_transform(dest, "+proj=longlat +datum=WGS84")
    @test forward_only(t)
    r = @test_nowarn GM.probe(t)
    @test r isa GM.SpherePolygon
    @test rim_closed(r)
    @test GM.angular_distance(r.inside, GM.XHAT) < 1e-9
    rimpts = reduce(vcat, [GM.sample(piece.arc, 8) for piece in GM.rim(r)])
    @test maximum(q -> abs(rad2deg(GM.angular_distance(q, GM.XHAT)) - 90), rimpts) < 0.01
    @test false_finite(r, t) == 0
    cap = GM.Cap(90.0)
    pts = GM.fibonacci_sphere(3000)
    @test count(p -> contains(r, p) == contains(cap, p), pts) / length(pts) >= 0.99
    # the table knows airy as the same cap, whatever +lat_b says
    @test GM.boundary(t, dest) isa GM.Zone
    @test all(p -> contains(GM.boundary(t, dest), p) == contains(cap, p), pts)
    dest_o = "+proj=airy +lat_0=45 +lon_0=10 +lat_b=40"
    to = GM.create_transform(dest_o, "+proj=longlat +datum=WGS84")
    bo = GM.boundary(to, dest_o)
    centre = GM.lonlat_to_xyz(10, 45)
    @test contains(bo, centre) && !contains(bo, -centre)
    @test false_finite(bo, to) == 0
    @test count(p -> contains(bo, p) == GM._finite2(GM._project_xyz(to, p)), pts) / length(pts) >= 0.995
end

@testset "probe answers everywhere and nowhere" begin
    t = GM.create_transform("+proj=longlat +datum=WGS84", "+proj=longlat +datum=WGS84")
    @test GM.isfullsphere(@test_nowarn GM.probe(t))
    @test GM.isfullsphere(@test_nowarn GM.probe(identity))
end

@testset "most_projections" begin
    ok = 0
    nforward = 0
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
        elseif forward_only(t)
            # forward-only: the probe's own oracle is the finite forward, so the
            # rim must close and nothing claimed may project to Inf
            nforward += 1
            pr = @test_nowarn GM.probe(t)
            @test GM.isfullsphere(pr) || (pr isa GM.SpherePolygon && rim_closed(pr))
            @test false_finite(pr, t; n = 1000) == 0
            @test false_finite(r, t; n = 1000) == 0
        end
        if !GM.isfullsphere(r)
            rl = @test_nowarn GM.project_rim(r, t)
            @test rl.bbox === nothing || all(isfinite, minimum(rl.bbox)) && all(isfinite, widths(rl.bbox))
        end
        ok += 1
    end
    @test ok >= 28
    @test nforward >= 8          # adams_hemi, adams_ws1, airy, apian, august, bacon, bertin1953, boggs, chamb, denoy
    @test GM.CHAIN_OPEN[] == open0
end
