# 0.6.3
- Converted all internal computations to use `Float64` instead of `Float32` thanks to @ffreyer's work in Makie.jl v0.21.
    - Consequently, the `PROJ_RESCALE_FACTOR` hack is also removed.
    - Zooming in close should also work now, with the correct ticks being shown.
- Added the option to provide an integer `scale` in `coastlines` and `land`, which triggers GeoMakie to get data from [NaturalEarth.jl](https://github.com/JuliaGeo/NaturalEarth.jl) instead of using the bundled data.
- Updated the `to_multipoly` function to use GeoInterface traits, so that it's more universal.
- Added several new examples - `tissot.jl`, `source_crs.jl`, etc.
