# # MakieCon example
using Makie, GeoMakie, CairoMakie

using Rasters # deliver Rasters unto this world

prec_raster = Raster(WorldClim{Climate}, :prec; month = 7)

fig = Figure()
ga = GeoAxis(fig[1, 1]; dest = "+proj=vandg")
sp = surface!(ga, prec_raster, shading = NoShading)
sp.colorrange = Makie.PlotUtils.zscale(sp[3][]; contrast = 0.9)
cb = Colorbar(fig[1, 2], sp; label = "Precipitation", height = Relative(0.7))
fig
#
# make cover image #jl
mkpath("covers") #hide
save("covers/$(splitext(basename(@__FILE__))[1]).png", fig) #hide
nothing #hide
