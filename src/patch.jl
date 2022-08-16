using GeoInterface
using GeometryBasics


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


function geoJSONtraitParse(geometry)
    if GeoInterface.trait(geometry) == PolygonTrait()
        geometry = GeoInterface.convert(Polygon, geometry)
    elseif GeoInterface.trait(geometry) == MultiPolygonTrait()
        geometry = GeoInterface.convert(MultiPolygon, geometry)
    elseif GeoInterface.trait(geometry) == LineStringTrait()
        geometry = GeoInterface.convert(LineString, geometry)
    elseif GeoInterface.trait(geometry) == PointTrait()
        geometry = GeoInterface.convert(Point, geometry)
    else
        @warn "GeoMakie.geoJSONtraitParse: Unknown geometry type $(GeoInterface.trait(geometry))"
    end
end



