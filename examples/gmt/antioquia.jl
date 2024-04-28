using GMT # for data
using GeoMakie, Polylabel, Shapefile

import ZipFile, Shapefile, DataFrames
function read_shp_from_zipfile(zipfile)
  r = ZipFile.Reader(zipfile)
  # need to get dbx
  shpdata, shxdata, dbfdata, prjdata = nothing, nothing, nothing, nothing
  for f in r.files
    fn = f.name
    lfn = lowercase(fn)
    if endswith(lfn, ".shp")
      shpdata = IOBuffer(read(f))
    elseif endswith(lfn, ".shx")
      shxdata = read(f, Shapefile.IndexHandle)
    elseif endswith(lfn, ".dbf")
      dbfdata = Shapefile.DBFTables.Table(IOBuffer(read(f)))
    elseif endswith(lfn, "prj")
      prjdata = try
        Shapefile.GeoFormatTypes.ESRIWellKnownText(Shapefile.GeoFormatTypes.CRS(), read(f, String))
      catch
        @warn "Projection file $zipfile/$lfn appears to be corrupted. `nothing` used for `crs`"
        nothing 
      end
    end
  end
  close(r)
  @assert shpdata !== nothing
  shp = if shxdata !== nothing # we have shxdata/index 
    read(shpdata, Shapefile.Handle, shxdata)
  else
    read(shpdata, Shapefile.Handle)
  end 
  if prjdata !== nothing
    shp.crs = prjdata 
  end 
  return Shapefile.Table(shp, dbfdata)
end 

table = read_shp_from_zipfile(joinpath(GMT.TESTSDIR, "COL_adm2.shp.zip")) |> DataFrame

antioquia_geoms = filter(:NAME_1 => ==("Antioquia"), table)

f, a, p = poly(antioquia_geoms.geometry; axis = (; aspect = DataAspect()))
tp = Makie.text!(a, Polylabel.polylabel.(antioquia_geoms.geometry); text = string.(antioquia_geoms.ID_2), align = (:center, :center))
tp.fontsize = 5
f

f, a, p = poly(antioquia_geoms.geometry; color = antioquia_geoms.ID_2, axis = (; aspect = DataAspect()))
tp = Makie.text!(a, Polylabel.polylabel.(antioquia_geoms.geometry); fontsize = 4, text = string.(antioquia_geoms.ID_2))
f # TODO: doesn't work, color not computed?