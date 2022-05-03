using GeoMakie, GeoMakie.Proj
using CairoMakie
using Downloads

img = rotr90(FileIO.load(Downloads.download("https://gist.github.com/pelson/5871263/raw/EIDA50_201211061300_clip2.png")))

img_xaxis = LinRange(-5500000, 5500000, size(img, 1))
img_yaxis = LinRange(-5500000, 5500000, size(img, 2))

geos_to_latlong = Proj.Transformation("+proj=geos +h=35786000", "+proj=latlong"; always_xy = true)

img_grid_points = geos_to_latlong.(Point2f.(img_xaxis, img_yaxis'))

fig = Figure()
ga = GeoAxis(fig[1, 1]; dest = "+proj=natearth", coastlines = true, coastline_attributes = (color = :steelblue,))

ga.title[] = "Image from geostationary satellite"

surface!(
    first.(img_grid_points), # x points,
    last.(img_grid_points),  # y points,
    ones(size(img)...); # dummy points to create the surface
    color = img
)
fig
