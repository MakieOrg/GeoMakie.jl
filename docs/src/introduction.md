# GeoMakie.jl
GeoMakie.jl is a Julia package for plotting geospatial data on a given map projection. It is based on the [Makie.jl plotting ecosystem](https://docs.makie.org/stable/).

The package [ClimateBase.jl](https://juliaclimate.github.io/ClimateBase.jl/dev/) builds upon GeoMakie.jl to create a seamless workflow between analyzing/manipulating climate data, and plotting them.

## Installation

This package is **in development** and may **break**, although we are currently working on a long-term stable interface.

You can install it from the REPL like so:
```julia
]add GeoMakie
```

## GeoAxis
Using GeoMakie.jl is straightforward, although it does assume basic knowledge of the Makie.jl ecosystem.

GeoMakie.jl provides an axis for plotting geospatial data, `GeoAxis`. Both are showcased in the examples below.

## Ticks, graticule and frame

A `GeoAxis` decorates itself the way an `Axis` does, but on the shape the
projection gives it: the *frame* is the projection's own boundary (an
ellipse for Equal Earth, a circle for an orthographic limb, a rectangle for a
Mercator region), the *graticule* is the set of meridians and parallels
inside it, and the *ticks* sit where those lines leave the frame, with their
labels outside.  Everything here is an attribute of the axis, so it works
through keywords, `ax.attr = value`, and `Theme(GeoAxis = (...,))`.

```@example TICKS
using GeoMakie, CairoMakie

fig = Figure(size = (700, 400))
ax = GeoAxis(fig[1, 1]; dest = "+proj=ortho +lon_0=10 +lat_0=45",
    title = "Orthographic", xminorticksvisible = true, yminorticksvisible = true,
    xminorgridvisible = true, yminorgridvisible = true)
lines!(ax, GeoMakie.coastlines())
fig
```

### What you can set

The vocabulary is `Axis`'s, all of it honoured, plus a few geographic
extensions.  See the docstring of `GeoAxis` for every attribute with its
default.

| Group | Attributes | Behaviour |
|---|---|---|
| Tick values | `xticks`, `yticks`, `xminorticks`, `yminorticks` | The default `GeographicTicks()` picks a step from a geographic ladder (30°, 15°, 10°, 5°, 2°, 1°, 30′, …) sized to the visible extent, and pairs each major step with a minor one (`xminorticks = automatic`).  `ArcMinuteTicks()` runs the ladder in minutes and seconds of arc below one degree.  Any Makie tick finder (`WilkinsonTicks`, `LinearTicks`, `IntervalsBetween` for minors), a vector or range of values, or a `(values, labels)` tuple works too. |
| Formatting | `xtickformat`, `ytickformat` | `automatic` prints hemisphere suffixes (`110°W`, `0°`, `45°N`; `10°30′E` with `ArcMinuteTicks`).  A function of the values, a format string, or `geoformat_ticklabels` are accepted. |
| Placement | `xticklabelpad`, `yticklabelpad`, `xticklabelrotation`, `yticklabelrotation`, `xticklabelalign`, `yticklabelalign`, `xaxisposition`, `yaxisposition` | Labels sit on the outward normal of the frame at their tick, upright; `automatic` alignment centres each label on that normal and can be overridden with a `(horizontal, vertical)` tuple.  On a rectangular frame `xaxisposition` (`:bottom`, `:top`, `:both`) and `yaxisposition` (`:left`, `:right`, `:both`) choose the labelled edges; curved edges label both families. |
| Crowding | `ticklabelminangle`, `ticklabelmingap`, `ticklabelcollisions`, `ticklabelreport` | A line leaving the frame at less than `ticklabelminangle` degrees is not labelled there.  Labels closer than `ticklabelmingap` pixels are thinned, keeping the rounder value and then the one nearer the middle of its edge; `ticklabelcollisions = false` draws them all.  What was dropped is reported at the `ticklabelreport` level (`:debug`, `:info` or `:none`). |
| Interior labels | `interiorlabels`, `carriermeridian`, `carrierparallel`, `interiorlabelsize`, `interiorlabelrotation`, `interiorlabelhalo`, `interiorlabelhalocolor`, `interiorlabelhalowidth` | Graticule lines that never reach the frame (closed parallels on a polar map, meridians converging to a pole) are labelled inside the map beside a carrier line; `:all` labels every line inside as well, `false` none.  The carriers are chosen automatically or set to a meridian / parallel; labels turn along their line and sit on a halo in the background colour. |
| Frame | `framestyle`, `framewidth`, `framecolors`, `spinewidth`, `spinecolor`, `spinevisible`, `outline` | `:plain` strokes the frame; `:fancy` adds a band of `framewidth` pixels outside it alternating between `framecolors` at every tick, on any frame shape.  `outline` replaces the projection's domain with your own lon/lat polygon (or `:dest => points` in projected coordinates). |
| Grid | `xgrid*`, `ygrid*`, `xminorgrid*`, `yminorgrid*`, `gridbehind` | Colour, width, style and visibility as on `Axis`; the graticule draws behind the plots by default (`gridbehind = false` puts it in front). |
| Background | `backgroundcolor`, `maskoutside` | The background fills the axis area; whatever plots draw outside the frame is covered with it (`maskoutside = false` leaves it), so data beyond a limb never runs under the labels. |
| Layout | `title`, `subtitle`, `xlabel`, `ylabel` and their style attributes | Drawn natively; a `GeoAxis` beside an `Axis` with the same decorations takes the same space.  `xlabelpadding` / `ylabelpadding` pad the axis labels, as on `Axis`. |

`hidedecorations!`, `hidexdecorations!`, `hideydecorations!` and
`hidespines!` work as on `Axis` (a map's frame is one closed curve, so
`hidespines!` hides all of it).  `tight_ticklabel_spacing!(ax)` shrinks the
reserved margin to exactly what the drawn labels need, which matters on a
curved frame.  Spine and grid colours follow the `Axis` theme, so
`with_theme(theme_dark())` styles both kinds of axis alike.

### Frame styles and interior labels

```@example TICKS
fig = Figure(size = (800, 350))
ax1 = GeoAxis(fig[1, 1]; dest = "+proj=laea +lat_0=90", limits = ((-180, 180), (40, 90)),
    title = "Interior labels on a polar map")
ax2 = GeoAxis(fig[1, 2]; dest = "+proj=merc", limits = ((-1, 1), (50, 51.5)),
    framestyle = :fancy, framewidth = 8, framecolors = (:black, :white),
    xticks = ArcMinuteTicks(), yticks = ArcMinuteTicks(), title = "A fancy frame, arc-minute ticks")
lines!(ax1, GeoMakie.coastlines()); lines!(ax2, GeoMakie.coastlines())
fig
```

The parallels of the polar map are closed curves that never meet the frame,
so they carry their labels inside, beside the carrier meridian; the
meridians all reach the frame and are labelled there.  Set
`interiorlabels = false` to draw none, or `carriermeridian = 0` to move them.

### Custom ticks and formats

```@example TICKS
fig = Figure(size = (700, 400))
ax = GeoAxis(fig[1, 1]; dest = "+proj=eqearth",
    xticks = -180:60:180, yticks = ([-66.5, -23.5, 0, 23.5, 66.5], ["Antarctic", "Capricorn", "Equator", "Cancer", "Arctic"]),
    xtickformat = v -> string.(round.(Int, v), "°"), yaxisposition = :both, ticklabelmingap = 6)
lines!(ax, GeoMakie.coastlines())
fig
```

### The scene's transformation

Plots inherit the axis scene's `transformation`, so `scale!(ax.scene, 1, -1, 1)`
or `rotate!(ax.scene, ...)` flips or turns the map; the frame, graticule and
labels follow (a south-up map is labelled on its flipped edges).

### Reference images

The tests in `test/refimages` render every decoration case and compare the
pictures against a reference set attached to the GitHub release
`refimages-<major.minor>`, using Makie's (unregistered) `ReferenceTests`.
To run that gallery locally add it to the test environment once,
`using TestEnv; TestEnv.activate(); using Pkg; Pkg.add(url = "https://github.com/MakieOrg/Makie.jl", subdir = "ReferenceTests", rev = "a76df399a4ee8631ee3ba6587ca052dd902dfe74")`,
then `include("test/runtests.jl")`; without it the gallery is skipped.
The rendered set, the references and the diffs are written to
`test_images/refimages/`, with `review.html` beside them.


## Gotchas

When plotting a projection which has a limited domain (in either longitude or latitude), if your limits are not inside that domain, the axis will appear blank.  To fix this, simply correct the limits - you can even do it on the fly, using the `xlims!(ax, low, high)` or `ylims!(ax, low, high)` functions.

## Useful data sources

- [NaturalEarth.jl](https://github.com/JuliaGeo/NaturalEarth.jl) provides access to all of the Natural Earth datasets, like coastlines, land polygons, country borders, rivers, and so on.
- [GADM.jl](https://github.com/JuliaGeo/GADM.jl) provides access to the GADM cultural data, including the borders of all countries and their sub-divisions,from the GADM dataset (https://gadm.org/)..
- [GeoDatasets.jl](https://github.com/JuliaGeo/GeoDatasets.jl) provides access to the GSHHG dataset.
- [RasterDataSources.jl](https://github.com/EcoJulia/RasterDataSources.jl) 

## Examples

### Surface example
```@example MAIN
using GeoMakie, CairoMakie

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

fig = Figure()
ax = GeoAxis(fig[1,1])
surface!(ax, lons, lats, field; shading = NoShading)
fig
```

### Scatter example
```@example MAIN
using GeoMakie, CairoMakie

lons = -180:180
lats = -90:90
slons = rand(lons, 2000)
slats = rand(lats, 2000)
sfield = [exp(cosd(l)) + 3(y/90) for (l,y) in zip(slons, slats)]

fig = Figure()
ax = GeoAxis(fig[1,1])
scatter!(slons, slats; color = sfield)
fig
```

### Map projections
The default projection is given by the arguments `source = "+proj=longlat +datum=WGS84", dest = "+proj=eqearth"`, so that if a different one is needed, for example a `wintri` projection one can do it as follows:
```@example MAIN
using GeoMakie, CairoMakie

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

fig = Figure()
ax = GeoAxis(fig[1,1]; dest = "+proj=wintri")
surface!(ax, lons, lats, field; shading = NoShading)
fig
```

### Changing central longitude
Be careful! Each data point is transformed individually.
However, when using `surface` or `contour` plots this can lead to errors when the longitudinal dimension "wraps" around the planet.

E.g., if the data have the dimensions

```@example MAIN
lons = 0.5:359.5
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats];
```
a `surface!` plot with the default arguments will lead to artifacts if the data along longitude 179 and 180 have significantly different values.
To fix this, there are two approaches: (1) to change the central longitude of the map transformation, by changing the projection destination used like so:

```julia
ax = GeoAxis(fig[1,1]; dest = "+proj=eqearth +lon_0=180")
```

_or_ (2), circshift your data appropriately so that the central longitude you want coincides with the center of the longitude dimension of the data.

### Countries loaded with GeoJSON
```@example MAIN
using GeoMakie, CairoMakie

# First, make a surface plot
lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

fig = Figure()
ax = GeoAxis(fig[1,1])
sf = surface!(ax, lons, lats, field; shading = NoShading)
cb1 = Colorbar(fig[1,2], sf; label = "field", height = Relative(0.65))

using NaturalEarth
countries = naturalearth("admin_0_countries", 110)

n = length(countries)
hm = poly!(ax, GeoMakie.to_multipoly(countries.geometry); color= 1:n, colormap = :dense,
    strokecolor = :black, strokewidth = 0.5,
)
translate!(hm, 0, 0, 100) # move above surface plot

fig
```

## Gotchas

With **CairoMakie**, we recommend that you use `image!(ga, ...)` or `heatmap!(ga, ...)` to plot images or scalar fields into `ga::GeoAxis`.

However, with **GLMakie**, which is much faster, these methods do not work; if you have used them, you will see an empty axis.  If you want to plot an image `img`, you can use a surface in the following way:
`surface!(ga, lonmin..lonmax, latmin..latmax, ones(size(img)...); color = img, shading = NoShading)`.

To plot a scalar field, simply use `surface!(ga, lonmin..lonmax, latmin..latmax, field)`.  The `..` notation denotes an interval which Makie will automatically sample from to obtain the x and y points for the surface.



## API

```@docs
GeoMakie.to_multipoly
GeoMakie.geo2basic
GeoMakie.geoformat_ticklabels

```

`GeoAxis`, `meshimage`, and the rest of the public API are documented on the
[API reference](@ref) page.
