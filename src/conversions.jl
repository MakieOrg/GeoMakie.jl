#=
# Plot conversion functions

This mainly deals with default conversion functions and plot types
for GeoInterface.jl geometries.
=#

# set the default plot type for Vectors of polygons,
# so that they are plotted using the most efficient method!
plottype(::Vector{<: GeometryBasics.MultiPolygon}) = Mesh
plottype(::Vector{<: GeometryBasics.Polygon}) = Mesh

# function convert_arguments(P::Type{<: Union{Poly, Mesh}}, geom::GeoInterface.AbstractGeometry)
#     return convert_arguments(P, geo2basic(geom))
# end

function Makie.convert_arguments(P::Type{<:Poly}, geom::GeoJSON.FeatureCollection)
    return convert_arguments(P, to_multipoly.(geo2basic(geom)))
end

function Makie.convert_arguments(P::Type{<:AbstractPlot}, geom::GeoJSON.FeatureCollection)
    return convert_arguments(P, geo2basic(geom))
end
