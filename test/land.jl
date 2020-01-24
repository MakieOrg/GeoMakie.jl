using GeoMakie, Shapefile

shp = Shapefile.Table("/Users/anshul/Downloads/ne_110m_land/ne_110m_land.shp") |> Shapefile.shapes |> skipmissing |> collect

points = rec_point(coordinates.(shp))

source = LonLat()

dest = Projection("+proj=fouc")

meshes = GeoMakie.toMesh.(rec_project(source, dest, points))

geoaxis(-180, 180, -90, 90; show_axis = false, crs = (dest = dest,))

mesh!(meshes)
