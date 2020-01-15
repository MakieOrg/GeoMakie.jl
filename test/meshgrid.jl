using GeoMakie, Makie, Proj4, PlotUtils

using Images, FileIO
const HOME = expanduser("~")
img = load("$HOME/NASAobs/neo.sci.gsfc.nasa.gov/archive/geotiff/CERES_NETFLUX_M/CERES_NETFLUX_M_2006-07.TIFF")

lons = LinRange(-89, 90, size(img)[1])
lats = LinRange(-179, 180, size(img)[2])

source = WGS84()
dest = Projection("+proj=robin")

points = GeoMakie.transform.(WGS84(), dest, GeoMakie.gridpoints(lats, lons))
faces  = GeoMakie.grid_triangle_faces(lats, lons)

colorfunc(i) = (sin.(lats .+ i) .+ cos.(lons'))[:]

# img =

scene = poly(points, faces; color = img[:], show_axis = false)

geoaxis!(scene, -180, 180, -90, 90; crs = (dest = dest,))

record(scene, "test.gif", LinRange(0, 2π, 150); framerate = 25) do i
    scene.plots[1].color = colorfunc(i)
end
