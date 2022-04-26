# GeoMakie

## Geographic plotting utilities for Makie.jl <a href = "https://www.github.com/JuliaPlots/Makie.jl"><img src="https://raw.githubusercontent.com/JuliaPlots/Makie.jl/master/assets/logo.png" alt="Makie.jl" height="30" align = "top"></a>

![Stable](https://img.shields.io/badge/docs-stable-blue.svg)(https://JuliaPlots.github.io/GeoMakie.jl/stable)
![Dev](https://img.shields.io/badge/docs-dev-blue.svg)(https://JuliaPlots.github.io/GeoMakie.jl/dev)
![CI](https://github.com/JuliaPlots/GeoMakie.jl/actions/workflows/ci.yml/badge.svg)

This package is **in development**, and may break often.  You can install it from the REPL like so:
```julia
]add GeoMakie
```

## Quick start

The main entry point to GeoMakie is the function `GeoAxis(fig[i, j]; kw_args...)`.  It creates an axis which accepts nonlinear projections, but is otherwise identical in usage to Makie's `Axis`.
Projections are accepted as [PROJ-strings](https://proj.org/operations/projections/index.html), and can be set through the `source="+proj=latlong +datum=WGS84"` and `dest="+proj=eqearth"` keyword arguments.


```julia
fig = Figure()
ga = GeoAxis(
    fig[1, 1]; # any cell of the figure's layout
    dest = "+proj=wintri", # the CRS in which you want to plot
    coastlines = true # plot coastlines from Natural Earth, as a reference.
)
fig
```
![geoax1](https://user-images.githubusercontent.com/32143268/165352924-32f82178-54b1-4b3a-9821-2348581c3a84.svg)

```julia
scatter!(ga, -120:15:120, -60:7.5:60; color = -60:7.5:60, strokecolor = (:black, 0.2)); fig
```
![geoax2](https://user-images.githubusercontent.com/32143268/165353013-ec6c4230-be7e-4dbc-a8c8-7e40204ebf80.svg)


As you can see, the axis automatically transforms your input from the `source`
CRS (default `"+proj=longlat +datum=WGS84"`) to the `dest` CRS.

You can also use quite a few other plot types and projections:
```julia
fieldlons = -180:180; fieldlats = -90:90
field = [exp(cosd(lon)) + 3(lat/90) for lon in fieldlons, lat in fieldlats]

img = rotr90(GeoMakie.earth())
land = GeoMakie.land()

fig = Figure(resolution = (1000, 1000))

ga1 = GeoAxis(fig[1, 1]; dest = "+proj=ortho", coastlines = true, lonlims = (-90, 90), title = "Orthographic\n ")
ga2 = GeoAxis(fig[1, 2]; dest = "+proj=moll", title = "Image of Earth\n ")
ga3 = GeoAxis(fig[2, 1]; coastlines = false, title = "Plotting polygons")
ga4 = GeoAxis(fig[2, 2]; dest = "+proj=natearth", title = "Auto limits") # you can plot geodata on regular axes too

surface!(ga1, fieldlons, fieldlats, field; colormap = :rainbow_bgyrm_35_85_c69_n256, shading = false)
image!(ga2, -180..180, -90..90, img; interpolate = false) # this must be included
poly!(ga3, land[50:100]; color = 1:51, colormap = (:plasma, 0.5))
poly!(ga4, land[22]); datalims!(ga4)

fig
```
![geoaxes](https://user-images.githubusercontent.com/32143268/165358447-ab1aa721-d457-4710-979c-d361080eae52.svg)


# Instructions for the `as/geoaxis` branch
In the REPL, run `]add GeoMakie#as/geoaxis Makie#master CairoMakie#master MakieCore#master`

To clean up, run the following in Julia:
```julia
using Pkg
Pkg.rm.(["GeoMakie", "Makie", "CairoMakie", "MakieCore"])
Pkg.add.(["Makie", "CairoMakie", "MakieCore"])
```

Please see the documentation for examples and basic usage.
