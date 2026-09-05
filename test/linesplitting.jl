# linesplitting.jl -- data is cut at the boundary's seams (Phase 9): the
# CutAtSeams correction, `split(geoms, ax)` and `coastlines(ax)`.

using GeoMakie, CairoMakie, GeometryBasics, Test
import GeoInterface as GI, GeometryOps as GO
using GeoMakie: GeoFormatTypes, Proj

"A parallel at `lat` from `lon0` to `lon1` in `step`-degree pieces."
parallel(lat, lon0, lon1; step = 1.0) = GeometryBasics.LineString([Point2d(lon, lat) for lon in lon0:step:lon1])

pieces(mls) = collect(GI.getgeom(mls))
points(ls) = collect(GI.getpoint(ls))

"How many segments of `mlss` jump more than a quarter of the map's width in `ax`: lines drawn across a seam."
function jumps(ax, mlss)
    t = ax.graph[:transform][]
    W = widths(ax.targetlimits[])[1]
    lines(m) = GI.trait(m) isa GI.AbstractLineStringTrait ? (m,) : GI.getgeom(m)
    return sum(count(>(0.25 * W), abs.(diff([Makie.apply_transform(t, p)[1] for p in points(l)]))) for m in mlss for l in lines(m))
end

"Longitudes of the projected ends of every piece: does the piece leave the map at the seam?"
projected_x(ax, ls) = (t = ax.graph[:transform][]; (Makie.apply_transform(t, first(points(ls)))[1], Makie.apply_transform(t, last(points(ls)))[1]))

@testset "a parallel across robin +lon_0=150's seam" begin
    ax = GeoAxis(Figure(); dest = "+proj=robin +lon_0=150")
    seams = GeoMakie.seams(ax.graph[:boundary][])
    @test length(seams) == 1
    par = parallel(60, -40.5, -20.5)
    mls = split(par, ax)
    @test mls isa GeometryBasics.MultiLineString
    ps = pieces(mls)
    @test length(ps) == 2
    a, b = points(ps[1]), points(ps[2])
    # the crossing is at 330° (-30°), inserted on both pieces, each on its own side
    @test a[end][2] ≈ 60 && b[1][2] ≈ 60
    @test a[end][1] < -30 < b[1][1]
    @test abs(a[end][1] + 30) < 1e-4 && abs(b[1][1] + 30) < 1e-4
    @test abs(a[end][1] - b[1][1]) < 1e-4
    # the west piece ends on the map's right edge and the east piece starts on its left
    xa = projected_x(ax, ps[1]); xb = projected_x(ax, ps[2])
    @test xa[1] > 0 && xa[2] > 0 && xb[1] < 0 && xb[2] < 0
    @test abs(xa[2]) ≈ abs(xb[1]) rtol = 1e-6
    # every other vertex is bit-identical to the input
    @test a[1:end-1] == points(par)[1:11]
    @test b[2:end] == points(par)[12:end]
    # a parallel that never meets the seam is one piece, unchanged
    @test points(only(pieces(split(parallel(60, 0, 20), ax)))) == points(parallel(60, 0, 20))
    # a vertex exactly on the seam is nudged off it towards its predecessor, and the cut follows
    ps = pieces(split(parallel(60, -40, -20), ax))
    @test length(ps) == 2
    a, b = points(ps[1]), points(ps[2])
    @test a[1:10] == points(parallel(60, -40, -20))[1:10]
    @test all(-30.001 < p[1] < -30 for p in a[11:end])
    @test -30 < b[1][1] < -29.999
    @test b[2:end] == points(parallel(60, -40, -20))[12:end]
    xa = projected_x(ax, ps[1]); xb = projected_x(ax, ps[2])
    @test xa[2] > 0 && xb[1] < 0
end

@testset "ob_tran cuts on the rotated great circle" begin
    # o_lon_p = o_lat_p = 45 puts the seam on an oblique great circle
    ax = GeoAxis(Figure(); dest = "+proj=ob_tran +o_proj=moll +o_lon_p=45 +o_lat_p=45 +lon_0=180")
    seams = GeoMakie.seams(ax.graph[:boundary][])
    @test length(seams) == 1
    seam = only(seams)
    # not a meridian: the seam plane is not vertical, and its longitude changes along it
    @test abs(seam.axis[3]) > 0.1
    samples = [GeoMakie.xyz_to_lonlat(GeoMakie.arcpoint(seam, t)) for t in (0.3, 1.2, 2.4)]
    @test maximum(s[1] for s in samples) - minimum(s[1] for s in samples) > 10
    for (lon, lat) in samples
        seg = GeometryBasics.LineString([Point2d(lon - 1, lat), Point2d(lon + 1, lat)])
        ps = pieces(split(seg, ax))
        @test length(ps) == 2
        # the cut sits where the seam crosses this parallel: at the seam point itself
        @test abs(points(ps[1])[end][1] - lon) < 1e-5
        @test abs(points(ps[2])[1][1] - lon) < 1e-5
        # and a meridian segment through the seam point is cut at its latitude
        seg = GeometryBasics.LineString([Point2d(lon, lat - 1), Point2d(lon, lat + 1)])
        ps = pieces(split(seg, ax))
        @test length(ps) == 2
        @test abs(points(ps[1])[end][2] - lat) < 1e-5
    end
    # the `+lon_0` guess would cut at 0° / 180°; a parallel crossing 0° away from the seam is left whole
    @test length(pieces(split(parallel(-40, -10, 10), ax))) == 1
    @test length(pieces(split(parallel(0, 170, 190), ax))) == 1
end

@testset "igh cuts at all five seams" begin
    ax = GeoAxis(Figure(); dest = "+proj=igh")
    seams = GeoMakie.seams(ax.graph[:boundary][])
    @test length(seams) == 6     # ±180 once per hemisphere, -40 north, -100 / -20 / 80 south
    north = pieces(split(parallel(45, -179, 179), ax))
    @test length(north) == 2
    @test abs(points(north[1])[end][1] + 40) < 1e-4
    south = pieces(split(parallel(-45, -179, 179), ax))
    @test length(south) == 4
    cuts = sort([points(p)[end][1] for p in south[1:3]])
    @test all(abs.(cuts .- [-100, -20, 80]) .< 1e-4)
    # the antimeridian seam, crossed by a segment that spans it (cut on the sphere chord)
    seg = GeometryBasics.LineString([Point2d(179, 45), Point2d(-179, 45)])
    ps = pieces(split(seg, ax))
    @test length(ps) == 2
    @test abs(points(ps[1])[end][1] - 180) < 1e-4 || abs(points(ps[1])[end][1] + 180) < 1e-4
    @test abs(abs(points(ps[2])[1][1]) - 180) < 1e-4
    @test sign(points(ps[1])[end][1]) != sign(points(ps[2])[1][1])
    @test abs(points(ps[1])[end][2] - 45) < 0.01
end

@testset "polygons, points and features" begin
    ax = GeoAxis(Figure(); dest = "+proj=robin +lon_0=150")
    poly = GI.Polygon([[(-40.0, 50.0), (-20.0, 50.0), (-20.0, 60.0), (-40.0, 60.0), (-40.0, 50.0)]])
    @test split(poly, ax) === poly
    land = GeoMakie.land()
    @test all(a === b for (a, b) in zip(split(land, ax), land))
    pt = GI.Point((-30.0, 10.0))
    @test split(pt, ax) === pt
    # a feature collection keeps its CRS and properties; its line is cut
    fc = GI.FeatureCollection([GI.Feature(parallel(60, -40, -20); properties = (; name = "par"))]; crs = GeoFormatTypes.EPSG(4326))
    out = split(fc, ax)
    @test GI.crs(out) == GeoFormatTypes.EPSG(4326)
    f = only(GI.getfeature(out))
    @test GI.properties(f).name == "par"
    @test GI.ngeom(GI.geometry(f)) == 2
    # a multilinestring flattens
    mls = GeometryBasics.MultiLineString([parallel(60, -40, -20), parallel(50, 0, 10)])
    @test GI.ngeom(split(mls, ax)) == 3
end

@testset "input in a projected CRS" begin
    ax = GeoAxis(Figure(); dest = "+proj=robin +lon_0=150")
    to_merc = GeoMakie.create_transform("+proj=merc", "+proj=longlat +datum=WGS84")
    seg = GeometryBasics.LineString([Makie.apply_transform(to_merc, Point2d(lon, 60)) for lon in -40.5:1.0:-20.5])
    ps = pieces(split(seg, ax; crs = "+proj=merc"))
    @test length(ps) == 2
    from_merc = GeoMakie.create_transform("+proj=longlat +datum=WGS84", "+proj=merc")
    cut = Makie.apply_transform(from_merc, points(ps[1])[end])
    @test abs(cut[1] + 30) < 1e-4 && abs(cut[2] - 60) < 1e-4
    @test points(ps[1])[1:end-1] == points(seg)[1:11]
    # the axis' source CRS is the default
    ax2 = GeoAxis(Figure(); dest = "+proj=robin +lon_0=150", source = "+proj=merc")
    @test length(pieces(split(seg, ax2))) == 2
end

@testset "coastlines(ax)" begin
    ax = GeoAxis(Figure(); dest = "+proj=robin +lon_0=150")
    cl = GeoMakie.coastlines()
    obs = GeoMakie.coastlines(ax)
    @test obs isa Observable
    out = obs[]
    @test out isa Vector{<:GeometryBasics.MultiLineString}
    @test length(out) == length(cl)
    @test sum(GI.ngeom, out) > length(cl)
    # vertices other than crossings (and the seam) are bit-identical to the input
    original = Set(p for l in cl for p in points(l))
    inserted = [p for m in out for l in GI.getgeom(m) for p in points(l) if !(p in original)]
    @test !isempty(inserted)
    @test all(abs(p[1] + 30) < 1e-3 for p in inserted)
    # no segment jumps across the map, whereas the unsplit coastlines do
    @test jumps(ax, out) == 0
    @test jumps(ax, cl) > 0
    # a new dest re-splits; the unrotated projection's seam is the antimeridian, where
    # Natural Earth is already split (its vertices at ±180° are nudged off the seam, nothing is cut)
    ax.dest[] = "+proj=robin"
    @test sum(GI.ngeom, obs[]) == length(cl)
    @test jumps(ax, obs[]) == 0
    @test all(abs(p[1]) < 180 for m in obs[] for l in GI.getgeom(m) for p in points(l))
    lines!(ax, obs)
    @test true
    # every world map with a cut draws no coastline across its seam
    for dest in ("+proj=wintri +lon_0=-160", "+proj=igh", "+proj=ob_tran +o_proj=eqc +o_lat_p=35 +o_lon_p=0 +lon_0=20",
                 "+proj=ob_tran +o_proj=moll +o_lon_p=45 +o_lat_p=45 +lon_0=180", "+proj=eqearth +lon_0=-160")
        ax2 = GeoAxis(Figure(); dest)
        @test jumps(ax2, GeoMakie.coastlines(ax2)[]) == 0
    end
    # a conic's seam stops at its cutoff parallel: a crossing beyond it (Antarctica at 84°E,
    # 67°S, outside the frame and under the mask) is left alone
    ax3 = GeoAxis(Figure(); dest = "+proj=lcc +lon_0=-96 +lat_1=33 +lat_2=45")
    @test jumps(ax3, GeoMakie.coastlines(ax3)[]) == 1
end
