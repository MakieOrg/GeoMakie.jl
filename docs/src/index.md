# GeoMakie.jl
GeoMakie.jl is a Julia package for plotting geospatial data on a given map projection. It is based on the [Makie.jl plotting ecosystem](https://makie.juliaplots.org/stable/).

The package [ClimateBase.jl](https://juliaclimate.github.io/ClimateBase.jl/dev/) builds upon GeoMakie.jl to create a seamless workflow between analyzing/manipulating climate data, and plotting them.


## API
Using GeoMakie.jl is straightforward, although it does assume basic knowledge of the Makie.jl ecosystem. 

GeoMakie.jl provides an axis for plotting geospatial data, [`GeoAxis`](@ref), and also the function [`geo2basic`](@ref) that converts an output of GeoJSON to a polygon appropriate for plotting. Both are showcased in the examples below.

```@docs
GeoAxis
geo2basic
```


## Examples

### Surface example
```@example MAIN
using GeoMakie, CairoMakie

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

fig = Figure()
ax = GeoAxis(fig[1,1])
el = surface!(ax, lons, lats, field)
display(fig)
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
el = scatter!(slons, slats; color = sfield)
display(fig)
```

### Different map projection
```@example MAIN
using GeoMakie, CairoMakie

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

fig = Figure()
ax = GeoAxis(fig[1,1])
el = surface!(ax, lons, lats, field)
display(fig)
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

```@example MAIN
fig = Figure()
ax = GeoAxis(fig[1,1]; dest = "eqearth +lon_0=180")
el = surface!(ax, lons, lats, field)
display(fig)
```

_or_ (2), circshift your data appropriately so that the central longitude you want coincides with the center of the longitude dimension of the data.

### Countries loaded with GeoJSON
```@example MAIN
using GeoMakie, CairoMakie
using Downloads

# First, make a surface plot
using GeoMakie, CairoMakie

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

fig = Figure()
ax = GeoAxis(fig[1,1])
el = surface!(ax, lons, lats, field)
display(fig)

# TODO: Finish this.

download("https://datahub.io/core/geo-countries/datapackage.json", "countries.geojson")
countries = GeoJSON.read(read("countries.geojson"))
```


### Submarine cables
```@example MAIN
using GeoMakie, CairoMakie
using Downloads # for downloading the cable data
using GeoJSON   # for reading cable data
# notice that `GeoInterface` is a module name also exported by GeoMakie

# data from https://github.com/telegeography/www.submarinecablemap.com
urlPoints = "https://raw.githubusercontent.com/telegeography/www.submarinecablemap.com/master/web/public/api/v3/landing-point/landing-point-geo.json"
urlCables = "https://raw.githubusercontent.com/telegeography/www.submarinecablemap.com/master/web/public/api/v3/cable/cable-geo.json"

landPoints = Downloads.download(urlPoints, IOBuffer())
landCables = Downloads.download(urlCables, IOBuffer())
land_geoPoints = GeoJSON.read(seekstart(landPoints))
land_geoCables = GeoJSON.read(seekstart(landCables))

# TODO: This example is so complicated I give up. I don't understand anything.
# please either @lazarusA or @vsir or @SimonDanisch write this example in 
# a way that a beginner user can follow what's going on.
# the full example is here: https://lazarusa.github.io/BeautifulMakie/GeoPlots/submarineCables/
```