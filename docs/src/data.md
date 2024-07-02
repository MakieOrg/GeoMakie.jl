# Data

In general, geographic data is classified into two types - _vector_ data and _raster_ data.

Vector data uses points and line segments to identify locations on the earth, and collects those into "feature collections" with associated values, while raster data uses a series of cells to represent locations on the earth.[^esri_raster_faster]

Vector data are usually plotted by `lines`, `scatter`, or `poly`, and raster data are usually plotted by `surface`, `meshimage`, or `heatmap`.

## GeoMakie sources

GeoMakie.jl provides three functions to get plottable data for your map.  These methods provide data from [Natural Earth](https://www.naturalearthdata.com/).  You can pass the output straight to Makie plotting functions like `lines`, `poly` or `image` (for `earth`).

```@docs
GeoMakie.coastlines
GeoMakie.land
GeoMakie.earth
```

## External sources 

The Julia package ecosystem has several sources which provide geographic data from various sources.  

- [NaturalEarth.jl](https://github.com/JuliaGeo/NaturalEarth.jl) - get data from [Natural Earth](https://www.naturalearthdata.com/).
- [GADM.jl](https://github.com/JuliaGeo/GADM.jl) - get data from [GADM](https://gadm.org/), a database of political borders for countries, down to state and even province-equivalent level.
- [GeoDatasets.jl](https://github.com/JuliaGeo/GeoDatasets.jl) - currently provides access to [GSHHG](https://www.soest.hawaii.edu/pwessel/gshhg/).
- [GMT.jl](https://github.com/JuliaGeo/GMT.jl) - provides access to the [GMT](https://www.generic-mapping-tools.org/) library, which has quite a bit of data as well as being another geographic plotting library!
- [RasterDataSources.jl](https://github.com/EcoJulia/RasterDataSources.jl) - provides access to various raster datasets via [Rasters.jl](https://github.com/rafaqz/Rasters.jl).  See their documentation for the full list!

## Loading data yourself

- Vector data loaders:
    - Native Julia: [GeoJSON.jl](https://github.com/JuliaGeo/GeoJSON.jl), [Shapefile.jl](https://github.com/JuliaGeo/Shapefile.jl), [GeoParquet.jl](https://github.com/JuliaGeo/GeoParquet.jl), [WellKnownGeometry.jl](https://github.com/evetion/WellKnownGeometry.jl)
    - [GeoDatasets.jl](https://github.com/evetion/GeoDatasets.jl), which wraps ArchGDAL.jl to return a DataFrame.
    - [ArchGDAL.jl](https://github.com/yeesian/ArchGDAL.jl), and the more primitive [GDAL.jl](https://github.com/yeesian/GDAL.jl), which wraps the [GDAL](https://gdal.org/) library (used by R's `sf`).
- Raster data loaders
    - [Rasters.jl](https://github.com/rafaqz/Rasters.jl).
    - [NCDatasets.jl](https://github.com/JuliaGeo/NCDatasets.jl)
    - [ArchGDAL.jl](https://github.com/yeesian/ArchGDAL.jl) (used by Rasters.jl as well)



[^esri_raster_faster]: https://www.esri.com/content/dam/esrisites/en-us/media/pdf/teach-with-gis/raster-faster.pdf

