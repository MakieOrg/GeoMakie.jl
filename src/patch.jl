using GeoInterface
using GeometryBasics

const trait_type_pairs = [PolygonTrait() Polygon;
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
