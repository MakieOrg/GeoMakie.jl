using GeoInterface
using GeometryBasics

to_point2(a::AbstractVector{<: Number}) = Point2f(a[1], a[2])

function geo2basic(poly::GeoJSON.Polygon)
    polygon_coordinates = GeoInterface.coordinates(poly)
    linestrings = map(x-> to_point2.(x), polygon_coordinates)
    return GeometryBasics.Polygon(linestrings[1], linestrings[2:end])
end

function geo2basic(vector::AbstractVector{<:AbstractVector})
    if isempty(vector)
        return Point{2, Float64}[]
    else
        # GeoJSON strips the eltype so we need to inspect the elements
        x = first(vector)
        if x isa AbstractVector && length(x) == 2 && x[1] isa Real
            return to_point2.(vector)
        elseif x isa AbstractVector && eltype(x) <: AbstractVector
            linestrings = map(x-> to_point2.(x), vector)
            return GeometryBasics.Polygon(linestrings[1], linestrings[2:end])
        else
            error("Unsupported eltype: $(x)")
        end
    end
end

function geo2basic(point::GeoJSON.Point)
    return to_point2(GeoInterface.coordinates(point))
end

function geo2basic(multi_poly::GeoJSON.MultiPolygon)
    polygons = GeoInterface.coordinates(multi_poly)
    return geo2basic.(polygons)
end

geo2basic(feature::GeoJSON.Feature) = geo2basic(GeoInterface.geometry(feature))
function geo2basic(feature::GeoJSON.LineString)
    return GeometryBasics.LineString(geo2basic(GeoInterface.coordinates(feature)))
end

to_multipoly(poly::Polygon) = GeometryBasics.MultiPolygon([poly])
to_multipoly(mp::MultiPolygon) = mp
to_multipoly(any) = GeometryBasics.MultiPolygon(any)

# Only converts polygons and multipolygons
function geo2basic(fc::GeoJSON.FeatureCollection)
    return map(geo2basic, fc)
end
