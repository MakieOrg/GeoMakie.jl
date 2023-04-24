# # Helper functions
to_point2(a::Vector{<: T}) where T = Point2{T}(a[1], a[2])
to_point2(a::AbstractVector{T}) where T <: Number = Point2{T}(a[1], a[2])
to_point2(a::Tuple{T1 <: Number, T2 <: Number}) where {T1, T2} = Point2{promote_type(T1, T2)}(a[1], a[2])

# set the default plot type for Vectors of polygons,
# so that they are plotted using the most efficient method!
plottype(::Vector{<: GeometryBasics.MultiPolygon}) = Mesh
plottype(::Vector{<: GeometryBasics.Polygon}) = Mesh

# Define a specialized conversion function for images with intervals
# This means that one can plot images with intervals into GeoMakie
# TODO: put this in Makie proper
function Makie.convert_arguments(P::Type{<: Makie.MakieCore.Image}, x::Makie.IntervalSets.ClosedInterval, y::Makie.IntervalSets.ClosedInterval, z::AbstractMatrix)
    return convert_arguments(P, LinRange(x.left, x.right, size(z, 1) + 1), LinRange(y.left, y.right, size(z, 2) + 1), z)
end

# function convert_arguments(P::Type{<: Union{Poly, Mesh}}, geom::GeoInterface.AbstractGeometry)
#     return convert_arguments(P, geo2basic(geom))
# end

function Makie.convert_arguments(P::Type{<:Poly}, geom::GeoJSON.FeatureCollection)
    return convert_arguments(P, to_multipoly.(geo2basic(geom)))
end

function Makie.convert_arguments(P::Type{<:AbstractPlot}, geom::GeoJSON.FeatureCollection)
    return convert_arguments(P, geo2basic(geom))
end
