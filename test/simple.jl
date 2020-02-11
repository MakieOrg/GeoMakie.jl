using GeoMakie, Makie, Proj4

lons = LinRange(0.5, 359.5, 360)
lats = LinRange(-89.5, 89.5, 180)

field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

cf = circshift(field, 180) # shift the field to the correct position

source = Projection("+proj=lonlat +lon_0=180 +pm=180")
dest = Projection("+proj=moll +lon_0=0")

xs, ys = xygrid(lons, lats)
Proj4.transform!(source, dest, vec(xs), vec(ys))

scene = surface(xs, ys; color = cf, shading = false, show_axis = false)

geoaxis!(scene, -180, 180, -90, 90; crs = (src = source, dest = dest,))

coastlines!(scene, 1; crs = (src = source, dest = dest,))
