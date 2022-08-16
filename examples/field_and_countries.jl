# This example was taken from Lazar Alonso's
# BeautifulMakie.jl repository.  It has some really
# good stuff - check it out!
using Makie, CairoMakie, GeoMakie
import Downloads
using GeoMakie.GeoJSON
using GeometryBasics

# https://datahub.io/core/geo-countries#curl # download data from here
worldCountries = GeoJSON.read(read(Downloads.download("https://raw.githubusercontent.com/johan/world.geo.json/master/countries.geo.json"), String))
worldCountries = GeoMakie.geoJSONtraitParse.(GeoInterface.geometry.(worldCountries))

n = length(GeoMakie.GeoInterface.getfeature(worldCountries))
lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]


fig = Figure(resolution = (1200,800), fontsize = 22)

ax = GeoAxis(
    fig[1,1];
    dest = "+proj=wintri",
    title = "World Countries",
    tellheight = true,
)

hm1 = surface!(ax, lons, lats, field; shading = false)

hm2 = poly!(
    ax, worldCountries;
    color= 1:n,
    colormap = Reverse(:plasma),
    strokecolor = :black,
    strokewidth = 0.25
)

cb = Colorbar(fig[1,2]; colorrange = (1, n), colormap = Reverse(:plasma), label = "variable, color code", height = Relative(0.65))

fig
