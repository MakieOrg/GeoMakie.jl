# GeoMakie
## Geographic plotting utilities for [Makie.jl](https://github.com/JuliaPlots/Makie.jl)

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://asinghvi17.github.io/GeoMakie.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://asinghvi17.github.io/GeoMakie.jl/dev)
[![Build Status](https://travis-ci.com/asinghvi17/GeoMakie.jl.svg?branch=master)](https://travis-ci.com/asinghvi17/GeoMakie.jl)
[![Build Status](https://gitlab.com/asinghvi17/GeoMakie.jl/badges/master/build.svg)](https://gitlab.com/asinghvi17/GeoMakie.jl/pipelines)
[![Coverage](https://gitlab.com/asinghvi17/GeoMakie.jl/badges/master/coverage.svg)](https://gitlab.com/asinghvi17/GeoMakie.jl/commits/master)

## Installation

This package is **in development** and will **break often**.  As it is currently unregistered, you can install it from the REPL like so:
```julia
]add https://github.com/JuliaPlots/GeoMakie.jl
```

## Examples

```julia
using GeoJSON, GeoMakie, Makie
states = download("https://raw.githubusercontent.com/PublicaMundi/MappingAPI/master/data/geojson/us-states.json")

states_geo = GeoJSON.parse(read(states, String))

poly(states_geo, strokecolor = :blue, strokewidth = 1)
```
![US simple example](assets/us-simple.png)

These plots can be arbitrarily colored using the `color` keyword, and the Makie poly interface is also exposed.
All that this package is (as of now) is some definitions for argument conversion.
