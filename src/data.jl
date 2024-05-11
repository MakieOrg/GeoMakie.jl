assetpath(files...) =  joinpath(dirname(@__DIR__), "assets", files...)

const LOAD_CACHE = Dict{String, Any}()

"""
    earth()

Loads the Natural Earth [^1] 50m raster illustration of Earth as an image.

[^1]: Made with Natural Earth. Free vector and raster map data at [naturalearthdata.com](https://www.naturalearth.com).
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

By default, a scale of 110m is used, for which data is shipped with GeoMakie.
To use other scales, NaturalEarth.jl uses an Internet connection.

[^1]: Made with Natural Earth. Free vector and raster map data at [naturalearthdata.com](https://www.naturalearth.com).
"""
coastlines(scale::Int) = geo2basic(NaturalEarth.naturalearth("coastline", scale))
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

By default, a scale of 110m is used, for which data is shipped with GeoMakie.
To use other scales, NaturalEarth.jl uses an Internet connection.

[^1]: Made with Natural Earth. Free vector and raster map data at [naturalearthdata.com](https://www.naturalearth.com).
"""
land(scale::Int) = geo2basic(NaturalEarth.naturalearth("land", scale))
function land()
    return get!(LOAD_CACHE, "land") do
        geometry = GeoJSON.read(read(assetpath("vector", "110m_land.geojson"), String))
        return geo2basic(geometry)
    end
end

