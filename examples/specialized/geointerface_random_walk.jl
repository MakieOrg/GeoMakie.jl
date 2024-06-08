# A random walk through Julia's GeoInterface ecosystem

## Creating geometry (with CRS) from scratch

using DataFrames
import GeoInterface as GI
import GeometryOps as GO
import GeoFormatTypes as GFT
import Proj
using GeoMakie
# Coodinate reference system (crs) that you're working in
source_crs = GFT.EPSG(4326)

# Create a single LinearRing Trait.
# A LiearRing is simply a LineString with the same begin and endpoint. 
# i.e. an arbitraty closed shape composed of point pairs
ring1 = GI.LinearRing([(1., 1.5), (1.5, 1), (2, 1.5), (1.5, 2)]; crs = source_crs)

# now let's make a sinlge shape a polygon and add coodinate reference system (crs) info
geopoly1 = GI.Polygon([ring1], crs=source_crs)

# Now let's plot what we have so far
fig = Figure()
ax = GeoAxis(fig[1, 1])
poly!(ax, geopoly1)
fig