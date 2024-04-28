using GeoInterface
using GeometryBasics


# The entry point - takes in any datatype, and gets its GeoInterface trait type
# then, specializes based on trait type to produce a GeometryBasics object

"""
    geo2basic(input)

Takes any GeoInterface-compatible structure, and returns its equivalent in the GeometryBasics.jl package, which Makie is built on.

Currently works for the following traits:

    - PointTrait
    - LineTrait
    - LineStringTrait
    - PolygonTrait
    - MultiPolygonTrait
"""
function geo2basic(input)

    # makew sure that what is passed in is a GeoInterface geometry/feature/featurecollection

    if GeoInterface.isgeometry(input)
        return geo2basic(GeoInterface.geomtrait(input), input)
    elseif GeoInterface.isfeature(input)
        return geo2basic(GeoInterface.getgeom(input))
    elseif GeoInterface.isfeaturecollection(input)
    elseif input isa AbstractArray && GeoInterface.isgeometry(eltype(input))
        return geo2basic.(input)
    else
        @error("Input of type $(typeof(input)) does not support GeoInterface!")
    end
end

function geo2basic(::GeoInterface.PolygonTrait, poly)
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
        elseif x isa AbstractVector && eltype(x) <: Union{AbstractVector, Tuple}
            linestrings = map(x-> to_point2.(x), vector)
            return GeometryBasics.Polygon(linestrings[1], linestrings[2:end])
        else
            error("Unsupported eltype: $(x)")
        end
    end
end

# TODO: get this to be general across 3d points as well.
function geo2basic(::GeoInterface.PointTrait, point)
    return to_point2(GeoInterface.coordinates(point))
end

function geo2basic(::GeoInterface.LineTrait, line)
    return GeometryBasics.Line(geo2basic(GeoInterface.coordinates(line))...)
end

function geo2basic(::GeoInterface.LineStringTrait, linestring)
    return GeometryBasics.LineString(geo2basic(GeoInterface.coordinates(linestring)))
end

function geo2basic(::GeoInterface.MultiLineStringTrait, multilinestring)
    return GeometryBasics.MultiLineString(
            GeometryBasics.LineString.(
                    map.(
                            to_point2,
                            GeoInterface.coordinates(multilinestring)
                    )
            )
    )
end

function geo2basic(::GeoInterface.MultiPolygonTrait, multipoly)
    polygons = GeoInterface.coordinates(multipoly)
    return to_multipoly(geo2basic.(polygons))
end



to_multipoly(poly::GeometryBasics.Polygon) = GeometryBasics.MultiPolygon([poly])
to_multipoly(poly::Vector{GeometryBasics.Polygon}) = GeometryBasics.MultiPolygon(poly)
to_multipoly(mp::GeometryBasics.MultiPolygon) = mp
to_multipoly(geom) = to_multipoly(GeoInterface.trait(geom), geom)
to_multipoly(::GeoInterface.PolygonTrait, geom) = GeometryBasics.MultiPolygon([GeoInterface.convert(GeometryBasics, geom)])
to_multipoly(::GeoInterface.MultiPolygonTrait, geom) = GeoInterface.convert(GeometryBasics, geom)


# GeoJSON-specific overrides for clarity
# Only converts polygons and multipolygons
function geo2basic(fc::GeoJSON.FeatureCollection)
    return map(geo2basic, fc)
end

geo2basic(feature::GeoJSON.Feature) = geo2basic(GeoInterface.geometry(feature))
