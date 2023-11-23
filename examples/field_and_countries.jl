# This example was taken from Lazaro Alonso's
# BeautifulMakie.jl repository.  It has some really
# good stuff - check it out!
using Makie, CairoMakie, GeoMakie
import Downloads
using GeoMakie.GeoJSON
using GeometryBasics
using GeoMakie.GeoInterface

# https://datahub.io/core/geo-countries#curl # download data from here
path = GeoMakie.assetpath("vector", "countries.geo.json")
json_str = read(path, String)
worldCountries = GeoJSON.read(json_str)
n = length(worldCountries)
lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

fig = Figure(size = (1200,800), fontsize = 22)

ax = GeoAxis(
    fig[1,1];
    dest="+proj=wintri",
    title = "World Countries",
    tellheight = true,
)

hm1 = surface!(ax, lons, lats, field; shading = NoShading)
translate!(hm1, 0, 0, -10)

hm2 = poly!(
    ax, worldCountries;
    color= 1:n,
    colormap = Reverse(:plasma),
    strokecolor = :black,
    strokewidth = 0.25
)

cb = Colorbar(fig[1,2]; colorrange = (1, n), colormap = Reverse(:plasma), label = "variable, color code", height = Relative(0.65))

fig
