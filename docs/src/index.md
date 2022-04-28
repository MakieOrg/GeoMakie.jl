# GeoMakie.jl
GeoMakie.jl is a Julia package for plotting geospatial data on a given map projection. It is based on the [Makie.jl plotting ecosystem](https://makie.juliaplots.org/stable/).

The package [ClimateBase.jl](https://juliaclimate.github.io/ClimateBase.jl/dev/) builds upon GeoMakie.jl to create a seamless workflow between analyzing/manipulating climate data, and plotting them.

## Installation

This package is **in development** and may **break**, although we are currently working on a long-term stable interface.

You can install it from the REPL like so:
```julia
]add GeoMakie
```

## GeoAxis
Using GeoMakie.jl is straightforward, although it does assume basic knowledge of the Makie.jl ecosystem.

GeoMakie.jl provides an axis for plotting geospatial data, [`GeoAxis`](@ref), and also the function [`geo2basic`](@ref) that converts an output of GeoJSON to a polygon appropriate for plotting. Both are showcased in the examples below.

```@docs
GeoAxis
geo2basic
```

## Gotchas

When plotting a projection which has a limited domain (in either longitude or latitude), if your limits are not inside that domain, the axis will appear blank.  To fix this, simply correct the limits - you can even do it on the fly, using the `xlims!(ax, low, high)` or `ylims!(ax, low, high)` functions.

## Examples

### Surface example
```@example MAIN
using GeoMakie, CairoMakie

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

fig = Figure()
ax = GeoAxis(fig[1,1])
surface!(ax, lons, lats, field; shading = false)
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
surface!(ax, lons, lats, field; shading = false)
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
sf = surface!(ax, lons, lats, field; shading = false)
cb1 = Colorbar(fig[1,2], sf; label = "field", height = Relative(0.65))

using GeoMakie.GeoJSON
countries_file = download("https://datahub.io/core/geo-countries/r/countries.geojson")
countries = GeoJSON.read(read(countries_file, String))

n = length(GeoInterface.features(countries))
hm = poly!(ax, countries; color= 1:n, colormap = :dense,
    strokecolor = :black, strokewidth = 0.5, overdraw = true,
)

# cb2 = Colorbar(fig[1,3], hm; label = "countries index", height = Relative(0.65))

fig
```

## Gotchas

With **CairoMakie**, we recommend that you use `image!(ga, ...)` or `heatmap!(ga, ...)` to plot images or scalar fields into `ga::GeoAxis`.

However, with **GLMakie**, which is much faster, these methods do not work.  If you want to plot an image `img`, you can use a surface in the following way: `surface!(ga, lonmin..lonmax, latmin..latmax, ones(size(img)...); color = img, shading = false)`.  To plot a scalar field, simply use `surface!(ga, lonmin..lonmax, latmin..latmax, field)`.  The `..` notation denotes an interval which Makie will automatically sample from to obtain the x and y points for the surface.
