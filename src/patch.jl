using GeoInterface
using GeometryBasics

# Coerce all coordinates to Floats
#### Hack for type inference issues for integers, related to ####################################
#### FIX FOR https://github.com/JuliaGeometry/GeometryBasics.jl/issues/142 #####################
#### Should be fixed by https://github.com/JuliaGeometry/GeometryBasics.jl/pull/173, perhaps. ##
function GeoInterface.convert(::Type{LineString}, type::LineStringTrait, geom)
    dim = Int(ncoord(geom))
    return LineString([Point{dim}(GeoInterface.coordinates(p) * 1.0) for p in getgeom(geom)])
end

function GeoInterface.convert(::Type{Point}, type::PointTrait, geom)
    dim = Int(ncoord(geom))
    return Point{dim}(GeoInterface.coordinates(geom) * 1.0)
end
### Hack over...

trait_type_pairs = [PolygonTrait() Polygon;
                    MultiPolygonTrait() MultiPolygon;
                    LineStringTrait() LineString;
                    PointTrait() Point]

# Convert all geoJSON objects to the appropriate GeometryBasics type based on trait
function geoJSONtraitParse(feature::GeoJSON.Feature)
    geometry = GeoInterface.geometry(feature)
    trait_matches = trait_type_pairs[:,1] .== (GeoInterface.trait(geometry),)

    if sum(trait_matches) != 1
        @warn "GeoMakie.geoJSONtraitParse: Unknown geometry type $(GeoInterface.trait(geometry))"
        return nothing
    end

    return GeoInterface.convert(trait_type_pairs[trait_matches, 2][1], geometry)
end

function geoJSONtraitParse(featureCollection::GeoJSON.FeatureCollection)
    Vector{}
    return [geoJSONtraitParse(f) for f in featureCollection]
end
