using CairoMakie, AbstractPlotting, GeoMakie

lons = LinRange(-179.5, 179.5, 360)
lats = LinRange(-89.5, 89.5, 180)

field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

source = LonLat()
dest = WinkelTripel()

points, faces = GeoMakie.triangulated_grid(lons, lats)

tpoints = Proj4.transform.(source, dest, points)

scene = mesh(
    tpoints, faces;
    color = GeoMakie.img2colorvec(field),
    shading = false,
    show_axis = false, scale_plot = false, # don't show the normal axis and
                                           # ensure the aspect ratio is correct
    resolution = (1200, 600)               # just a nice resolution for this projection
)

geoaxis!(scene, extrema(lons), extrema(lats); crs = (src = source, dest = dest,))

coastlines!(scene; crs = (src = source, dest = dest))

save("geomakie-readme.png", scene) # works
save("geomakie-readme.svg", scene) # works
save("geomakie-readme.pdf", scene) # works but is really large
