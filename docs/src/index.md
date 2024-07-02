```@raw html
---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "GeoMakie"
  text: ""
  tagline: Geographic plots for Makie
  image:
    src: /logo.png
    alt: Makie logo deformed on an Interrupted Goode Homolosine projection.
  actions:
    - theme: brand
      text: Introduction
      link: /introduction
    - theme: alt
      text: View on Github
      link: https://github.com/MakieOrg/GeoMakie.jl
    - theme: alt
      text: Examples
      link: /examples

features:
  - icon: <img width="64" height="64" src="https://rawcdn.githack.com/JuliaLang/julia-logo-graphics/f3a09eb033b653970c5b8412e7755e3c7d78db9e/images/juliadots.iconset/icon_512x512.png" alt="Julia code"/>
    title: Pure Julia code
    details: Fast, understandable, extensible functions
    link: /introduction
  - icon: <img width="64" height="64" src="https://rawcdn.githack.com/JuliaGeo/juliageo.github.io/4788480c2a5f7ae36df67a4b142e3a963024ac91/img/juliageo.svg" />
    title: Full integration with GeoInterface
    details: Use any GeoInterface.jl-compatible geometry
    link: https://juliageo.org/GeoInterface.jl/stable
  - title: Projections via Proj.jl
    details: Plot in any projection, with data coming from any projection!
    link: /examples/multiple_crs
---


<p style="margin-bottom:2cm"></p>

<div class="vp-doc" style="width:80%; margin:auto">

```

# What is GeoMakie.jl?

GeoMakie.jl is a Julia package for plotting geospatial data on a given map projection. It is built on top of the [Makie.jl plotting ecosystem](https://docs.makie.org/stable/).

GeoMakie provides a `GeoAxis` type which handles CRS and projections, and various utilities and integrations to handle plotting geometries.  `GeoAxis` should work seamlessly with any Makie plotting function, and can be used as a drop-in replacement for `Makie.Axis`.

## Quick start


## Quick start

The main entry point to GeoMakie is the function `GeoAxis(fig[i, j]; kw_args...)`.  It creates an axis which accepts nonlinear projections, but is otherwise identical in usage to Makie's `Axis`.
Projections are accepted as [PROJ-strings](https://proj.org/operations/projections/index.html), and can be set through the `source="+proj=latlong +datum=WGS84"` and `dest="+proj=eqearth"` keyword arguments to `GeoAxis`.


```@example quickstart
using CairoMakie, GeoMakie

fig = Figure()
)
lines!(ga, GeoMakie.coastlines()) # plot coastlines from Natural Earth as a reference
# You can plot your data the same way you would in Makie
scatter!(ga, -120:15:120, -60:7.5:60; color = -60:7.5:60, strokecolor = (:black, 0.2))
fig
```

As you can see, the axis automatically transforms your input from the `source`
CRS (default `"+proj=longlat +datum=WGS84"`) to the `dest` CRS.

### Changing central longitude

Be careful! Each data point is transformed individually.
However, when using `surface` or `contour` plots this can lead to errors when the longitudinal dimension "wraps" around the planet.

To fix this issue, the recommended approach is that you (1) change the central longitude of the map transformation (`dest`), and (2) `circshift` your data accordingly for `lons` and `field`.

```@example MAIN
function cshift(lons, field, lon_0)
   shift = @. lons - lon_0 > 180
   nn = sum(shift)
   (circshift(lons - 360shift, nn), circshift(field, (nn, 0)))
end
```

```@example MAIN
lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

lon_0 = -160
(lons_shift, field_shift) = cshift(lons, field, lon_0)
```

```@example MAIN
fig = Figure()
ax = GeoAxis(fig[1,1]; dest = "+proj=eqearth +lon_0=$(lon_0)")
surface!(ax, lons_shift, lats, field_shift, colormap=:balance)
lines!.(ax, GeoMakie.coastlines(ax), color=:black, overdraw = true)
fig
```

You can also use quite a few other plot types and projections:
```@example quickstart
fieldlons = -180:180; fieldlats = -90:90
field = [exp(cosd(lon)) + 3(lat/90) for lon in fieldlons, lat in fieldlats]

img = rotr90(GeoMakie.earth())
land = GeoMakie.land()

fig = Figure(size = (1000, 1000))

ga1 = GeoAxis(fig[1, 1]; dest = "+proj=ortho", title = "Orthographic\n "); lines!(ga1, GeoMakie.coastlines())
ga2 = GeoAxis(fig[1, 2]; dest = "+proj=moll", title = "Image of Earth\n ")
ga3 = GeoAxis(fig[2, 1]; title = "Plotting polygons")
ga4 = GeoAxis(fig[2, 2]; dest = "+proj=natearth", title = "Auto limits") # you can plot geodata on regular axes too

surface!(ga1, fieldlons, fieldlats, field; colormap = :rainbow_bgyrm_35_85_c69_n256, shading = NoShading)
image!(ga2, -180..180, -90..90, img; interpolate = false) # this must be included
poly!(ga3, land[50:100]; color = 1:51, colormap = (:plasma, 0.5))
poly!(ga4, land[22]);

ylims!(ga3, (-90, 90)) # you can manipulate the axes as usual for Makie!

fig
```

See the documentation for examples and basic usage!


```@raw html
</div>
```

