using Test
using GeoMakie, CairoMakie, GeometryBasics
import Proj
const G = GeoMakie
const _LL = "+proj=longlat +datum=WGS84"
_t(d) = G.create_transform(d, _LL)

@testset "clip_strategy dispatch" begin
    ct(d) = G.clip_strategy(_t(d))
    @test ct("+proj=moll") isa G.AntimeridianClip
    @test ct("+proj=moll +lon_0=180") isa G.AntimeridianClip
    @test ct("+proj=eqc") isa G.AntimeridianClip
    @test ct("+proj=ortho") isa G.CircleClip
    @test ct("+proj=aeqd") isa G.CircleClip          # full-disk azimuthal: antipode cap, not seam
    @test ct("+proj=laea") isa G.CircleClip
    @test ct("+proj=stere +lat_0=90") isa G.CircleClip   # polar stereographic: antipode cap, NOT antimeridian
    @test ct("+proj=stere +lat_0=-90") isa G.CircleClip
    @test ct("+proj=merc").lat_max < 90              # Mercator pole clamp
    @test ct("+proj=spilhaus") isa G.PolygonClip
    @test ct("+proj=igh") isa G.PolygonClip
    @test ct("+proj=igh_o") isa G.PolygonClip
    @test ct("+proj=imoll_o") isa G.PolygonClip      # oceanic interrupted Mollweide
    @test ct("+proj=bertin1953") isa G.ObliqueAntimeridianClip   # rotated Hammer, native Option B
    @test ct("+proj=tmerc") isa G.CircleClip                 # transverse Mercator: zone cap (Bucket D)
    @test ct("+proj=omerc +lat_1=45 +lat_2=55") isa G.CircleClip
    @test ct("+proj=tpeqd +lat_1=60 +lat_2=65") isa G.NoClip # continuous whole-globe: no seam
    @test ct("+proj=chamb +lat_1=10 +lon_1=30 +lon_2=40") isa G.NoClip
    @test ct("+proj=lsat +ellps=GRS80 +lat_1=-60 +lat_2=60 +lsat=2 +path=2") isa G.NoClip  # continuous track
    @test ct("+proj=isea") isa G.NoClip                     # icosahedral net: continuous, no seam
    @test ct("+proj=tobmerc").lat_max < 90                  # Tobler–Mercator pole clamp (like merc)
    @test ct("+proj=longlat +over") isa G.NoClip
end

# Bucket D: the oblique/multi-point family no longer blanks or tears. Each needs a different remedy
# (CircleClip zone cap for tmerc/omerc; NoClip for the seamless lsat/isea; merc-style pole clamp for
# tobmerc), but all must yield a finite, non-degenerate spine so the panel frames instead of blanking.
@testset "oblique/multi-point family non-blank (Bucket D)" begin
    for dest in ["+proj=tmerc", "+proj=omerc +lat_1=45 +lat_2=55",
                 "+proj=lsat +ellps=GRS80 +lat_1=-60 +lat_2=60 +lsat=2 +path=2",
                 "+proj=isea", "+proj=tobmerc"]
        b = filter(p -> isfinite(p[1]) && isfinite(p[2]), G.boundary_points(dest))
        @test length(b) > 50
        xspan = maximum(p[1] for p in b) - minimum(p[1] for p in b)
        yspan = maximum(p[2] for p in b) - minimum(p[2] for p in b)
        @test xspan > 0.1 * yspan && yspan > 0.1 * xspan    # neither axis collapsed → not blank
    end
end

@testset "great-circle intersect (d3 oracle)" begin
    seg(a, b) = G._ixseg(G._cartr(a[1] * pi / 180, a[2] * pi / 180), G._cartr(b[1] * pi / 180, b[2] * pi / 180))
    ix(a1, a2, b1, b2) = (x = G._gc_intersect(seg(a1, a2), seg(b1, b2));
                          x === nothing ? nothing : round.(G._sphr(x) .* (180 / pi), digits = 5))
    @test ix([-10, -10], [10, 10], [-10, 10], [10, -10]) == (0.0, 0.0)
    @test ix([0, 0], [40, 0], [20, -20], [20, 20]) == (20.0, 0.0)
    @test ix([0, 0], [10, 0], [50, 0], [60, 0]) === nothing
    # degenerate (zero-length) segment must NOT produce a spurious intersection
    @test G._gc_intersect(seg([5, 5], [5, 5]), seg([0, 0], [10, 0])) === nothing
end

@testset "resampler direction symmetry" begin
    proj = G._projector(_t("+proj=moll"))
    a = G.resample_sphere([G.Point2d(-30, 10), G.Point2d(40, -20)], proj)
    b = reverse(G.resample_sphere([G.Point2d(40, -20), G.Point2d(-30, 10)], proj))
    @test length(a) == length(b)
    @test all(((p, q),) -> isapprox(p[1], q[1]; atol = 1e-6) && isapprox(p[2], q[2]; atol = 1e-6), zip(a, b))
end

@testset "split_geometry produces no smear" begin
    LAND = GeoMakie.land()
    for dest in ["+proj=moll", "+proj=moll +lon_0=180", "+proj=ortho +lon_0=20 +lat_0=20",
                 "+proj=spilhaus", "+proj=igh", "+proj=igh_o"]
        t = _t(dest); proj = G._projector(t)
        sp = G.split_geometry(LAND, t)
        @test !isempty(sp)
        nonfin = count(sp) do p
            any(q -> !all(isfinite, proj(q[1], q[2])), GeometryBasics.coordinates(p.exterior))
        end
        @test nonfin == 0
    end
end

@testset "boundary_points finite" begin
    for dest in ["+proj=moll", "+proj=moll +lon_0=180", "+proj=ortho", "+proj=eqc",
                 "+proj=spilhaus", "+proj=igh"]
        b = G.boundary_points(dest)
        @test !isempty(b)
        @test all(p -> isfinite(p[1]) && isfinite(p[2]), b)
    end
end

# Bucket C: azimuthal/perspective limbs (and the hemisphere-clipped globulars) must draw a clean
# circular spine that encloses the clipped land. Regression guards: (1) `aeqd`'s spine used to drop
# the arc straddling the antimeridian near the antipode, leaving a ~full-diameter chord that cut the
# left/right caps off the disk; (2) the globular projections used to fall through to AntimeridianClip,
# whose oval spine the (non-convex, folded) whole-world land spilled past.
@testset "circular limb: no chord, encloses land (Bucket C)" begin
    for dest in ["+proj=aeqd", "+proj=laea", "+proj=stere", "+proj=ortho",
                 "+proj=nicol", "+proj=apian", "+proj=bacon", "+proj=ortel"]
        t = _t(dest); proj = G._projector(t)
        @test G.clip_strategy(t) isa G.CircleClip
        sp = filter(p -> isfinite(p[1]) && isfinite(p[2]), G.boundary_points(dest))
        @test length(sp) > 100
        diam = 2 * maximum(hypot(p[1], p[2]) for p in sp)
        maxchord = maximum(hypot(sp[i][1] - sp[i - 1][1], sp[i][2] - sp[i - 1][2]) for i in 2:length(sp))
        @test maxchord < 0.05 * diam                      # no antipode-cap chord (was ~1.0)
        # the clipped land does not spill past the spine (was ~26% of vertices for nicol on the
        # wrong antimeridian-oval spine; rim-hugging land within chord sagitta is the only residual)
        ring = [(p[1], p[2]) for p in sp]; nr = length(ring)
        function inpoly(x, y)
            c = false; j = nr
            for i in 1:nr
                xi, yi = ring[i]; xj, yj = ring[j]
                ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi) && (c = !c)
                j = i
            end
            return c
        end
        out = 0; tot = 0
        for poly in G.split_geometry(GeoMakie.land(), t), q in GeometryBasics.coordinates(poly.exterior)
            xy = proj(q[1], q[2]); (isfinite(xy[1]) && isfinite(xy[2])) || continue
            tot += 1; inpoly(xy[1], xy[2]) || (out += 1)
        end
        @test out < 0.10 * tot                            # rim-hugging only (~4%); the bug was ~26%
    end
    # ...but a non-azimuthal CircleClip limb must NOT be circularised: adams_hemi maps the hemisphere
    # into a square, so its spine is a diamond (the perfect-circle build is gated to near-180° radii).
    sp = filter(p -> isfinite(p[1]) && isfinite(p[2]), G.boundary_points("+proj=adams_hemi"))
    cx = sum(p -> p[1], sp) / length(sp); cy = sum(p -> p[2], sp) / length(sp)
    rr = [hypot(p[1] - cx, p[2] - cy) for p in sp]
    @test maximum(rr) / minimum(rr) > 1.2                  # diamond corners vs edge midpoints
end

@testset "GeoAxis recipe overrides render" begin
    LAND = GeoMakie.land(); C = GeoMakie.coastlines()
    lons = -180.0:4.0:180.0; lats = -90.0:4.0:90.0
    data = [sind(3l) * cosd(2p) for l in lons, p in lats]
    for dest in ["+proj=moll +lon_0=180", "+proj=spilhaus", "+proj=igh"]
        fig = Figure(); ga = GeoAxis(fig[1, 1]; dest = dest)
        @test_nowarn poly!(ga, LAND)
        @test_nowarn lines!(ga, C)
        @test_nowarn surface!(ga, lons, lats, zeros(length(lons), length(lats)); color = data, shading = NoShading)
        # explicit per-vertex *colour* matrix (e.g. draping an image) must not force Float64(::RGBA)
        imgcol = [RGBA{Float32}(abs(sind(l)), abs(cosd(p)), 0.5f0, 1.0f0) for l in lons, p in lats]
        @test_nowarn surface!(ga, lons, lats, zeros(length(lons), length(lats)); color = imgcol, shading = NoShading)
        # a colour image finer than the z grid must be resampled onto it, not dropped to a flat colour
        bigimg = [RGBA{Float32}(abs(sind(2l)), abs(cosd(3p)), 0.2f0, 1.0f0)
                  for l in range(-180, 180; length = 200), p in range(-90, 90; length = 100)]
        @test_nowarn surface!(ga, lons, lats, zeros(length(lons), length(lats)); color = bigimg, shading = NoShading)
        @test_nowarn heatmap!(ga, lons, lats, data)
        @test_nowarn meshimage!(ga, -180 .. 180, -90 .. 90, GeoMakie.earth() |> rotr90)
        @test_nowarn Makie.update_state_before_display!(fig)
    end
end

@testset "_resample_to_grid samples a finer image onto the z grid" begin
    A = Float64[10i + j for i in 1:4, j in 1:4]   # all distinct
    B = G._resample_to_grid(A, 2, 2)
    @test size(B) == (2, 2)
    @test length(unique(B)) == 4                  # sampled, not collapsed to one flat value
    @test G._resample_to_grid(A, 4, 4) === A      # same size -> identity, no copy
end

@testset "bertin1953 native centred Hammer (Option B)" begin
    clip = G.clip_strategy(_t("+proj=bertin1953")); proj = G._projector(_t("+proj=bertin1953"))
    fwd, _ = G._bertin_rotation()
    # native centred ∘ rotation == PROJ bertin forward (the Option-B exactness guarantee)
    for (lo, la) in [(0.0, 0.0), (30.0, 40.0), (-100.0, -30.0), (150.0, 60.0)]
        r = fwd(deg2rad(lo), deg2rad(la)); b = G._bertin_centred(rad2deg(r[1]), rad2deg(r[2])); f = proj(lo, la)
        @test isapprox(b[1], f[1]; atol = 1.0) && isapprox(b[2], f[2]; atol = 1.0)
    end
    # no chord-streak (Antarctica straddles the rotated seam) through the actual split path
    polys, _ = G._split_geom(GeoMakie.land(), "+proj=bertin1953", _LL); c = clip.centred.f
    worst = 0.0
    for p in polys, k in 2:length(GeometryBasics.coordinates(p.exterior))
        pr = GeometryBasics.coordinates(p.exterior)
        worst = max(worst, hypot(c(pr[k]...)[1] - c(pr[k-1]...)[1], c(pr[k]...)[2] - c(pr[k-1]...)[2]))
    end
    @test worst < 5.0e6        # a seam-collapse streak would be ~20e6 (≈ map width)
end

@testset "Tissot pole/seam circles don't fill the whole map" begin
    # Regression (Tissot's indicatrix on bertin1953): a small geodesic circle centred on a pole is a
    # constant-latitude ring that ENCIRCLES the pole (planar shoelace ≈ 0, sign is noise); one
    # straddling the antimeridian has a SIGN-FLIPPED planar winding. The old planar rewind therefore
    # reversed them into bounding their complement → `_polygon_contains` read the clip anchor as
    # inside → the whole map filled. The `:spherical` rewind (poly!/`split_geometry`) orients by
    # `_geo_area`, which honours the seam and the poles. Faithful triggers need real geodesic circles:
    geod = Proj.geod_geodesic(6378137, 1 / 298.257223563)
    function geocircle(lon, lat, radius = 500_000, n = 50)
        pts = GeometryBasics.Point2d[GeometryBasics.Point2d(reverse(Proj.geod_direct(geod, lat, lon, θ, radius)[1:2])...)
                                     for θ in range(0, 360; length = n)]
        pts[end] == pts[1] || push!(pts, pts[1])
        return GeometryBasics.Polygon(pts)
    end
    subjects = [geocircle(lo, la) for (lo, la) in
                [(0.0, -90.0), (90.0, -90.0), (180.0, -81.0), (0.0, 90.0), (0.0, 0.0)]]
    mapspan(p, c) = (xy = [c(q...) for q in GeometryBasics.coordinates(p.exterior) if all(isfinite, c(q...))];
                     isempty(xy) ? 0.0 :
                     (maximum(first.(xy)) - minimum(first.(xy))) * (maximum(last.(xy)) - minimum(last.(xy))))
    planar_worst = 0.0   # track whether the OLD `:planar` rewind blew anything up (anywhere)
    for dest in ["+proj=bertin1953", "+proj=moll +lon_0=180", "+proj=igh"]
        t = _t(dest); clip = G.clip_strategy(t)
        # bounded frame the split is drawn in (centred for the Option-B clips), to measure extent
        c = clip isa G.ObliqueAntimeridianClip ? clip.centred.f :
            clip isa G.AntimeridianClip ? G._projector(_t(G._centred_dest(dest))) : G._projector(t)
        polys, _ = G._split_geom(subjects, dest, _LL)   # poly! path → `:spherical`
        @test !isempty(polys)
        # a whole-map fill bbox ≈ the map area (~3e14 m²); a ~500 km circle stays well under 1e14.
        @test maximum(mapspan(p, c) for p in polys) < 1.0e14
        project = clip isa G.ObliqueAntimeridianClip ? G._projector(clip.centred) :
                  clip isa G.AntimeridianClip ? G._projector(_t(G._centred_dest(dest))) : G._projector(t)
        rotated = clip isa G.AntimeridianClip || clip isa G.ObliqueAntimeridianClip
        planar = reduce(vcat, (G._split_polygon(clip, G._poly_rings(s), project, G.resample_scale(project);
                                                 rotated = rotated, winding = :planar) for s in subjects))
        planar_worst = max(planar_worst, maximum(mapspan(p, c) for p in planar))
    end
    # confirm the guard is real: the OLD `:planar` rewind DID fill the map for at least one case.
    @test planar_worst > 1.0e14
end
