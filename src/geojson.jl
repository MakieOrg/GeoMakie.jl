#=
# GeoInterface.jl integration

This code has some utilities to work with GeoJSON and GeoInterface geometries.
=#

using GeoInterface
using GeometryBasics


# The entry point - decomposes whatever it is handed down to geometries,
# then hands each one to GeoInterface.convert

"""
    geo2basic(input)

Takes any GeoInterface-compatible object -- a geometry, feature, feature collection,
table with a geometry column, or any (nested) iterable of those -- and returns the
equivalent GeometryBasics.jl geometry, or vector of geometries, which is what Makie
is built on.

Feature collections, features and tables are decomposed to their geometries first;
each geometry is then converted wholesale by `GeoInterface.convert`.
"""
function geo2basic(input)
    return GO.apply(_geometrybasics_geom, GO.TraitTarget{GI.AbstractGeometryTrait}(), GO.get_geometries(input))
end

# `GeoInterface.convert` handles every trait that GeometryBasics has a type for.
_geometrybasics_geom(geom) = _geometrybasics_geom(GI.trait(geom), geom)
_geometrybasics_geom(::GI.AbstractGeometryTrait, geom) = GI.convert(GeometryBasics, geom)
# The two exceptions are linear rings and geometry collections, which GeometryBasics
# has no equivalent type for.  Rings become (closed) linestrings, and collections stay
# GeoInterface geometry collections whose members are GeometryBasics geometries.
_geometrybasics_geom(::GI.LinearRingTrait, geom) =
    GI.convert(GeometryBasics, GI.LineString(collect(GI.getpoint(geom)); extent = GI.extent(geom), crs = GI.crs(geom)))
_geometrybasics_geom(::GI.GeometryCollectionTrait, geom) =
    GI.GeometryCollection(map(_geometrybasics_geom, collect(GI.getgeom(geom))); extent = GI.extent(geom), crs = GI.crs(geom))



"""
    to_multipoly(geom)

Convert a polygon, vector of polygons, multipolygon, or any GeoInterface-compatible
geometry into a `GeometryBasics.MultiPolygon`. `GeometryCollection`s are handled by
extracting their polygon and multipolygon members and unioning them.
"""
to_multipoly(poly::GeometryBasics.Polygon) = GeometryBasics.MultiPolygon([poly])
to_multipoly(polys::AbstractVector{<:GeometryBasics.Polygon}) = GeometryBasics.MultiPolygon(polys)
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
        final_multipoly = reduce((x, y) -> GO.union(x, y; target = GeoInterface.MultiPolygonTrait()), poly_and_multipoly_s)
        return to_multipoly(final_multipoly)
    end
end

to_multilinestring(poly::GeometryBasics.LineString) = GeometryBasics.MultiLineString([poly])
to_multilinestring(ls::AbstractVector{<:GeometryBasics.LineString}) = GeometryBasics.MultiLineString(ls)
to_multilinestring(mp::GeometryBasics.MultiLineString) = mp
to_multilinestring(geom) = to_multilinestring(GeoInterface.trait(geom), geom)
to_multilinestring(geom::AbstractVector) = to_multilinestring.(GeoInterface.trait.(geom), geom)
to_multilinestring(::GeoInterface.LineStringTrait, geom) = GeometryBasics.MultiLineString([GeoInterface.convert(GeometryBasics, geom)])
to_multilinestring(::GeoInterface.MultiLineStringTrait, geom) = GeoInterface.convert(GeometryBasics, geom)

function _mls2ls(mls::GeometryBasics.MultiLineString{N, T}) where {N, T}
    points = Vector{Point{N, T}}()
    sizehint!(
        points, 
        sum(GeoInterface.npoint, mls.linestrings) #= length of individual linestrings =# + 
        length(mls.linestrings) #= NaN points between linestrings =#
    )
    for ls in mls
        append!(points, GeometryBasics.coordinates(ls))
        push!(points, Point{N, T}(NaN))
    end
    return GeometryBasics.LineString(points)
end
