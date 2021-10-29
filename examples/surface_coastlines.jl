using GeoMakie, GLMakie

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

fig, ax, el = geosurface(field, lons, lats)
display(fig)