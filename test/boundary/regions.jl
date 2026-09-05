# The primitives: arcs, the solver, regions, clip and rim.

@testset "circle_roots" begin
    eq = GM.full_circle(GM.ZHAT, 0.0)                       # the equator
    roots, degenerate = GM.circle_roots(eq, GM.XHAT, 0.0)   # crossings of the plane x = 0
    @test !degenerate
    @test length(roots) == 2
    @test all(abs(GM.arcpoint(eq, t)[1]) < 1e-12 for (t, _) in roots)
    @test abs(roots[1][1] - roots[2][1]) ≈ pi
    _, degenerate = GM.circle_roots(eq, GM.ZHAT, 0.0)       # the equator lies in z = 0
    @test degenerate
    roots, _ = GM.circle_roots(eq, GM.ZHAT, 0.5)            # never reaches z = 0.5
    @test isempty(roots)
    par = GM.full_circle(GM.ZHAT, sind(60))
    roots, _ = GM.circle_roots(par, GM._dir(30), cosd(60) * cosd(10))
    @test length(roots) == 2
    for (t, scale) in roots
        @test GM._dot3(GM.arcpoint(par, t), GM._dir(30)) ≈ cosd(60) * cosd(10) atol = 1e-12
        @test scale > 0
    end
end

@testset "Zone and Wedge" begin
    cap = GM.Zone(GM.XHAT, cosd(30), 1.0)
    @test contains(cap, GM.lonlat_to_xyz(20, 0))
    @test !contains(cap, GM.lonlat_to_xyz(40, 0))
    @test contains(cap, GM.lonlat_to_xyz(30, 0))          # on the boundary
    w = GM.Wedge(GM.ZHAT, GM._dir(-40), deg2rad(220))    # lon -40 .. 180
    @test contains(w, GM.lonlat_to_xyz(0, 10))
    @test contains(w, GM.lonlat_to_xyz(179, -10))
    @test !contains(w, GM.lonlat_to_xyz(-100, 0))
    @test contains(w, GM.ZHAT)                             # the axis belongs to every wedge
    cut = GM.CutQuadrangle(0.0)
    @test contains(cut, GM.lonlat_to_xyz(-179.9, 0)) && contains(cut, GM.lonlat_to_xyz(179.9, 0))
    r = GM.rotate(cap, GM.centre_rotation(10, 45))
    @test contains(r, GM.lonlat_to_xyz(10, 45))
    @test !contains(r, GM.lonlat_to_xyz(10, -45))
end

@testset "rim provenance" begin
    merc = GM.analytic_region(GM.parse_proj_string("+proj=merc"))
    pieces = GM.rim(merc)
    @test length(pieces) == 4
    @test count(p -> p.tag == :limb, pieces) == 2
    cuts = filter(p -> p.tag == :cut, pieces)
    @test length(cuts) == 2
    @test Set(p.side for p in cuts) == Set([1, -1])
    @test allunique(p.part for p in pieces) == false && length(unique(p.part for p in pieces)) == 2
    # the two seam sides are inset from the seam by SEAM_EPS, on opposite sides
    for p in cuts
        mid = GM.arcpoint(p.arc, 0.5 * (p.arc.t0 + p.arc.t1))
        @test sign(mid[2]) == -p.side || abs(mid[2]) < 1e-12     # seam at lon 180: y ~ ±sin(SEAM_EPS)
        @test abs(abs(GM.xyz_to_lonlat(mid)[1]) - 180) ≈ rad2deg(GM.SEAM_EPS) atol = 1e-6
    end
    # band circles are inset from the seam and end within the band
    for p in filter(p -> p.tag == :limb, pieces)
        @test !GM.isfull(p.arc)
        for tt in (p.arc.t0, p.arc.t1)
            lon, lat = GM.xyz_to_lonlat(GM.arcpoint(p.arc, tt))
            @test abs(lat) ≈ GM.MERCATOR_BAND_DEG atol = 1e-9
            @test abs(abs(lon) - 180) > 1e-4
        end
    end
end

@testset "clip" begin
    cap = GM.Cap(60.0)                                     # about x̂
    eq = GM.full_circle(GM.ZHAT, 0.0)
    pieces = GM.clip(cap, eq)
    @test length(pieces) == 1
    lo = GM.xyz_to_lonlat(GM.arcpoint(pieces[1], pieces[1].t0))
    hi = GM.xyz_to_lonlat(GM.arcpoint(pieces[1], pieces[1].t1))
    @test sort([lo[1], hi[1]]) ≈ [-60, 60] atol = 1e-9
    # a full circle inside the region survives whole
    @test length(GM.clip(GM.whole_sphere(), eq)) == 1
    @test GM.isfull(GM.clip(GM.whole_sphere(), eq)[1])
    # a parallel clipped by a pure cut is split at the seam with an inset
    cut = GM.CutQuadrangle(0.0)
    pieces = GM.clip(cut, GM.full_circle(GM.ZHAT, sind(40)))
    @test length(pieces) == 1
    lon0 = GM.xyz_to_lonlat(GM.arcpoint(pieces[1], pieces[1].t0))[1]
    lon1 = GM.xyz_to_lonlat(GM.arcpoint(pieces[1], pieces[1].t1))[1]
    @test lon0 > -180 && lon1 < 180
    @test (lon0 + 180) ≈ (180 - lon1) atol = 1e-9
    # a meridian on the seam itself is emitted twice, once each side of the
    # seam (rotated ±SEAM_EPS about the axis, like the rim's own pieces)
    seam = GM.make_arc(GM._cross3(GM._dir(180), GM.ZHAT), 0.0, GM._dir(180), -pi / 2, pi / 2)
    sides = GM.clip(cut, seam)
    @test length(sides) == 2
    side_lons = [GM.xyz_to_lonlat(GM.arcpoint(a, 0.5 * (a.t0 + a.t1)))[1] for a in sides]
    @test all(l -> abs(abs(l) - 180) < 2 * rad2deg(GM.SEAM_EPS), side_lons)
    @test prod(sign, side_lons) < 0
    # nothing survives outside
    @test isempty(GM.clip(GM.Cap(10.0), GM.full_circle(GM.ZHAT, sind(-40))))
end

@testset "Quadrangle" begin
    @test GM.isfullsphere(GM.Quadrangle((-180, 180), (-90, 90)))
    q = GM.Quadrangle((-180, 180), (60, 90))
    @test q isa GM.Zone && q.tag == :limit
    @test length(GM.rim(q)) == 1
    q = GM.Quadrangle((-10, 30), (35, 60))
    @test q isa GM.Intersection
    pieces = GM.rim(q)
    @test length(pieces) == 4 && all(p -> p.tag == :limit, pieces) && all(p -> p.side == 0, pieces)
    @test contains(q, GM.lonlat_to_xyz(0, 50)) && !contains(q, GM.lonlat_to_xyz(40, 50))
end

@testset "SpherePolygon" begin
    verts = [GM.lonlat_to_xyz(lon, lat) for (lon, lat) in ((-20, -20), (20, -20), (20, 20), (-20, 20))]
    arcs = [GM.great_arc(verts[i], verts[mod1(i + 1, 4)]) for i in 1:4]
    poly = GM.SpherePolygon(arcs, GM.XHAT)
    @test contains(poly, GM.lonlat_to_xyz(0, 0))
    @test contains(poly, GM.lonlat_to_xyz(15, 15))
    @test !contains(poly, GM.lonlat_to_xyz(30, 0))
    @test !contains(poly, GM.lonlat_to_xyz(-179, 0))
    @test length(GM.rim(poly)) == 4
    pieces = GM.clip(poly, GM.full_circle(GM.ZHAT, 0.0))
    @test length(pieces) == 1
end

@testset "Goode's equator is not rim" begin
    g = GM.GoodeLobes()
    pieces = GM.rim(g)
    @test all(p -> p.tag == :cut, pieces)
    @test length(pieces) == 12
    @test length(GM.seams(g)) == 6
    @test contains(g, GM.lonlat_to_xyz(-40, 0)) && contains(g, GM.lonlat_to_xyz(-40, 45))
end
