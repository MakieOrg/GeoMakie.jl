# # Helper functions

Point2{T}(a::Vector{T}) where T = Point2(a[1], a[2])

"""
    toPointVecs(poly::Polygon)

Creates a vector of [`Point`](@ref)s from the given polygon.
Returns a `Vector{Vector{Point}}`, with one element.
"""
toPointVecs(poly::T) where T <: GeoInterface.AbstractPolygon = [Point2.(cs) for cs in coordinates(poly)]

"""
    toPointVecs(mp::MultiPolygon)

Creates a vector of vectors of [`Point`](@ref)s from the given MultiPolygon.
Returns a `Vector{Vector{Point}}`.

!!! warning
    There is no support for holes in this function at present; that will need to
    wait for GeometryBasics.jl to become complete, possibly replacing GeoInterface.
"""
function toPointVecs(mp::T) where T <: GeoInterface.AbstractMultiPolygon

    polys = []

end



"""
    nonzero(pt::Point{2, T}) where T

Returns `true` if both of the elements are nonzero, and `false` otherwise.
"""
nonzero(pt::Point{2, T}) where {T} = pt[1] != zero(T) && pt[2] != zero(T)

"""
    imprecise(arr)

Returns `true` if the polygon is invalid when converted to Float32,
and `false` otherwise.
"""
function imprecise(arr)
    dif = Point2{Float32}.(arr) |> diff
    return !any(nonzero.(dif))
end

"""
    toMeshes(mp::Vector{Vector{Vector{Point2}}})::Vector{GLNormalUVMesh}
    toMeshes(p::Vector{Vector{Point2}})::Vector{GLNormalUVMesh}

Takes in a polygon, or a multipolygon, and returns a vector of meshes
(which may only contain one mesh).
"""
function toMeshes(mp::Vector{Vector{Vector{Point2{T}}}}) where T

    meshes = GLNormalMesh[]
    # give a hint for the size of the vector so we don't dynamically allocate
    sizehint!(meshes, length(mp))

    for pol in mp
        # this **should** account for holes...
        triangle_faces = EarCut.triangulate(pol)

        v = map(x-> Point3f0(x[1], x[2], 0), vcat(pol...))

        push!(meshes, GLNormalMesh(vertices=v, faces=triangle_faces))
    end

    return meshes
end

function toMeshes(mp::Vector{Vector{Point2{T}}}) where T

    triangle_faces = EarCut.triangulate(mp)

    v = map(x-> Point3{T}(x[1], x[2], 0), vcat(mp...))

    return [GLNormalMesh(vertices=v, faces=triangle_faces)]
end

function toMeshes(mps::Vector{<: GeoInterface.AbstractMultiPolygon})
    meshes = GLNormalUVMesh[]
    sizehint!(meshes, length(mps))
    for mp in mps
        polys = coordinates(mp) |> rec_point
        push!(meshes, merge(vcat(toMeshes.(polys)...)))
    end

    return meshes
end
# # Argument conversions

# ## Polygons

convert_arguments(::Type{<: Poly}, poly::T) where T <: GeoInterface.AbstractPolygon = (toPointVecs(poly)[1],)

convert_arguments(::Type{<: Poly}, mp::T) where T <: GeoInterface.AbstractMultiPolygon = (toPointVecs(mp),)

# Only converts polygons and multipolygons
function convert_arguments(::Type{<: Poly}, fc::GeoInterface.FeatureCollection{GeoInterface.Feature})
    features = fc.features

    cs = Vector{Point2f0}[]

    imp = false

    for feature in features
        for coord in toPointVecs(feature.geometry)
            if imprecise(coord) || length(coord) <= 4
                @warn(
                    """
                    Imprecise coordinates!  You may want to consider reprojecting to a different coordinate system.
                    """,
                    coord
                )
                imp = true
            else
                push!(cs, coord)
            end
        end

    end

    imp && @warn(
                """Coordinates have been removed, because they were
                too ambiguous.  Number of coordinates is now $(length(cs)).
                """
            )

    (cs,)

end

function AbstractPlotting.convert_arguments(::Type{<: Mesh}, fc::GeoInterface.FeatureCollection{GeoInterface.Feature})
    return (fc.features .|> GeoInterface.geometry .|> toPointVecs .|> toMeshes,) # return a Vector of meshes
end

convert_arguments(::Type{<: Mesh}, polys::Vector{<:GeoInterface.AbstractMultiPolygon}) = (toMeshes(polys),)

# set the default plot type for Vectors of polygons,
# so that they are plotted using the most efficient method!
plottype(::Vector{<: GeoInterface.AbstractMultiPolygon}) = Mesh
plottype(::Vector{<: GeoInterface.AbstractPolygon}) = Mesh

function Proj4.transform(src, dest, pt::Point2{T}) where T
    if isnan(pt[1]) && isnan(pt[2])
        return Point2{T}(NaN)
    end
    return Point2{T}(transform(src, dest, Vector(pt)))
end
Base.Broadcast.broadcastable(p::Projection) = Ref(p)
