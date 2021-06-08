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
    source = LonLat()
    dest = WinkelTripel()
    states = Downloads.download("https://raw.githubusercontent.com/PublicaMundi/MappingAPI/master/data/geojson/us-states.json")
    states_geo = GeoJSON.read(read(states, String))
    lons = LinRange(-179.5, 179.5, 360 ÷ 2)
    lats = LinRange(-89.5, 89.5, 180 ÷ 2)
    field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]
    points = map(CartesianIndices(size(field))) do xy
        x, y = Tuple(xy)
        Point2f0(lons[x], lats[y])
    end

    proj = GeoMakie.proj(source, dest)
    limits = FRect2D(Makie.apply_transform(proj, points))
    fig = Figure()

    ax = Axis(fig[1,1])
    limits!(limits)
    ax.scene.transformation.transform_func[] = proj

    wireframe!(ax, lons, lats, field, color=(:gray, 0.2), transparency=true)
    n = length(GeoInterface.features(states_geo))
    lines!(ax, GeoMakie.coastlines())
    poly!(ax, states_geo, color= 1:n, strokecolor = :blue, strokewidth = 1)
    display(fig)
end
```
![image](https://user-images.githubusercontent.com/1010467/104816235-04ed8100-581a-11eb-9c40-abbc752524f7.png)

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
