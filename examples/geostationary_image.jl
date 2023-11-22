using Makie, GeoMakie, CairoMakie
using Downloads, FileIO
# Download a geostationary satellite image
img = rotr90(FileIO.load(Downloads.download("https://gist.github.com/pelson/5871263/raw/EIDA50_201211061300_clip2.png")))
image(img)
# then, plot the figure etc
fig = Figure()
ga = GeoAxis(fig[1, 1]; target_projection = "+proj=natearth")
lines!(ga, GeoMakie.coastlines())

ga.title[] = "Image from geostationary satellite" # this doesn't do anything - yet!

#=
# Surface could be used as well but is slower!
surface!(
    ga,
    -5500000..5500000, -5500000..5500000, # the bounding box in input space for the image
    ones(size(img)...); # dummy points to create the surface
    color = img,
    source_projection = "+proj=geos +h=35786000"
)
=#

meshimage!(ga,
    -5500000 .. 5500000, -5500000 .. 5500000, img;
    source_projection="+proj=geos +h=35786000",
    npoints=100
)
fig
