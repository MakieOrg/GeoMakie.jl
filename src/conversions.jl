# # Helper functions
to_point2(a::Vector{<: Number}) = Point2f0(a[1], a[2])

"""
GeoInterface -> GeometryBasics
"""
function geo2basic(poly::GeoInterface.AbstractPolygon)
    polygon_coordinates = GeoInterface.coordinates(poly)
    linestrings = map(x-> to_point2.(x), polygon_coordinates)
    return GeometryBasics.Polygon(linestrings[1], linestrings[2:end])
end

function geo2basic(poly::Vector{Vector{Vector{Float64}}})
    linestrings = map(x-> to_point2.(x), poly)
    return GeometryBasics.Polygon(linestrings[1], linestrings[2:end])
end

function geo2basic(linestring::Vector{Vector{Float64}})
    return  to_point2.(linestring)
end

function geo2basic(multi_poly::GeoInterface.AbstractMultiPolygon)
    polygons = GeoInterface.coordinates(multi_poly)
    return geo2basic.(polygons)
end

geo2basic(feature::GeoInterface.Feature) = geo2basic(GeoInterface.geometry(feature))
function geo2basic(feature::GeoInterface.AbstractLineString)
    return GeometryBasics.LineString(geo2basic(GeoInterface.coordinates(feature)))
end

to_multipoly(poly::Polygon) = GeometryBasics.MultiPolygon([poly])
to_multipoly(mp::MultiPolygon) = mp
to_multipoly(any) = GeometryBasics.MultiPolygon(any)

# Only converts polygons and multipolygons
function geo2basic(fc::GeoInterface.AbstractFeatureCollection)
    return map(geo2basic, GeoInterface.features(fc))
end

function convert_arguments(P::Type{<: Union{Poly, Mesh}}, geom::GeoInterface.AbstractGeometry)
    return convert_arguments(P, geo2basic(geom))
end

function convert_arguments(P::Type{<:Poly}, geom::GeoInterface.AbstractFeatureCollection)
    return convert_arguments(P, to_multipoly.(geo2basic(geom)))
end


# set the default plot type for Vectors of polygons,
# so that they are plotted using the most efficient method!
plottype(::Vector{<: GeoInterface.AbstractMultiPolygon}) = Mesh
plottype(::Vector{<: GeoInterface.AbstractPolygon}) = Mesh
