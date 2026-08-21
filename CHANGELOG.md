# Unreleased
- Reworked `GeoAxis` tick-label placement.
    - New `xticklabelplacement` and `yticklabelplacement` attributes, `:axis` (default) or `:normal`, choosing whether a label moves along its axis or straight out along the projected boundary normal.
    - `xticklabelpad`, `yticklabelpad`, `xtickformat`, `ytickformat`, and tick-label rotation are now applied; previously they were declared but ignored.
    - A label is no longer dropped because a fixed pixel budget was exceeded; steep boundaries rotate towards normal placement instead. Oblique and large-font maps that previously lost most or all of one axis now keep their labels, and polar projections keep their meridian labels.
    - A graticule that does not reach the map boundary no longer gets a label drawn over the data. This covers the parallels of a polar projection, which are closed circles in the middle of the map; labelling those needs radial placement, which is not implemented. Labels are also still left out for a collision or for an anchor shared with the orthogonal axis.
    - Tick labels report their exact tick value. A zoomed range such as `limits = ((-122.6, -122.2), (37.6, 37.9))` used to render five labels all reading `-122ᵒ`.
    - Graticules are traced across the whole visible extent rather than only the requested limits, and are clipped with Liang--Barsky, so a parallel no longer stops in the middle of the map.
    - Rich text and LaTeX tick labels are measured as laid out instead of being flattened with `string`. LaTeX rules -- fraction bars, square roots -- are not included in the measurement, so a label dominated by them measures slightly small.
    - Removed the unused internal helpers `text_bbox`, `find_outvec`, and `directional_pad`.

# 0.6.3
- Converted all internal computations to use `Float64` instead of `Float32` thanks to @ffreyer's work in Makie.jl v0.21.
    - Consequently, the `PROJ_RESCALE_FACTOR` hack is also removed.
    - Zooming in close should also work now, with the correct ticks being shown.
- Added the option to provide an integer `scale` in `coastlines` and `land`, which triggers GeoMakie to get data from [NaturalEarth.jl](https://github.com/JuliaGeo/NaturalEarth.jl) instead of using the bundled data.
- Updated the `to_multipoly` function to use GeoInterface traits, so that it's more universal.
- Added several new examples - `tissot.jl`, `source_crs.jl`, etc.
