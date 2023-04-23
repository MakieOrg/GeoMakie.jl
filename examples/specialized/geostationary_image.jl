using GeoMakie, GeoMakie.Proj
using CairoMakie
using Downloads, FileIO

img = rotr90(FileIO.load(Downloads.download("https://gist.github.com/pelson/5871263/raw/EIDA50_201211061300_clip2.png")))

fig = Figure()
ga = GeoAxis(fig[1, 1]; target_projection = "+proj=natearth")
lines!(ga, GeoMakie.coastlines())

ga.title[] = "Image from geostationary satellite"

surface!(
    ga,
    img_xaxis, img_yaxis,
    ones(size(img)...); # dummy points to create the surface
    color = img,
    source_projection = img_crs
)

# or

meshimage!(
    ga,
    -5500000..5500000, -5500000..5500000,
    img;
    source_projection = "+proj=geos +h=35786000", # the image was taken from a geostationary satellite at these coordinates
    npoints = 100
) # significantly more efficient, and with better interpolation to boot!

