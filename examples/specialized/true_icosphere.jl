using GeometryBasics, LinearAlgebra

using CoordinateTransformations
import GeoInterface as GI

struct UnitCartesianFromGeographic <: CoordinateTransformations.Transformation 
end

function (::UnitCartesianFromGeographic)(geographic_point)
    # Longitude is directly translatable to a spherical coordinate
    # θ (azimuth)
    θ = deg2rad(GI.x(geographic_point))
    # The polar angle is 90 degrees minus the latitude
    # ϕ (polar angle)
    ϕ = deg2rad(90 - GI.y(geographic_point))
    # Since this is the unit sphere, the radius is assumed to be 1,
    # and we don't need to multiply by it.
    return Point3(
        sin(ϕ) * cos(θ),
        sin(ϕ) * sin(θ),
        cos(ϕ)
    )
end

struct GeographicFromUnitCartesian <: CoordinateTransformations.Transformation 
end

function (::GeographicFromUnitCartesian)(xyz::AbstractVector)
    @assert length(xyz) == 3 "GeographicFromUnitCartesian expects a 3D Cartesian vector"
    x, y, z = xyz
    return Point2(
        atan(y, x),
        atan(hypot(x, y), z),
    )
end

struct GeographicUVFromUnitCartesian <: CoordinateTransformations.Transformation 
end

function (::GeographicUVFromUnitCartesian)(xyz::AbstractVector)
    @assert length(xyz) == 3 "GeographicFromUnitCartesian expects a 3D Cartesian vector"
    x, y, z = xyz
    return Point2(
        ((atan(y, x))/(2pi) + 1)/1.5,
        ((atan(hypot(x, y), z))/pi + 0.5)/1.5,
    )
end


function add_vertex!(vertex_list, vertex)
    push!(vertex_list, LinearAlgebra.normalize(vertex))
    return length(vertex_list)
end

function get_middle_point!(vertex_list, midpoint_cache, p1::Int, p2::Int)
    first_is_smaller = p1 < p2
    smaller_index = first_is_smaller ? p1 : p2
    larger_index = first_is_smaller ? p2 : p1
    key = smaller_index << 32 + larger_index
    
    if haskey(midpoint_cache, key)
        return midpoint_cache[key]
    else
        midpoint = @. (vertex_list[p1] + vertex_list[p2]) / 2
        midpoint_idx = add_vertex!(vertex_list, midpoint)
        midpoint_cache[key] = midpoint_idx
        return midpoint_idx
    end
end

function refined_faces!(face, vertex_list, midpoint_cache)
    p1, p2, p3 = face
    p12 = get_middle_point!(vertex_list, midpoint_cache, p1, p2)
    p13 = get_middle_point!(vertex_list, midpoint_cache, p1, p3)
    p23 = get_middle_point!(vertex_list, midpoint_cache, p2, p3)
    
    return (
        TriangleFace{Int}(p1, p12, p13),
        TriangleFace{Int}(p2, p23, p12),
        TriangleFace{Int}(p3, p13, p23),
        TriangleFace{Int}(p12, p23, p13),
    )
end


# Helper functions
function crosses_antimeridian(vertices, v1, v2, v3)
    s1, s2, s3 = GeographicFromUnitCartesian().(vertices[Vec3(v1, v2, v3)])
    if isapprox(s1[1], pi) || abs.(v1) == Point3{Float64}(0, 0, 1) 
        return v1
    elseif isapprox(s2[1], pi) || abs.(v2) == Point3{Float64}(0, 0, 1) 
        return v2
    elseif isapprox(s3[1], pi) || abs.(v3) == Point3{Float64}(0, 0, 1) 
        return v3
    else
        return 0
    end
end

function split_face_through_vertex(face, antimeridian_vertex, vertices, uvs)
    v1, v2, v3 = vertices[face[1]], vertices[face[2]], vertices[face[3]]
    # Find the index of the antimeridian vertex in the face
    antimeridian_index = findfirst(v -> v == antimeridian_vertex, face)
    
    if antimeridian_index === nothing
        return [face]  # No split needed
    end
    
    # Reorder vertices so that the antimeridian vertex is first
    ordered_face = circshift(face, 1 - antimeridian_index)
    v1, v2, v3 = vertices[ordered_face[1]], vertices[ordered_face[2]], vertices[ordered_face[3]]
    uv1, uv2, uv3 = uvs[ordered_face[1]], uvs[ordered_face[2]], uvs[ordered_face[3]]
    
    # Compute a new vertex along the edge opposite the antimeridian vertex
    new_vertex = normalize(@. (v2 + v3)/2)
    nv1 = add_vertex!(vertices, new_vertex)
    nv2 = add_vertex!(vertices, new_vertex)
    
    # Calculate UV coordinates for the new vertices
    new_uv1 = Vec2{Float64}(0.0, (uv1[2] + uv2[2]) / 2)  # Left edge of texture
    new_uv2 = Vec2{Float64}(1.0, (uv1[2] + uv3[2]) / 2)  # Right edge of texture
    push!(uvs, new_uv1)
    push!(uvs, new_uv2)
    
    # Create two new faces, each with a unique set of vertices
    new_face1 = (ordered_face[1], ordered_face[2], nv1)  # Using new_vertex1
    new_face2 = (ordered_face[1], nv2, ordered_face[3])      # Using new_vertex2
    
    return [new_face1, new_face2]
end

function cartesian_to_spherical(v)
    x, y, z = v
    θ = acos(z)
    ϕ = atan(y, x)
    return Point3{Float64}(1, ϕ, θ)
end

function spherical_to_cartesian(v)
    r, ϕ, θ = v
    x = r * cos(θ) * cos(ϕ)
    y = r * cos(θ) * sin(ϕ)
    z = r * cos(θ)
    return Point3{Float64}(x, y, z)
end



"""
    icosphere(n_refinements::Int = 2)

Create an icosphere with the specified number of refinements.

Returns a tuple containing a vector of points (vertices) and a vector of faces.

## Usage examples
```julia
vertices, faces = icosphere(2)
msh = GeometryBasics.Mesh(vertices, faces)
# you can now plot this however you like:
using GLMakie
wireframe(msh)
```

If you want to assign UV coordinates to the vertices, you can compute them from the vertices directly.
In this case we'll map the UVs to a lon-lat equirectangular projection, with `u` going from 0 to 1 
horizontally around the sphere, and `v` going from 0 to 1 vertically from the south pole to the north pole.
```julia
# create the icosphere mesh
vertices, faces = icosphere(2)
# compute the UV coordinates
uvs = [Vec2{Float64}(atan(p[2], p[1]) / (2π) + 0.5, asin(p[3]) / π + 0.5) for p in vertices]

# create the mesh with UV coordinates
mesh = GeometryBasics.Mesh(GeometryBasics.meta(vertices; uv = uvs), faces)
```
"""
function icosphere(n_refinements::Int = 2)
    # Potential optimizations:
    # Precompute the number of vertices and faces based on n_refinements
    # Since we know both the input and output number of vertices and faces,
    # we can preallocate the arrays using `sizehint!`.
    #
    # 

    ϕ = (1+√5)/2
    vertices = LinearAlgebra.normalize.(Point3{Float64}[
            (-1,   ϕ, 0),
            ( 1,   ϕ, 0),
            (-1,  -ϕ, 0),
            ( 1,  -ϕ, 0),
            (0, -1,   ϕ),
            (0,  1,   ϕ),
            (0, -1,  -ϕ),
            (0,  1,  -ϕ),
            (  ϕ, 0, -1),
            (  ϕ, 0,  1),
            ( -ϕ, 0, -1),
            ( -ϕ, 0,  1),

        ])


    faces = TriangleFace{Int}.([(1, 12,  6),
                (1,  8,  11),
                (1,  11,  12),
                (2,  6,  10),
                (6,  12,  5),
                (12,  11,  3),
                (11,  8,  7),
                (8,  2,  9),
                (4,  10,  5),
                (4,  7,  9),
                (4,  9,  10),
                (6,  5,  10),
                (3,  5,  12),
                (7,  3,  11),
                (9,  7,  8),
                (10,  9,  2),
        ])

    # Split the faces that aren't already split by the antimeridian
    
        
    midpoint_cache = Dict{Int, Int}()
    new_faces = TriangleFace{Int}[]
    for _ in 1:n_refinements
        for face in faces
            append!(new_faces, refined_faces!(face, vertices, midpoint_cache))
        end
        tmp = faces
        faces = new_faces
        new_faces = tmp
        empty!(new_faces)
    end

    # TODO: add the following corrections to the faces:
    # - split all faces along the antimeridian
    # - add the ability to refine more points along the poles, to resolve detail.

    # Split faces along the antimeridian (-180 degrees)
    uvs = similar(vertices, Vec2f)
    antimeridian_faces = TriangleFace{Int}[]
    for face in faces
        v1, v2, v3 = vertices[face[1]], vertices[face[2]], vertices[face[3]]
        
        uvs[face[1]] = GeographicUVFromUnitCartesian()(v1)
        uvs[face[2]] = GeographicUVFromUnitCartesian()(v2)
        uvs[face[3]] = GeographicUVFromUnitCartesian()(v3)
    end

    return GeometryBasics.meta(vertices; uv = uvs), faces
end