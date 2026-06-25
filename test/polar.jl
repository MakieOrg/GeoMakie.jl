using Test
using GeoMakie, CairoMakie, GeometryBasics
const G = GeoMakie

@testset "construction & defaults" begin
    fig = Figure()
    gpa = GeoPolarAxis(fig[1, 1]; latcap = 50)
    @test gpa isa GeoPolarAxis
    @test gpa isa Makie.AbstractAxis               # a proper Block (sibling of GeoAxis)
    @test gpa in fig.content                        # registered in the figure
    @test Makie.current_axis(fig) === gpa          # and set as the current axis
    @test gpa.axis isa Makie.PolarAxis
    @test occursin("lat_0=90", gpa.dest[])         # north pole inferred from latcap ≥ 0
    @test gpa.axis.rlimits[] == (0.0, G._polar_radius(gpa.transform, 50.0))
    @test gpa.axis.direction[] == 1                # north: 0°-meridian at the bottom

    gps = GeoPolarAxis(fig[1, 2]; latcap = -60)
    @test occursin("lat_0=-90", gps.dest[])        # south pole inferred from latcap < 0
    @test gps.axis.direction[] == -1               # south: 0°-meridian at the top
end

@testset "radial law (exact) & orientation matches the projection" begin
    for (latcap, pole) in ((50.0, 90.0), (-50.0, -90.0))
        gpa = GeoPolarAxis(Figure()[1, 1]; latcap = latcap)
        t = gpa.transform
        @test G._polar_radius(t, pole) ≈ 0 atol = 1e-6         # the pole maps to r = 0
        @test G._polar_radius(t, 0.7pole) < G._polar_radius(t, 0.55pole)  # monotone in colatitude
        # θ = lon, and the auto-derived (direction, theta_0) place it exactly where the projection does
        dir, th0 = G._polar_orientation(t, 0.6pole)
        @test gpa.axis.direction[] == dir                      # the axis is configured from the projection
        @test gpa.axis.theta_0[] ≈ th0 atol = 1e-5             # (PolarAxis stores theta_0 as Float32)
        for (lon, lat) in ((0.0, 0.7pole), (90.0, 0.6pole), (-120.0, 0.8pole))
            θ, r = G._polar_θr(t, lon, lat)
            @test θ ≈ deg2rad(lon)
            x, y = t(lon, lat)
            # Makie's `Polar` transform places θ at screen angle `direction·(θ + theta_0)`, which
            # must reproduce the true projected (x, y); this is what the orientation fix guarantees
            # (north `dir=+1` is insensitive to it; south `dir=-1` would be 180°-flipped if wrong).
            @test r * cos(dir * (θ + th0)) ≈ x atol = 1e-3
            @test r * sin(dir * (θ + th0)) ≈ y atol = 1e-3
        end
    end
end

@testset "antimeridian split: Antarctica fills to the pole, pieces simple" begin
    gpa = GeoPolarAxis(Figure()[1, 1]; latcap = -50)
    polys, group = G._anti_split(gpa, GeoMakie.land())
    @test !isempty(polys)
    @test length(group) == length(polys)
    θrpolys = [G._polar_polygon(gpa.transform, p) for p in polys]
    # a pole-enclosing polygon (Antarctica) must reach r = 0 after the pole-walk
    minr = minimum(q[2] for poly in θrpolys for q in GeometryBasics.coordinates(poly.exterior))
    @test minr ≈ 0 atol = 1.0
end

@testset "stroke seams the antimeridian (no radial cut to the pole)" begin
    for (latcap, d) in ((50.0, "+proj=stere +lat_0=90 +lon_0=0"), (-50.0, "+proj=stere +lat_0=-90 +lon_0=0"))
        gpa = GeoPolarAxis(Figure()[1, 1]; latcap = latcap, dest = d)
        polys, _ = G._anti_split(gpa, GeoMakie.land())
        sp = G._polar_stroke_points(gpa.transform, polys)
        rcap = G._polar_radius(gpa.transform, latcap)
        toxy(v) = (v[2] * cos(v[1]), v[2] * sin(v[1]))
        cuts = 0
        for i in 2:length(sp)
            (any(isnan, sp[i]) || any(isnan, sp[i - 1])) && continue
            a = toxy(sp[i]); b = toxy(sp[i - 1])
            # a long chord whose midpoint is well inside the disk == a seam edge cutting across
            if hypot(a[1] - b[1], a[2] - b[2]) > 0.15rcap && hypot((a[1] + b[1]) / 2, (a[2] + b[2]) / 2) < 0.85rcap
                cuts += 1
            end
        end
        @test cuts == 0
    end
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

@testset "filled artists stay vector in SVG (no rasterised mesh)" begin
    fig = Figure()
    gpa = GeoPolarAxis(fig[1, 1]; latcap = -50)
    poly!(gpa, GeoMakie.land(); color = (:gray70, 0.7), strokecolor = :black, strokewidth = 0.6)
    path = tempname() * ".svg"
    save(path, fig)
    svg = read(path, String)
    # poly! fills render as vector paths; a regression to mesh-based fills would emit <feImage>/<image>
    @test !occursin("feImage", svg)
    @test !occursin("<image", svg)
end
