# # GMT vector example

# This example was translated from the [equivalent GMT.jl example](https://www.generic-mapping-tools.org/GMTjl_doc/tutorials/vector_shp/vector_shp/).

using GMT # for data
using GeoMakie, Polylabel, Shapefile

import ZipFile, Shapefile

table = Shapefile.Table(joinpath(GMT.TESTSDIR, "COL_adm2.shp.zip"))

antioquia_geoms = filter(:NAME_1 => ==("Antioquia"), table)

f, a, p = poly(antioquia_geoms.geometry; axis = (; type = GeoAxis))
tp = Makie.text!(a, Polylabel.polylabel.(antioquia_geoms.geometry); text = string.(antioquia_geoms.ID_2), align = (:center, :center))
tp.fontsize = 5
f
