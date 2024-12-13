using Makie.LinearAlgebra
using GeometryBasics
using GeometryOps.ExactPredicates
using GeometryOps.ExactPredicates.Codegen
using GeometryOps.ExactPredicates.StaticArrays: SVector

# This function is an "exact predicate" that is robust to floating point error
# May not be necessary, but it's here if we need it.
@genpredicate function _collinear(p :: 3, q :: 3, r :: 3)
    pq = q - p
    pr = r - p
    Codegen.group!(pq...)
    Codegen.group!(pr...)
    # Cross product of vectors will be zero if points are collinear
    cross = SVector{3}(
        pq[2]*pr[3] - pq[3]*pr[2],
        pq[3]*pr[1] - pq[1]*pr[3], 
        pq[1]*pr[2] - pq[2]*pr[1]
    )
    return ExactPredicates.inp(cross, cross) # Will be 0 if collinear, positive otherwise
end

# This should be removed once https://github.com/MakieOrg/Makie.jl/pull/4584 is merged!
# TODO

# We don't want to override the general case poly_convert for all polygons, because that's piracy,
# but we _can_ override it for the specific case of a 3D polygon that is being transformed by a function
# that is a subtype of Union{<: Proj.Transformation, <: GeoMakie.Geodesy.ECEFfromLLA}
function Makie.poly_convert(polygon::GeometryBasics.Polygon, transform_func::Union{<: Proj.Transformation, <: GeoMakie.Geodesy.ECEFfromLLA})

    outer = GeometryBasics.metafree(GeometryBasics.coordinates(polygon.exterior))
    PT = Makie.float_type(outer)
    points = [Makie.apply_transform(transform_func, outer)]
    points_flat = PT[outer;]
    for inner in polygon.interiors
        inner_points = GeometryBasics.metafree(GeometryBasics.coordinates(inner))
        append!(points_flat, inner_points)
        push!(points, Makie.apply_transform(transform_func, inner_points))
    end

    # Shortcut if the transformation is 2D -> 2D
    if points isa Vector{<: Vector{<: Makie.VecTypes{2}}}
        faces = GeometryBasics.earcut_triangulate(points)
        return GeometryBasics.Mesh(points_flat, faces)
    end

    # We assume the polygon lies on a plane, and thus seek to find that plane,
    # so we can use it to project the polygon into 2D, and then call earcut_triangulate
    # on the projected polygon.

    # First, we extract three unique and independent (non-collinear) points from the polygon.
    p1, p2, p3 = extract_three_unique_and_independent_points(points)

    # Now, we can find a plane from these points:

    # Define a plane that can be used to project the polygon into 2D
    v1 = p2 - p1
    v2 = p3 - p1
    normal = cross(v1, v2)
    
    # `x` and `y` are the vectors that define the plane.
    x = v1
    y = cross(normal, x)


    # Project the polygon into 2D
    projected_polygon = map(ring -> map(p -> Point2{Float64}(dot(p, x), dot(p, y)), ring), points)

    # Now, call earcut_triangulate on the projected polygon, which is 2D
    faces = GeometryBasics.earcut_triangulate(projected_polygon)
    return GeometryBasics.Mesh(points_flat, faces)
end

function extract_three_unique_and_independent_points(points::Vector{Vector{PT}}) where PT <: Makie.VecTypes
    p1, p2, p3 = points[1][1], points[1][2], points[1][3]

    if p1 == p2 || p1 == p3 || p2 == p3
        if length(points[1]) <= 3
            error("Polygon has only three points and they are all the same, we can't triangulate this!")
        elseif p1 == p2 == p3
            new_point_idx = findfirst(p -> p != p1, points[1])
            if isnothing(new_point_idx)
                error("All points in the polygon are the same, we can't triangulate this!")
            end
            p2 = points[1][new_point_idx]
            new_point_idx = findfirst(p -> p != p1 && p != p2, points[1])
            if isnothing(new_point_idx)
                error("Only found two unique points in the polygon, we can't triangulate this!")
            end
            p3 = points[1][new_point_idx]
        elseif p1 == p2
            p2 = points[1][4]
        elseif p1 == p3
            p3 = points[1][4]
        elseif p2 == p3
            p2 = points[1][4]
        end
    end

    # Account for collinear points
    if _collinear(Makie.to_ndim(Point3d, p1, 0.0), Makie.to_ndim(Point3d, p2, 0.0), Makie.to_ndim(Point3d, p3, 0.0)) == 0 # collinear, all the points lie on the same line
        if length(points[1]) <= 3
            error("Polygon has only three points and they are all collinear, we can't triangulate this!")
        end
        new_point_idx = findfirst(p -> _collinear(Makie.to_ndim(Point3d, p1, 0.0), Makie.to_ndim(Point3d, p2, 0.0), Makie.to_ndim(Point3d, p), 0.0) != 0, points[1])
        if isnothing(new_point_idx)
            error("All points in the polygon are collinear, we can't triangulate this!")
        end
        p3 = points[1][new_point_idx]
    end

    return p1, p2, p3
end
