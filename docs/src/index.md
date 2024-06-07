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

<h1> What is GeoMakie.jl? </h1>

GeoMakie.jl is a Julia package for plotting geospatial data on a given map projection. It is built on top of the [Makie.jl plotting ecosystem](https://docs.makie.org/stable/).

GeoMakie provides a `GeoAxis` type which handles CRS and projections, and various utilities and integrations to handle plotting geometries.  `GeoAxis` should work seamlessly with any Makie plotting function, and can be used as a drop-in replacement for `Makie.Axis`.

</div>

```

