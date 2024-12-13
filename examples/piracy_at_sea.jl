using Makie, GeoMakie

using GeoJSON, QuackIO, DataFrames
using Downloads

import GeometryOps as GO, GeoInterface as GI, Proj

shipping_routes_file = download("https://raw.githubusercontent.com/newzealandpaul/Shipping-Lanes/refs/tags/v1.3.1/data/Shipping_Lanes_v1.geojson", "Shipping_Lanes_v1.geojson")
pirate_attacks_file = download("https://raw.githubusercontent.com/newzealandpaul/Maritime-Pirate-Attacks/refs/heads/main/data/csv/pirate_attacks.csv", "pirate_attacks.csv")

shipping_routes = GeoJSON.read(shipping_routes_file)
pirate_attacks = QuackIO.read_csv(DataFrame, pirate_attacks_file)

major = shipping_routes.geometry[findfirst(==("Major"), shipping_routes.Type)]
middle = shipping_routes.geometry[findfirst(==("Middle"), shipping_routes.Type)]
minor = shipping_routes.geometry[findfirst(==("Minor"), shipping_routes.Type)]

pirate_attacks = DataFrame(CSV.File(pirate_attacks_file; dateformat = "YYYY-MM-DD"))

using Rasters
using Dates

pirate_attacks.pre2015 = year.(pirate_attacks.date) .<= 2015

groups = groupby(pirate_attacks, :pre2015; sort = true)

r1 = rasterize(sum, tuple.(groups[1].longitude, groups[1].latitude); fill = 1, res = 0.5, crs = Rasters.EPSG(4326))
r2 = rasterize(sum, tuple.(groups[2].longitude, groups[2].latitude); fill = 1, res = 0.5, crs = Rasters.EPSG(4326))

pts = DimIndices(r1)[(!ismissing).(r1)]
attrs

dt = DimTable(r1; mergedims = (X, Y)) |> DataFrame |> x -> dropmissing(x, :sum)
dt.XY |> x -> reinterpret(Float64, x)



fig = Figure(; size = (1000, 750))
ax = GeoAxis(fig[1, 1]; dest = "+proj=wintri")
# ax = Axis(fig[1, 1]; aspect = DataAspect())
background_plot = meshimage!(ax, -180..180, -90..90, reshape([RGBf(231/255, 255/255, 255/255)], 1, 1))

using NaturalEarth
country_plot = poly!(ax, naturalearth("admin_0_countries", 110).geometry; color = RGBf(221/255, 234/255, 214/255), strokewidth = 1, strokecolor = :white)


major_plot = lines!(ax, major)
middle_plot = lines!(ax, middle)
minor_plot = lines!(ax, minor)

major_plot.linewidth = 4
middle_plot.linewidth = 2

minor_plot.visible = false

major_plot.color = RGBAf(165/255, 223/255, 246/255, 1);
middle_plot.color = RGBAf(165/255, 234/255, 255/255, 1);


using Clustering
columns_as_points = permutedims(hcat(groups[1].longitude, groups[1].latitude))
res = Clustering.kmeans(columns_as_points, 30)
centers = splat(tuple).(eachcol(res.centers))
markersizes = res.counts

sp1 = scatter!(ax, centers; markersize = sqrt.(markersizes) .* 1.5, color = color = RGBf(156/255, 96/255, 178/255))


columns_as_points = permutedims(hcat(groups[2].longitude, groups[2].latitude))
res = Clustering.kmeans(columns_as_points, 110)
centers = splat(tuple).(eachcol(res.centers))
markersizes = res.counts

sp2 = scatter!(ax, centers; markersize = sqrt.(markersizes) .* 1.5, color = RGBf(65/255, 183/255, 153/255))

sp2.alpha = 0.6

# ylims!(ax, -60, 84)

translate!(sp1, 0, 0, 1)
# ax.aspect[] = 360 #= degrees longitude =# / (84 + 60) #= degrees latitude =#


leg_gl = GridLayout(fig[2, 1])

leg1 = Legend(
    leg_gl[1,1],
    [MarkerElement(; marker = sp2.marker, color = sp1.color, markersize) for markersize in sqrt.([5, 15, 30, 60]) .* 1.5],
    ["1-10", "11-20", "21-40", "41-80"],
    "Pirate Attacks 2015-2020"
    )

leg2 = Legend(
    leg_gl[2,1],
    [MarkerElement(; marker = sp2.marker, color = sp2.color, markersize) for markersize in sqrt.([5, 15, 30, 60]) .* 1.5],
    ["1-10", "11-20", "21-40", "41-80"],
    "Pirate Attacks 2010-2015"
)

fig