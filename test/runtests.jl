using GeoMakie, CairoMakie, AbstractPlotting, ImageMagick, NASAEarthObservations, Glob
using Test

source = LonLat()
dest = WinkelTripel()

imgdir = observations("rgb/MYDAL2_M_AER_RA")

imgpaths = sort(Glob.glob(joinpath(relpath(imgdir), "*.PNG"))) # change this to your requirements

img = ImageMagick.load(imgpaths[1])

re = GeoMakie.date_regex("MYDAL2_M_AER_RA", "PNG")
titletext = Node(join(match(re, basename(imgpaths[1])).captures, '-'))

lons = LinRange(-179.5, 179.5, size(img)[2])
lats = LinRange(89.5, -89.5, size(img)[1])

xs = [lon for lat in lats, lon in lons]
ys = [lat for lat in lats, lon in lons]

points, faces = GeoMakie.triangulated_grid(lons, lats)
tpoints = Proj4.transform.(source, dest, points)

scene = mesh(tpoints, faces; color = img[:], shading = false, show_axis = false, scale_plot = false)

geoaxis!(scene, -180, 180, -90, 90; crs = (src = source, dest = dest,));

titletext = Node("07/2016")

fullsc = title(scene, titletext; fontsize = 40);

record(fullsc, "particulates.mp4", filter!(x -> uppercase(splitext(x)[2]) == ".TIFF", sort(readdir(imgdir))); framerate = 10) do img

    year, month = match(re, img).captures

    scene.plots[1].color = ImageMagick.load(joinpath(imgdir,img))
    titletext[] = "$month/$year"
end
