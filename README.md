# GeoMakie
## Geographic plotting utilities for <a href = "https://www.github.com/JuliaPlots/Makie.jl"><img src="https://raw.githubusercontent.com/JuliaPlots/Makie.jl/master/assets/logo.png" alt="Makie.jl" height="30" align = "top"></a>

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaPlots.github.io/GeoMakie.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaPlots.github.io/GeoMakie.jl/dev)
[![Build Status](https://gitlab.com/JuliaGPU/GeoMakie-jl/badges/master/pipeline.svg)](https://gitlab.com/JuliaGPU/GeoMakie-jl/pipelines)

## Installation

This package is **in development** and will **break often**.  You can install it from the REPL like so:
```julia
]add GeoMakie
```

## Examples

```julia
using GLMakie
using GeoMakie
using GeoMakie.GeoInterface
using GeoMakie.GeoJSON
using Downloads

begin
    # select a coordinate projection, using a string that PROJ accepts
    # see e.g. https://proj.org/operations/projections/index.html
    source = "+proj=longlat +datum=WGS84"
    dest = "+proj=natearth2"
    trans = Proj4.Transformation(source, dest, always_xy=true)

    fig = Figure()
    ax = Axis(fig[1,1], aspect = DataAspect())

    # all input data coordinates are projected using this function
    ax.scene.transformation.transform_func[] = Makie.PointTrans{2}(trans)

    # draw projected grid lines and set limits accordingly
    lons = -180:10:180
    lats = -90:10:90
    field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]
    points = map(CartesianIndices(size(field))) do xy
        x, y = Tuple(xy)
        Point2f0(lons[x], lats[y])
    end
    limits = FRect2D(Makie.apply_transform(ptrans, points))
    limits!(ax, limits)
    wireframe!(ax, lons, lats, field, color=(:gray, 0.2), transparency=true)

    # add black polygons for land area
    url = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"
    land = Downloads.download(url * "ne_110m_land.geojson", IOBuffer())
    land_geo = GeoJSON.read(seekstart(land))
    poly!(ax, land_geo, color="black")

    # add grey dots for populated places
    pop = Downloads.download(url * "ne_10m_populated_places_simple.geojson", IOBuffer())
    pop_geo = GeoJSON.read(seekstart(pop))
    scatter!(ax, GeoMakie.geo2basic(pop_geo), color="lightgrey", markersize=1.2)

    hidedecorations!(ax)
    hidespines!(ax)
    display(fig)
end
```
![image](https://user-images.githubusercontent.com/4471859/123479757-ad8de100-d601-11eb-9745-82e0685e8163.png)

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
