# # German lakes
using GeoMakie, CairoMakie
using GeoJSON, Downloads

geoger = GeoJSON.read(read(Downloads.download("https://raw.githubusercontent.com/isellsoap/deutschlandGeoJSON/main/2_bundeslaender/4_niedrig.geo.json"), String))
lakes = GeoJSON.read(read(Downloads.download("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_lakes_europe.geojson"), String))

fig = Figure()
ga = GeoAxis(fig[1, 1]; dest = "+proj=merc", limits=((6, 15), (47, 55)))

poly!(ga, GeoMakie.to_multipoly(geoger.geometry); strokewidth = 0.7, color=:gold, rasterize = 5)
poly!(ga, GeoMakie.to_multipoly(lakes.geometry); strokewidth = 0.7, color=:blue, rasterize = 5,  xautolimits=false, yautolimits=false)
fig
#
# make cover image #jl
mkpath("covers") #hide
save("covers/$(splitext(basename(@__FILE__))[1]).png", fig) #hide
nothing #hide
