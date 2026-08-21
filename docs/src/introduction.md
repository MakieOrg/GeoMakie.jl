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

### Tick label placement

`GeoAxis` reads its tick labels off the projected graticule, so where a label
goes depends on the shape of the map and not only on the value of the tick.  Two
placement rules are available, independently per axis.  `:axis`, the default,
keeps a longitude label directly below its meridian and a latitude label
directly beside its parallel, the way a Cartesian `Axis` does.  `:normal`
instead moves each label straight out of the map along the local boundary
normal, which follows a curved or oblique map outline rather than cutting across
it.

```@example MAIN
using GeoMakie, CairoMakie

fig = Figure(size = (900, 340))
for (i, placement) in enumerate((:axis, :normal))
    ax = GeoAxis(fig[1, i];
        dest = "+proj=robin",
        xticks = -180:60:180, yticks = -60:30:60,
        xticklabelplacement = placement, yticklabelplacement = placement,
        title = ":$placement",
    )
    lines!(ax, GeoMakie.coastlines(); color = :gray50, linewidth = 0.5)
end
fig
```

Both rules work in pixel space and honour `xticklabelpad`, `yticklabelpad`, and
tick-label rotation, and both clear the map boundary by the requested padding.
Where a boundary is too steep for `:axis` placement to reach it without sending
the label a long way down the page, the direction rotates towards the normal for
that one label rather than the label being dropped.

A label that could be placed is then left out in two cases.  The first is a
collision: two labels whose glyph boxes would touch cannot both be drawn, and
the one nearer the middle of its side wins.  The second is a shared anchor:
where a meridian and a parallel end on the same pixel -- a corner of the frame,
or a pole where every meridian converges -- neither label says which of the two
it names, so both go, unless that would leave the axis with no labels at all.

A graticule that does not reach the map boundary carries no label in the first
place.  That covers a meridian ending at the pole of a polar projection, in the
middle of the map; the parallels of the same projection, which are closed
circles with no endpoint at all; and the meridians of a full orthographic, whose
limb is not a graticule and so gives them no boundary direction to clear.
Labelling a closed parallel would need radial placement, which `GeoAxis` does
not do.

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
