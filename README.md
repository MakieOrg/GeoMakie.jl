# GeoMakie
## Geographic plotting utilities for [Makie.jl](https://github.com/JuliaPlots/Makie.jl)

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaPlots.github.io/GeoMakie.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaPlots.github.io/GeoMakie.jl/dev)
[![Build Status](https://travis-ci.com/JuliaPlots/GeoMakie.jl.svg?branch=master)](https://travis-ci.com/JuliaPlots/GeoMakie.jl)
[![Build Status](https://gitlab.com/JuliaPlots/GeoMakie.jl/badges/master/build.svg)](https://gitlab.com/JuliaPlots/GeoMakie.jl/pipelines)
[![Coverage](https://gitlab.com/JuliaPlots/GeoMakie.jl/badges/master/coverage.svg)](https://gitlab.com/JuliaPlots/GeoMakie.jl/commits/master)

## Installation

This package is **in development** and will **break often**.  As it is currently unregistered, you can install it from the REPL like so:
```julia
]add https://github.com/JuliaPlots/GeoMakie.jl
```

## Examples

```julia
using GeoMakie, Makie, NASAEarthObservations, Glob, ImageMagick

source = LonLat()
dest = WinkelTripel()

imgdir = observations("rgb/MYDAL2_M_AER_RA")

imgpaths = sort(Glob.glob(joinpath(relpath(imgdir), "*.PNG"))) # change this to your requirements

img = ImageMagick.load(imgpaths[1])

re = GeoMakie.date_regex("MYDAL2_M_AER_RA", "PNG")
titletext = Node(join(match(re, basename(imgpaths[1])).captures, '-'))

lons = LinRange(-179.5, 179.5, size(img)[2])
lats = LinRange(89.5, -89.5, size(img)[1])

xs = [lon for lat in lats, lon in lons]
ys = [lat for lat in lats, lon in lons]

Proj4.transform!(source, dest, vec(xs), vec(ys))

scene = surface(xs, ys, zeros(size(xs)); color = img, shading = false, show_axis = false)
geoaxis!(scene, -180, 180, -90, 90; crs = (src = src, dest = dest,))
```
![aerosol](https://user-images.githubusercontent.com/32143268/73116039-d3d7ba80-3efd-11ea-9d75-fb5cb6dd1318.png)

These plots can be arbitrarily colored using the `color` keyword, and the full Makie interface is also exposed.

Check the examples in the `test` folder for more recent examples of usage.

## Performance

We use Earcut.jl for added performance when converting polygons to triangular meshes; it decreases time to mesh by an order of magnitude from the Makie implementation.

Since `surface` has an optimized shader, and can accept matrices of deformed grid points, it's **heavily** recommended to use it (or `mesh` if you need the flexibility) over `poly`.

## Planned features
- A `choropleth` recipe which can read data from the properties of a FeatureCollection
- helper functions to extract "columns" of a FeatureCollection

## More examples
```julia
using GeoJSON, GeoMakie, Makie
states = download("https://raw.githubusercontent.com/PublicaMundi/MappingAPI/master/data/geojson/us-states.json")

states_geo = GeoJSON.parse(read(states, String))

poly(states_geo, strokecolor = :blue, strokewidth = 1)
```
![US simple example](https://user-images.githubusercontent.com/32143268/73116030-c6223500-3efd-11ea-9690-f5a92415c264.png)
