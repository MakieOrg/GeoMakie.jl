using GeoInterface
using GeometryBasics

function geoJSONtraitParse(geometry)
    #### Hack for type inference issues for integers, related to ####################################
    #### FIX FOR https://github.com/JuliaGeometry/GeometryBasics.jl/issues/142 #####################
    #### Should be fixed by https://github.com/JuliaGeometry/GeometryBasics.jl/pull/173, perhaps. ##
    coord_c = copy(GeoInterface.coordinates(geometry))
    GeoInterface.coordinates(geom) = coord_c * 1.0
    ### Hack over...

    if GeoInterface.trait(geometry) == PolygonTrait()
        geometry = GeoInterface.convert(Polygon, geometry)
    elseif GeoInterface.trait(geometry) == MultiPolygonTrait()
        geometry = GeoInterface.convert(MultiPolygon, geometry)
    elseif GeoInterface.trait(geometry) == LineStringTrait()
        geometry = GeoInterface.convert(LineString, geometry)
    else
        @warn "GeoMakie.geoJSONtraitParse: Unknown geometry type $(GeoInterface.trait(geometry))"
    end
end
