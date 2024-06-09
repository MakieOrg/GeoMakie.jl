#=
# Bundled data

This file contains convenience functions to load bundled data as well as 
Natural Earth data at different scales.

=#

assetpath(files...) =  joinpath(dirname(@__DIR__), "assets", files...)

const LOAD_CACHE = Dict{String, Any}()

# Docstring consts
const NATURALEARTH_ATTRIBUTION = "Made with Natural Earth. Free vector and raster map data at [naturalearthdata.com](https://www.naturalearth.com)."
const NATURALEARTH_SCALE = """
By default, a scale of 110m is used, for which data is shipped with GeoMakie.
To use other scales, NaturalEarth.jl requires an Internet connection to download
the relevant data.
"""

"""
    earth()

Loads the Natural Earth [^1] 50m raster illustration of Earth as an image.  Doesn't support `scale` as of yet, but that's coming soon!

[^1]: $NATURALEARTH_ATTRIBUTION
"""
function earth()
    return get!(LOAD_CACHE, "earth") do
        FileIO.load(assetpath("raster", "50-natural-earth-1-downsampled.png"))
    end
end

"""
    coastlines([scale::Int = 110])

Loads Natural Earth [^1] coastline data as GeometryBasics.jl
geometries.  `scale` may be one of `110`, `50`, or `10`.

$NATURALEARTH_SCALE

[^1]: $NATURALEARTH_ATTRIBUTION
"""
coastlines(scale::Int) = to_multilinestring(geo2basic(NaturalEarth.naturalearth("coastline", scale)))
function coastlines()
    return get!(LOAD_CACHE, "coastlines") do
        geometry = GeoJSON.read(read(assetpath("vector", "110m_coastline.geojson"), String))
        return geo2basic(geometry)
    end
end


"""
    land()

Loads Natural Earth [^1] land polygon data as GeometryBasics.jl geometries.
`scale` may be one of `110`, `50`, or `10`.

$NATURALEARTH_SCALE

[^1]: $NATURALEARTH_ATTRIBUTION
"""
land(scale::Int) = to_multipoly(geo2basic(NaturalEarth.naturalearth("land", scale)))
function land()
    return get!(LOAD_CACHE, "land") do
        geometry = GeoJSON.read(read(assetpath("vector", "110m_land.geojson"), String))
        return geo2basic(geometry)
    end
end

