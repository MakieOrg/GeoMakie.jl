using GeoMakie, Makie, Proj4

lons = -90:90
lats = -180:180

source = WGS84()
dest = Projection("+proj=robin")

points = GeoMakie.transform.(WGS84(), dest, GeoMakie.gridpoints(lats, lons))
faces  = GeoMakie.grid_triangle_faces(lats, lons)

colorfunc(i) = (sin.(lats .+ i) .+ cos.(lons'))[:]

scene = poly(points, faces; color = colorfunc(0), show_axis = false)

geoaxis!(scene, -180, 180, -90, 90; crs = (dest = dest,))

record(scene, "test.gif", LinRange(0, 2π, 150); framerate = 25) do i
    scene.plots[1].color = colorfunc(i)
end
