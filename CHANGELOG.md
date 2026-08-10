# Unreleased
- `contour` and `contourf` on a `GeoAxis` are now **antimeridian-aware**: filled bands and contour lines that cross the projection's antimeridian (`lon_0 ± 180`) are split at the seam before projection, fixing the horizontal "smear" artifact. The inserted seam edges are densified so they follow the projected meridian (no straight chords across a curved projection boundary). This also works for **curvilinear** grids (2-D `x`/`y` coordinate matrices), e.g. tripolar ocean grids ([Makie.jl#4885](https://github.com/MakieOrg/Makie.jl/issues/4885)). See the new `antimeridian_contours` example.
- Added `add_cyclic_point` (analogous to `cartopy.util.add_cyclic_point`) to wrap longitude-periodic gridded data so `contourf`/`contour`/`surface`/`heatmap` close cleanly across the periodic grid boundary. Works for both rectilinear (vector longitudes) and curvilinear (matrix longitudes) grids.

# 0.6.3
- Converted all internal computations to use `Float64` instead of `Float32` thanks to @ffreyer's work in Makie.jl v0.21.
    - Consequently, the `PROJ_RESCALE_FACTOR` hack is also removed.
    - Zooming in close should also work now, with the correct ticks being shown.
- Added the option to provide an integer `scale` in `coastlines` and `land`, which triggers GeoMakie to get data from [NaturalEarth.jl](https://github.com/JuliaGeo/NaturalEarth.jl) instead of using the bundled data.
- Updated the `to_multipoly` function to use GeoInterface traits, so that it's more universal.
- Added several new examples - `tissot.jl`, `source_crs.jl`, etc.
