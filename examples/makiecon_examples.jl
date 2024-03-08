using Makie, GeoMakie, CairoMakie
CairoMakie.activate!(px_per_unit = 4) # hide

using Rasters # deliver Rasters unto this world

prec_raster = Raster(WorldClim{Climate}, :prec; month = 7)

fig = Figure()
ga = GeoAxis(fig[1, 1]; dest = "+proj=vandg")
sp = surface!(ga, prec_raster, shading = NoShading)
sp.colorrange = Makie.PlotUtils.zscale(sp[3][]; contrast = 0.9)
cb = Colorbar(fig[1, 2], sp; label = "Precipitation", height = Relative(0.7))
fig
