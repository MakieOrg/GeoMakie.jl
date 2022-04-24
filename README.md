# GeoMakie
## Geographic plotting utilities for Makie.jl <a href = "https://www.github.com/JuliaPlots/Makie.jl"><img src="https://raw.githubusercontent.com/JuliaPlots/Makie.jl/master/assets/logo.png" alt="Makie.jl" height="30" align = "top"></a>

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaPlots.github.io/GeoMakie.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaPlots.github.io/GeoMakie.jl/dev)
[![Build Status](https://gitlab.com/JuliaGPU/GeoMakie-jl/badges/master/pipeline.svg)](https://gitlab.com/JuliaGPU/GeoMakie-jl/pipelines)

## Installation

This package is **in development** and will **break often**.  You can install it from the REPL like so:
```julia
]add GeoMakie
```

# Instructions for the `as/geoaxis` branch
In the terminal (assuming Unix), do the following:

```bash
cd ~/.julia/dev
git clone https://github.com/JuliaGeo/Proj4.jl Proj
cd Proj
git checkout rename
popd

git clone https://github.com/JuliaPlots/GeoMakie.jl GeoMakie
cd GeoMakie
git checkout as/geoaxis
popd
popd
julia -e 'using Pkg; Pkg.add("~/.julia/dev/Proj"); Pkg.add("~/.julia/dev/GeoMakie")'
```

To clean up, delete the repos downloaded in the previous step (in `.julia/dev`)
and run the following in Julia:
```julia
using Pkg
Pkg.rm.(["GeoMakie", "Proj"])
```

Please see the documentation for examples and basic usage.
