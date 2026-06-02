# Unit tests for the antimeridian splitting primitives in `src/polygonsplitting.jl`.
# These run without a plotting backend.

using GeoMakie, GeometryBasics, Test
using GeoMakie: split_polygon, split_polys_and_colors, split_linestring_points, _normalise_lon
const P2 = GeometryBasics.Point2f

# helper: longitudes of a polygon's exterior
extlons(p) = [v[1] for v in GeometryBasics.coordinates(p.exterior)]
inrange(p, lon0) = all(l -> lon0 - 180 - 1e-3 <= l <= lon0 + 180 + 1e-3, extlons(p))

@testset "_normalise_lon" begin
    @test _normalise_lon(190, 0) ≈ -170
    @test _normalise_lon(-190, 0) ≈ 170
    @test _normalise_lon(430, 0) ≈ 70
    @test _normalise_lon(10, 0) ≈ 10
    # relative to a shifted centre
    @test _normalise_lon(10, 180) ≈ 370 - 360  # 10 -> 370 wrapped about 180 -> stays >0
end

@testset "split_polygon: seam-crossing rectangle" begin
    # rectangle spanning lon 170..190 (crosses the lon0=0 antimeridian)
    poly = GeometryBasics.Polygon([P2(170, -10), P2(190, -10), P2(190, 10), P2(170, 10), P2(170, -10)])
    pieces = split_polygon(poly, 0.0)
    @test length(pieces) >= 2
    @test all(p -> inrange(p, 0.0), pieces)
    # one piece should hug +180, another -180
    @test any(p -> isapprox(maximum(extlons(p)), 180; atol = 1e-2), pieces)
    @test any(p -> isapprox(minimum(extlons(p)), -180; atol = 1e-2), pieces)
end

@testset "split_polygon: shifted (unwrapped) but non-crossing" begin
    # rectangle centred near lon 250 (lon outside [-180,180]); should not be cut,
    # only translated into range.
    poly = GeometryBasics.Polygon([P2(220, -5), P2(280, -5), P2(280, 5), P2(220, 5), P2(220, -5)])
    pieces = split_polygon(poly, 0.0)
    @test length(pieces) == 1
    @test inrange(pieces[1], 0.0)
    @test minimum(extlons(pieces[1])) ≈ -140 atol = 1e-2   # 220 - 360
end

@testset "split_polygon: already in range" begin
    poly = GeometryBasics.Polygon([P2(-10, -10), P2(10, -10), P2(10, 10), P2(-10, 10), P2(-10, -10)])
    pieces = split_polygon(poly, 0.0)
    @test length(pieces) == 1
    @test inrange(pieces[1], 0.0)
end

@testset "split_polys_and_colors expands colours per piece" begin
    crossing = GeometryBasics.Polygon([P2(170, -10), P2(190, -10), P2(190, 10), P2(170, 10), P2(170, -10)])
    inside = GeometryBasics.Polygon([P2(-10, -10), P2(10, -10), P2(10, 10), P2(-10, 10), P2(-10, -10)])
    polys = [crossing, inside]
    colors = [1.0, 2.0]
    np, nc = split_polys_and_colors(polys, colors, 0.0)
    @test length(np) == length(nc)
    @test length(np) >= 3                # crossing -> >=2 pieces, inside -> 1
    @test count(==(1.0), nc) >= 2         # crossing pieces inherit colour 1
    @test count(==(2.0), nc) == 1
end

@testset "split_linestring_points: crossing inserts a NaN break" begin
    pts = P2[(170, 0), (190, 0), (200, 0)]
    out = split_linestring_points(pts, 0.0)
    @test any(p -> isnan(p[1]), out)
    @test all(p -> isnan(p[1]) || (-180 - 1e-3 <= p[1] <= 180 + 1e-3), out)
end

@testset "split_linestring_points: colours stay parallel" begin
    pts = P2[(170, 0), (190, 0), (200, 0)]
    cols = [1.0, 2.0, 3.0]
    op, oc = split_linestring_points(pts, cols, 0.0)
    @test length(op) == length(oc)
    @test any(p -> isnan(p[1]), op)
end

@testset "split_linestring_points: no crossing only normalises" begin
    pts = P2[(220, 0), (230, 0), (240, 0)]   # all shifted, no >180 jump
    out = split_linestring_points(pts, 0.0)
    @test !any(p -> isnan(p[1]), out)
    @test all(p -> -180 - 1e-3 <= p[1] <= 180 + 1e-3, out)
end

@testset "add_cyclic_point" begin
    # vector form: lon along dim 1 of data
    lon = collect(0.0:90:270)               # 0, 90, 180, 270
    data = reshape(collect(1.0:12.0), 4, 3) # (4 lon, 3 lat)
    lonc, datac = add_cyclic_point(lon, data)
    @test length(lonc) == 5
    @test lonc[end] ≈ 360
    @test size(datac) == (5, 3)
    @test datac[end, :] == data[1, :]       # wrapped row is a copy of the first

    # curvilinear matrix form
    λ = [Float64(l) for l in 0:90:270, _ in 1:3]
    φ = [Float64(j) for _ in 0:90:270, j in 1:3]
    z = reshape(collect(1.0:12.0), 4, 3)
    λc, φc, zc = add_cyclic_point(λ, φ, z)
    @test size(λc) == size(φc) == size(zc) == (5, 3)
    @test λc[end, :] ≈ λ[1, :] .+ 360       # only longitudes are shifted
    @test φc[end, :] == φ[1, :]
    @test zc[end, :] == z[1, :]

    # mismatched sizes error
    @test_throws ArgumentError add_cyclic_point(collect(0.0:90:180), data)
end
