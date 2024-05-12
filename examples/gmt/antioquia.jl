# # GMT vector example

# This example was translated from the [equivalent GMT.jl example](https://www.generic-mapping-tools.org/GMTjl_doc/tutorials/vector_shp/vector_shp/).

import GMT # for data
using GeoMakie, Polylabel
using DataFrames

import ZipFile, Shapefile

table = Shapefile.Table(joinpath(GMT.TESTSDIR, "COL_adm2.shp.zip")) |> DataFrame

antioquia_geoms = filter(:NAME_1 => ==("Antioquia"), table)

f, a, p = poly(antioquia_geoms.geometry; axis = (; type = GeoAxis))
tp = Makie.text!(a, Polylabel.polylabel.(antioquia_geoms.geometry); text = string.(antioquia_geoms.ID_2), align = (:center, :center))
tp.fontsize = 5
f
# Now that the polygons are labelled, we can also color them:

f, a, p = poly(antioquia_geoms.geometry; color = antioquia_geoms.ID_2 .|> identity, colormap = :bamako, axis = (; type = GeoAxis))
tp = Makie.text!(a, Polylabel.polylabel.(antioquia_geoms.geometry); text = string.(antioquia_geoms.ID_2), align = (:center, :center))
tp.fontsize = 5
a.title = "Another Map of Antioquia"
cb = Colorbar(f[1, 2], p)
f
# Note that this is not projected - the `proj=:guess` projection is not implemented in GeoMakie!
# However, we can project to an orthographic projection centered at the centroid of the geometry,
# using GeometryOps.jl to calculate the centroid.
import GeometryOps as GO
cx, cy = GO.centroid(antioquia_geoms)
a.dest = "+proj=ortho +lon_0=$cx +lat_0=$cy"
f
# That looks a lot more like what the GMT example does!