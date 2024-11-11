using Test
using GeoMakie, Makie
using GeometryBasics
import GeometryOps as GO, GeoInterface as GI
using Geodesy
using LinearAlgebra

@testset "3D Polygon Triangulation" begin
    @testset "Simple planar polygon" begin
        # Create a simple square in 3D space
        points = [
            Point3f(0, 0, 0),
            Point3f(1, 0, 0),
            Point3f(1, 1, 0),
            Point3f(0, 1, 0)
        ]
        poly = Polygon(points)
        
        # Test triangulation
        mesh = Makie.poly_convert(poly)
        faces = GeometryBasics.faces(mesh)
        @test length(faces) == 2  # A square should decompose into 2 triangles
        @test faces isa Vector{GeometryBasics.GLTriangleFace}
    end

    @testset "Rotated planar polygon" begin
        # Create a square rotated 45° around y-axis
        points = [
            Point3f(0, 0, 0),
            Point3f(1/√2, 0, 1/√2),
            Point3f(1/√2, 1, 1/√2),
            Point3f(0, 1, 0)
        ]
        poly = Polygon(points)
        
        mesh = Makie.poly_convert(poly)
        faces = GeometryBasics.faces(mesh)
        @test length(faces) == 2
    end

    @testset "Error cases" begin
        # Test collinear points
        collinear_points = [
            Point3f(0, 0, 0),
            Point3f(1, 1, 1),
            Point3f(2, 2, 2)
        ]
        @test_throws ErrorException Makie.poly_convert(Polygon(collinear_points))

        # Test duplicate points
        duplicate_points = [
            Point3f(0, 0, 0),
            Point3f(0, 0, 0),
            Point3f(0, 0, 0)
        ]
        @test_throws ErrorException Makie.poly_convert(Polygon(duplicate_points))
    end

    @testset "Complex spherical polygon" begin
        # Create a test case similar to your diagnostic code
        londs = [0.0, 90.0, 180.0, 270.0]
        latds = [45.0, 45.0, 45.0, 45.0]
        
        # Convert to 3D points using your transformation
        transf = GeoMakie.Geodesy.ECEFfromLLA(GeoMakie.Geodesy.WGS84())
        points = [Point2(λ, φ) for (λ, φ) in zip(londs, latds)]
        poly = Polygon(points)
        
        # Transform to 3D
        transformed_poly = GO.transform(poly) do point
            Makie.apply_transform(transf, point)
        end |> x -> GO.GI.convert(GeometryBasics, x)
        
        mesh = Makie.poly_convert(transformed_poly)
        faces = GeometryBasics.faces(mesh)

        meshfrom2d = Makie.poly_convert(poly, transf)
        facesfrom2d = GeometryBasics.faces(meshfrom2d)

        @test faces == facesfrom2d
        
        @test length(faces) > 0  # Should produce at least one triangle
        @test faces isa Vector{GeometryBasics.GLTriangleFace}
    end

    @testset "Polygon with interior" begin
        # Create a square with a square hole
        outer = [
            Point3f(0, 0, 0),
            Point3f(2, 0, 0),
            Point3f(2, 2, 0),
            Point3f(0, 2, 0)
        ]
        inner = [
            Point3f(0.5, 0.5, 0),
            Point3f(1.5, 0.5, 0),
            Point3f(1.5, 1.5, 0),
            Point3f(0.5, 1.5, 0)
        ]
        
        poly = Polygon(outer, [inner])
        mesh = Makie.poly_convert(poly)
        faces = GeometryBasics.faces(mesh)
        @test length(faces) > 4  # Should need more than 4 triangles to fill the ring
    end
end