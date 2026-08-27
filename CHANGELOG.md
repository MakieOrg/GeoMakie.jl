# Unreleased
- Reworked `GeoAxis` tick-label placement.
    - New `xticklabelplacement` and `yticklabelplacement` attributes, `:axis` (default) or `:normal`, choosing whether a label moves along its axis or straight out along the projected boundary normal.
    - `xticklabelpad`, `yticklabelpad`, `xtickformat`, `ytickformat`, and tick-label rotation are now applied; previously they were declared but ignored.
    - A label is no longer dropped because a fixed pixel budget was exceeded; steep boundaries rotate towards normal placement instead. Oblique and large-font maps that previously lost most or all of one axis now keep their labels, and polar projections keep their meridian labels.
    - A graticule that does not reach the map boundary no longer gets a label drawn over the data. This covers the parallels of a polar projection, which are closed circles in the middle of the map; labelling those needs radial placement, which is not implemented. Labels are also still left out for a collision or for an anchor shared with the orthogonal axis.
    - Tick labels report their exact tick value. A zoomed range such as `limits = ((-122.6, -122.2), (37.6, 37.9))` used to render five labels all reading `-122ᵒ`.
    - Graticules are traced across the whole visible extent rather than only the requested limits, and are clipped with Liang--Barsky, so a parallel no longer stops in the middle of the map.
    - The visible extent is now found by sampling the view and unwrapping longitude, rather than by inverse-projecting the corners of the projected view rectangle. Those corners can be outside the projection, and the longitudes they invert to are wrapped, so a whole-world map with a central meridian away from zero used to report a sliver of longitude either side of it. Every parallel then ended, and was labelled, near the middle of the map: `+proj=robin +lon_0=150` reported an extent of `(-176, 177)` instead of `(-30, 330)`.
    - Tick-label padding is measured along the direction the label moves rather than along the boundary normal, so a column of latitude labels follows a curved limb at a constant gap. Measuring along the normal inflated the gap by 1/cos of the incidence: 5 pixels at the equator became 19 at 60 degrees on a full-world Robinson map.
    - Rich text and LaTeX tick labels are measured as laid out instead of being flattened with `string`. LaTeX rules -- fraction bars, square roots -- are not included in the measurement, so a label dominated by them measures slightly small.
    - Removed the unused internal helpers `text_bbox`, `find_outvec`, and `directional_pad`.

# 0.6.3
- Converted all internal computations to use `Float64` instead of `Float32` thanks to @ffreyer's work in Makie.jl v0.21.
    - Consequently, the `PROJ_RESCALE_FACTOR` hack is also removed.
    - Zooming in close should also work now, with the correct ticks being shown.
- Added the option to provide an integer `scale` in `coastlines` and `land`, which triggers GeoMakie to get data from [NaturalEarth.jl](https://github.com/JuliaGeo/NaturalEarth.jl) instead of using the bundled data.
- Updated the `to_multipoly` function to use GeoInterface traits, so that it's more universal.
- Added several new examples - `tissot.jl`, `source_crs.jl`, etc.
