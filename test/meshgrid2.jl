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

xs = [lon for lat in lats, lon in lons]
ys = [lat for lat in lats, lon in lons]

Proj4.transform!(source, dest, vec(xs), vec(ys))

scene = surface(xs, ys, zeros(size(xs)); color = img, shading = false, show_axis = false)

geoaxis!(scene, -180, 180, -90, 90; crs = (src = src, dest = dest,));

visible = node(:visible, false)

poprect = lift(scene.events.mouseposition) do mp
    FRect((mp .+ 5), 250, 40)
end
textpos = lift(scene.events.mouseposition) do mp
    Vec3f0((mp .+ 5 .+ (250/2, 40 / 2))..., 120)
end
popup = poly!(campixel(scene), poprect, raw = true, color = :white, strokewidth = 2,
        strokecolor = :black, visible = visible)

rect = popup[end]

translate!(rect, Vec3f0(0, 0, 100))

textnode = Node(" ")

text!(popup, textnode, textsize = 30, position = textpos, color = :darkred, align = (:center, :center), raw = true, visible = visible)

text_field = popup[end]

x = Node(false)

on(scene.events.mouseposition) do pos
    if ispressed(scene, Mouse.left)
        visible[] = true
        pos = to_world(scene, Point2f0(scene.events.mouseposition[]))
        tpos = transform(dest, source, pos)
        textnode[] = sprint(io-> print(io, round.(Float64.(tpos), digits = 3)))
    else
        visible[] = false
    end
end

fullsc = title(scene, titletext)

save("a.png", scene); lines(rand(10))

record(fullsc, "test.mp4", imgpaths) do img

    scene.plots[1].color = GeoMakie.imflip(ImageMagick.load(img))

    # titletext[] = join(match(re, basename(img)).captures, '-')

end
lines(rand(10))
