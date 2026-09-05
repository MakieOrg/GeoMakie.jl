# The round-trip oracle itself: sanity on the cases whose domains are known.

@testset "sphere conventions" begin
    @test GM.lonlat_to_xyz(0, 0) ≈ [1, 0, 0]
    @test GM.lonlat_to_xyz(90, 0) ≈ [0, 1, 0]
    @test GM.lonlat_to_xyz(0, 90) ≈ [0, 0, 1]
    for (lon, lat) in ((12.3, -45.6), (-179.9, 89.0), (180.0, 0.0), (0.0, -90.0))
        lon2, lat2 = GM.xyz_to_lonlat(GM.lonlat_to_xyz(lon, lat))
        @test lat2 ≈ lat atol = 1e-9
        abs(lat) < 90 && @test mod(lon2 - lon + 180, 360) - 180 ≈ 0 atol = 1e-9
    end
    @test GM.angular_distance([1, 0, 0], [0, 1, 0]) ≈ pi / 2
    @test GM.angular_distance([1, 0, 0], [-1, 0, 0]) ≈ pi
    @test GM.angular_distance([1, 0, 0], [1, 1e-9, 0]) ≈ 1e-9 rtol = 1e-6
end

@testset "oracle on known domains" begin
    ortho = case_by_name(:ortho)
    @test onmap(ortho, 10, 45)
    @test onmap(ortho, 10 + 89, 45)                   # 89 deg away along the parallel-ish
    @test !onmap(ortho, -170, -45)                    # the antipode
    merc = case_by_name(:merc)
    @test onmap(merc, 0, 0)
    @test onmap(merc, 179.9, 80)
    geos = case_by_name(:geos)
    @test onmap(geos, 0, 0)
    @test !onmap(geos, 100, 0)
    tm = case_by_name(:tmerc)
    @test onmap(tm, 0, 0)
    @test onmap(tm, 170, 0)                            # extended tmerc is finite far away
    @test !onmap(tm, 90, 0)                            # but not at the blob centres
end

@testset "rotations" begin
    # proj_parameterised(p) == proj_reference(R' p), checked through PROJ itself
    pts = [GM.lonlat_to_xyz(lon, lat) for lon in -150:37:150, lat in -75:25:75]
    function check(dest_param, dest_ref, R; atol)
        tp = Proj.Transformation("EPSG:4326", dest_param; always_xy = true)
        tr = Proj.Transformation("EPSG:4326", dest_ref; always_xy = true)
        worst = 0.0
        for p in pts
            a = GM.project_point(tp, p)
            b = GM.project_point(tr, GM.Vec3d(transpose(R) * p))
            (GM._finite2(a) && GM._finite2(b)) || continue
            worst = max(worst, norm(a - b))
        end
        return worst
    end
    @test check("+proj=robin +lon_0=150 +R=6371000", "+proj=robin +R=6371000", GM.lon0_rotation(150); atol = 1) < 1
    @test check("+proj=ortho +lon_0=10 +lat_0=45 +R=6371000", "+proj=ortho +R=6371000", GM.centre_rotation(10, 45); atol = 1) < 1
    @test check("+proj=ob_tran +o_proj=moll +o_lon_p=45 +o_lat_p=45 +lon_0=180 +R=6371000", "+proj=moll +R=6371000",
        GM.obtran_rotation(45, 45, 180); atol = 1) < 1
    @test GM.Vec3d(GM.centre_rotation(10, 45) * GM.XHAT) ≈ GM.lonlat_to_xyz(10, 45)
end
