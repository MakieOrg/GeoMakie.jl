#=
# GeoInterface.jl integration

This code has some utilities to work with GeoJSON and GeoInterface geometries.
=#

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
to_multipoly(geom::AbstractVector) = to_multipoly.(GeoInterface.trait.(geom), geom)
to_multipoly(::GeoInterface.PolygonTrait, geom) = GeometryBasics.MultiPolygon([GeoInterface.convert(GeometryBasics, geom)])
to_multipoly(::GeoInterface.MultiPolygonTrait, geom) = GeoInterface.convert(GeometryBasics, geom)

function to_multipoly(::GeoInterface.GeometryCollectionTrait, geom)
    geoms = collect(GeoInterface.getgeom(geom))
    poly_and_multipoly_s = filter(x -> GeoInterface.trait(x) isa GeoInterface.PolygonTrait || GeoInterface.trait(x) isa GeoInterface.MultiPolygonTrait, geoms)
    if isempty(poly_and_multipoly_s) # geometry is effectively empty
        return GeometryBasics.MultiPolygon([GeometryBasics.Polygon(Point{2 + GeoInterface.hasz(geom) + GeoInterface.hasm(geom), Float64}[])])
    else # effectively "unary union" the geometry collection
        final_multipoly = reduce((x, y) -> GeometryOps.union(x, y; target = GeoInterface.MultiPolygonTrait()), poly_and_multipoly_s)
        return to_multipoly(final_multipoly)
    end
end

to_multilinestring(poly::GeometryBasics.LineString) = GeometryBasics.MultiLineString([poly])
to_multilinestring(poly::Vector{GeometryBasics.Polygon}) = GeometryBasics.MultiLineString(poly)
to_multilinestring(mp::GeometryBasics.MultiLineString) = mp
to_multilinestring(geom) = to_multilinestring(GeoInterface.trait(geom), geom)
to_multilinestring(geom::AbstractVector) = to_multilinestring.(GeoInterface.trait.(geom), geom)
to_multilinestring(::GeoInterface.LineStringTrait, geom) = GeometryBasics.MultiLineString([GeoInterface.convert(GeometryBasics, geom)])
to_multilinestring(::GeoInterface.MultiLineStringTrait, geom) = GeoInterface.convert(GeometryBasics, geom)


# GeoJSON-specific overrides for clarity
# Only converts polygons and multipolygons
function geo2basic(fc::GeoJSON.FeatureCollection)
    return map(geo2basic, fc)
end

geo2basic(feature::GeoJSON.Feature) = geo2basic(GeoInterface.geometry(feature))

function _mls2ls(mls::GeometryBasics.MultiLineString{N, T}) where {N, T}
    points = Vector{Point{N, T}}()
    sizehint!(
        points, 
        sum(GeometryBasics.GeoInterface.npoint, mls.linestrings) #= length of individual linestrings =# + 
        length(mls.linestrings) #= NaN points between linestrings =#
    )
    for ls in mls
        append!(points, GeometryBasics.coordinates(ls))
        push!(points, Point{N, T}(NaN))
    end
    return GeometryBasics.LineString(points)
end