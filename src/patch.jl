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

trait_type_pairs = Dict(PolygonTrait() => Polygon,
                        MultiPolygonTrait() => MultiPolygon,
                        LineStringTrait() => LineString,
                        PointTrait() => Point)

function geoJSONtraitParse(geometry)
    output_type = getkey(trait_type_pairs, GeoInterface.trait(geometry), nothing)
    
    if isnothing(output_type)
        @warn "GeoMakie.geoJSONtraitParse: Unknown geometry type $(GeoInterface.trait(geometry))"
    end

    return GeoInterface.convert(output_type, geometry)
end



