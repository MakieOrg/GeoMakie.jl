using GeoMakie, MakieLayout, Makie

lons = LinRange(-179.5, 179.5, 360)
lats = LinRange(-89.5, 89.5, 180)

field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

source = LonLat()
dest   = WinkelTripel()
cs     = Proj4.CRS2CRS(source, dest)

xs, ys = xygrid(lons, lats)

xmin, xmax = extrema(xs)
ymin, ymax = extrema(ys)

aspect_ratio = (ymax - ymin) / (xmax - xmin)

scene, layout = layoutscene(
);

layout[1, 1] = lsc = LScene(scene; scenekw = (show_axis = false, scale_plot = false, transform_func = cs))

splot = surface!(lsc, xs, ys; color = field, shading = false, show_axis = false)

geoaxis!(lsc, Rect2D(-180, -90, 360, 180))

coastlines!(lsc)

layout[1, 2] = LColorbar(scene, splot; label = "Arbitrary data", width = 30)

colsize!(layout, 1, Relative(1))
rowsize!(layout, 1, Aspect(1, aspect_ratio))

layout[0, :] = LText(scene, "MakieLayout is cool!"; textsize = 40)

scene |> save("geo.png")
scene |> save("geo.pdf")
