assetpath(files...) =  joinpath(dirname(@__DIR__), "assets", files...)

const LOAD_CACHE = Dict{String, Any}()

function earth()
    return get!(LOAD_CACHE, "earth") do
        FileIO.load(assetpath("raster", "50-natural-earth-1-downsampled.png"))
    end
end

function coastlines()
    return get!(LOAD_CACHE, "coastlines") do
        geometry = GeoJSON.read(read(assetpath("vector", "110m_coastline.geojson"), String))
        return geo2basic(geometry)
    end
end


function land()
    return get!(LOAD_CACHE, "land") do
        geometry = GeoJSON.read(read(assetpath("vector", "110m_land.geojson"), String))
        return geo2basic(geometry)
    end
end
