using Test
using GeoMakie, CairoMakie, GeometryBasics
const G = GeoMakie

# project a (θ, r) vertex back to Cartesian (PolarAxis defaults: theta_0 = 0, direction = +1)
_toxy(v) = (v[2] * cos(v[1]), v[2] * sin(v[1]))

@testset "construction & defaults" begin
    fig = Figure()
    gpa = GeoPolarAxis(fig[1, 1]; latcap = 50)
    @test gpa isa GeoPolarAxis
    @test gpa.axis isa Makie.PolarAxis
    @test occursin("lat_0=90", gpa.dest)         # north pole inferred from latcap ≥ 0
    @test gpa.axis.rlimits[] == (0.0, G._polar_radius(gpa.transform, 50.0))

    gps = GeoPolarAxis(fig[1, 2]; latcap = -60)
    @test occursin("lat_0=-90", gps.dest)         # south pole inferred from latcap < 0
end

@testset "radial law & angle (exact via projector)" begin
    gpa = GeoPolarAxis(Figure()[1, 1]; latcap = 50)
    t = gpa.transform
    # pole maps to r = 0
    @test G._polar_radius(t, 90.0) ≈ 0 atol = 1e-6
    # r is monotone in colatitude
    @test G._polar_radius(t, 80.0) < G._polar_radius(t, 60.0)
    # (θ, r) round-trips to the true projected (x, y)
    for (lon, lat) in ((0.0, 70.0), (90.0, 65.0), (-120.0, 80.0))
        θr = G._polar_θr(t, lon, lat)
        x, y = t(lon, lat)
        @test _toxy(θr)[1] ≈ x atol = 1e-3
        @test _toxy(θr)[2] ≈ y atol = 1e-3
    end
end

@testset "cap-clipped fills stay within the cap" begin
    for (latcap, name) in ((50.0, "north"), (-50.0, "south"))
        gpa = GeoPolarAxis(Figure()[1, 1]; latcap = latcap)
        rcap = G._polar_radius(gpa.transform, latcap)
        polys, group = G._cap_split(gpa, GeoMakie.land())
        @test !isempty(polys)
        @test length(group) == length(polys)
        meshes = [G._polar_fill_mesh(gpa.transform, p) for p in polys]
        merged, _ = G._merge_fill_meshes(meshes, nothing)
        verts = GeometryBasics.coordinates(merged)
        @test !isempty(verts)
        # every vertex within the cap radius (a tiny tolerance for the boundary arc)
        @test maximum(v[2] for v in verts) ≤ rcap * (1 + 1e-6)
        # no triangle edge spans more than the disk diameter (would signal a branch-cut artifact)
        diam = 2rcap
        maxedge = 0.0
        for f in GeometryBasics.faces(merged)
            a, b, c = _toxy(verts[f[1]]), _toxy(verts[f[2]]), _toxy(verts[f[3]])
            for (p, q) in ((a, b), (b, c), (c, a))
                maxedge = max(maxedge, hypot(p[1] - q[1], p[2] - q[2]))
            end
        end
        @test maxedge ≤ diam
    end
end

@testset "Antarctica fills to the pole" begin
    gpa = GeoPolarAxis(Figure()[1, 1]; latcap = -50)
    polys, _ = G._cap_split(gpa, GeoMakie.land())
    meshes = [G._polar_fill_mesh(gpa.transform, p) for p in polys]
    merged, _ = G._merge_fill_meshes(meshes, nothing)
    # a pole-enclosing polygon must reach r = 0 (the south pole is land)
    @test minimum(v[2] for v in GeometryBasics.coordinates(merged)) ≈ 0 atol = 1.0
end

@testset "every verb plots without error" begin
    lons = -180:10:180
    lats = 50:5:90
    z = [cosd(la) * sind(2lo) for lo in lons, la in lats]

    fig = Figure()
    gpa = GeoPolarAxis(fig[1, 1]; latcap = 50)
    @test poly!(gpa, GeoMakie.land(); color = (:gray70, 0.6), strokecolor = :black, strokewidth = 0.5) isa Makie.AbstractPlot
    @test lines!(gpa, GeoMakie.coastlines(); color = :black) isa Makie.AbstractPlot
    @test scatter!(gpa, [0.0, 90.0], [70.0, 65.0]; color = :red) isa Makie.AbstractPlot

    gpb = GeoPolarAxis(fig[1, 2]; latcap = 50)
    sf = surface!(gpb, lons, lats, z)
    @test sf isa Makie.AbstractPlot
    @test Colorbar(fig[1, 3], sf) isa Makie.Colorbar      # colormapping survives for a colorbar

    gpc = GeoPolarAxis(fig[2, 1]; latcap = 50)
    @test heatmap!(gpc, lons, lats, z) isa Makie.AbstractPlot

    gpd = GeoPolarAxis(fig[2, 2]; latcap = 50)
    @test contourf!(gpd, lons, lats, z; levels = 8) isa Makie.AbstractPlot

    @test (save(tempname() * ".png", fig); true)          # full render path
end
