using Pkg
pkg"add https://github.com/asinghvi17/NASAEarthObservations.jl"
using GeoMakie, Makie, NASAEarthObservations, Glob
using ImageMagick

source = LonLat()
dest = WinkelTripel()

imgdir = observations("rgb/MYDAL2_M_AER_RA")

imgpaths = sort(Glob.glob(joinpath(relpath(imgdir), "*.PNG"))) # change this to your requirements

img = ImageMagick.load(imgpaths[1])

re = GeoMakie.date_regex("MYDAL2_M_AER_RA", "PNG")
titletext = Node(join(match(re, basename(imgpaths[1])).captures, '-'))

lons = LinRange(-179.5, 179.5, size(img)[2])
lats = LinRange(89.5, -89.5, size(img)[1])

points, faces = GeoMakie.triangulated_grid(lons, lats)

tpoints = transform.(source, dest, points)

scene = poly(tpoints, faces; color = img[:], show_axis = false);

geoaxis!(scene, -180, 180, -90, 90; crs = (src = src, dest = dest,));

fullsc = title(scene, titletext)

save("a.png", scene); lines(rand(10))

record(fullsc, "test.mp4", imgpaths) do img

    scene.plots[1].color = GeoMakie.imflip(ImageMagick.load(img))

    # titletext[] = join(match(re, basename(img)).captures, '-')

end
lines(rand(10))
