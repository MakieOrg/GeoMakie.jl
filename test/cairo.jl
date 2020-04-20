using CairoMakie, AbstractPlotting, GeoMakie

lons = LinRange(-179.5, 179.5, 360)
lats = LinRange(-89.5, 89.5, 180)

field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

source = LonLat()
dest = WinkelTripel()

points, faces = GeoMakie.triangulated_gri(lons, lats)

tpoints = Proj4.transform.(source, dest, points)

scene = mesh(tpoints, faces; color = GeoMakie.img2colorvec(field), shading = false, show_axis = false, scale_plot = false)

geoaxis!(scene, -180, 180, -90, 90; crs = (src = source, dest = dest,))

coastlines!(scene, 1; crs = (src = source, dest = dest,))

save("geomakie-readme.png", scene) # works
save("geomakie-readme.svg", scene) # works
save("geomakie-readme.pdf", scene) # works but is really large
