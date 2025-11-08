# # Annotated plot
# This example is translated from [this Cartopy example](https://scitools.org.uk/cartopy/docs/latest/gallery/lines_and_polygons/feature_creation.html#sphx-glr-gallery-lines-and-polygons-feature-creation-py).

using CairoMakie, GeoMakie, Makie
using Makie: GeometryBasics
using NaturalEarth

states_fc = naturalearth("admin_1_states_provinces_lines", 50)

fig = Figure()
ga = GeoAxis(fig[1, 1]; limits = ((80, 170), (-45, 30)), dest = "+proj=longlat +datum=WGS84")
image!(ga, -180..180, -90..90, GeoMakie.earth() |> rotr90; interpolate = false)
poly!(ga, GeoMakie.land(); color = :lightyellow, strokecolor = :black, strokewidth = 1)
lines!(ga, GeoMakie.to_multilinestring.(states_fc.geometry); color = :gray)
fig
# Now to add the annotation:
const DATASOURCE = "Natural Earth"
const LICENSE = "public domain"
annotation_text = textlabel!(
    ga, Point2f(0.25, 0.05); # plotting in relative coordinates - (0, 0) is bottom left, (1, 1) is top right 
    space = :relative, text = "© $DATASOURCE ($LICENSE)",
    background_color = RGBAf(1,1,1,0.6),
)
fig
#=
```@cardmeta
Description = "An annotated plot with license info."
Cover = fig
```
=#