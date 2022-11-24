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

function coastlines_10m()
    # https://www.naturalearthdata.com/downloads/10m-physical-vectors/10m-coastline/
    temppath = abspath(joinpath(homedir(), "Downloads/ne_10m_coastline/ne_10m_coastline.shp"))
    geoms = Shapefile.shapes(Shapefile.Table(temppath))
    return map(geo2basic, geoms)
end

function land_50m()
    # https://www.naturalearthdata.com/downloads/50m-physical-vectors/50m-land/
    temppath = abspath(joinpath(homedir(), "Downloads/ne_50m_land/ne_50m_land.shp"))
    geoms = Shapefile.shapes(Shapefile.Table(temppath))
    return map(geo2basic, geoms)
end

"""
Adds support for ocean bathymetry datasets.
Currently tested on: https://www.naturalearthdata.com/downloads/10m-physical-vectors/10m-bathymetry/
(download all data)

The function returns a MultiPolygon describing the bathymetry at a given depth contour.

The following depths should be available: [10000, 9000, 8000, 7000, 6000, 5000, 4000, 3000, 2000, 1000, 200, 0]
"""
function bathymetry(contour::Int=2000)
    path = abspath(joinpath(homedir(), "Downloads/ne_10m_bathymetry_all/"))
    bathyfiles = filter(x-> endswith(x, ".shp"), readdir(path; join=true))
    # Extract depth signifier from filename
    depths = parse.(Int, getfield.(match.(r"\d+(?=.shp)", bathyfiles), :match))
    # Extract the file corresponding to the contour
    fileind = findfirst(==(contour), depths)
    isnothing(fileind) && error("Contour $contour not found. Available contours: $depths")
    
    # Open bathymetry file
    bathyfile = bathyfiles[fileind]
    geoms = Shapefile.shapes(Shapefile.Table(bathyfile))
    poly_multipoly = map(geo2basic, geoms)
    many_poly = reduce(vcat, poly_multipoly)  # flatten multiple Polygons and MultiPolygons to many Polygons
    return GeometryBasics.MultiPolygon(many_poly)  # turn all single Polygons into a single MultiPolygon
end

"""
Ocean bottom, similar to `earth()`, but higher resolution, at 50m.

Download here: https://www.naturalearthdata.com/downloads/50m-ocean-bottom/50m-ocean-bottom/

Plot by:
```julia
julia> bathy = oceanbottom_50m()

julia> img = image!(-180..180, -90..90, rotr90(bathy); interpolate = false)
```
"""
function oceanbottom_50m()
    path = abspath(joinpath(homedir(), "Downloads/OB_50M/OB_50M.tif"))
    return FileIO.load(path)
end
