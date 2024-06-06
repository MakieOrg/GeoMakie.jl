using Pkg
pkg"add https://github.com/asinghvi17/NASAEarthObservations.jl"
using GeoMakie, Makie, NASAEarthObservations

using ImageMagick: load

# download data - ~140 MB
imgdir = observations("geotiff/CERES_NETFLUX_M")

date_regex(dirname, ext) = Regex("$(dirname)_(\\d{4})-(\\d{2}).$(uppercase(ext))")
imflip(img) = reverse(vec(transpose(reverse(img; dims=2))))

img = load(joinpath(imgdir, "CERES_NETFLUX_M_2006-07.TIFF"))

lons = LinRange(-89, 90, size(img)[1])
lats = LinRange(-179, 180, size(img)[2])

source = LonLat()
dest = Projection("+proj=robin")

points = GeoMakie.transform.(LonLat(), dest, GeoMakie.gridpoints(lats, lons))
faces  = GeoMakie.grid_triangle_faces(lats, lons)


scene = poly(points, faces; color = imflip(img), show_axis = false);

geoaxis!(scene, -180, 180, -90, 90; crs = (dest = dest,));

titletext = Observable("07/2016")

fullsc = title(sc, titletext; fontsize = 40);

save(DataFormat{:PNG}, "d.png", fullsc); lines(rand(10))

record(fullsc, "ceres_netflux.mp4", filter!(x -> uppercase(splitext(x)[2]) == ".TIFF", sort(readdir(imgdir))); framerate = 10) do img

    year, month = match(re, img).captures

    scene.plots[1].color = imflip(ImageMagick.load(joinpath(imgdir,img)))
    titletext[] = "$month/$year"
end

lines(rand(10))
#
# make cover image #jl
mkpath("covers") #hide
save("covers/$(splitext(basename(@__FILE__))[1]).png", fig) #hide
nothing #hide