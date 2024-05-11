using GMT # for data
using GeoMakie, Polylabel, Shapefile

import ZipFile, Shapefile, DataFrames
table = Shapefile.Table(joinpath(GMT.TESTSDIR, "COL_adm2.shp.zip")) |> DataFrame

antioquia_geoms = filter(:NAME_1 => ==("Antioquia"), table)

f, a, p = poly(antioquia_geoms.geometry; axis = (; aspect = DataAspect()))
tp = Makie.text!(a, Polylabel.polylabel.(antioquia_geoms.geometry); text = string.(antioquia_geoms.ID_2), align = (:center, :center))
tp.fontsize = 5
f

f, a, p = poly(antioquia_geoms.geometry; color = antioquia_geoms.ID_2, axis = (; aspect = DataAspect()))
tp = Makie.text!(a, Polylabel.polylabel.(antioquia_geoms.geometry); fontsize = 4, text = string.(antioquia_geoms.ID_2))
f # TODO: doesn't work, color not computed?