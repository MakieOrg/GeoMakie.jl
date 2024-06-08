# # Raster data (with Rasters.jl)
# [Rasters.jl](https://github.com/rafaqz/Rasters.jl) is a Julia package designed for working with raster data. 
# It provides tools to read, write, and manipulate raster datasets, 
# which are commonly used in geographic information systems (GIS), 
# remote sensing, and similar fields where grid data is prevalent.
# It's built on top of [DimensionalData.jl](https://github.com/rafaqz/DimensionalData.jl), which also underpins e.g. [YAXArrays.jl](https://github.com/JuliaDataCubes/YAXArrays.jl).
#
# In general, any input that works with base Makie will work with GeoMakie in a GeoAxis!

# First, we'll load Rasters.jl, RasterDataSources.jl which provides access to common datasets, and ArchGDAL.jl which Rasters.jl depends on to read files.
using Rasters, RasterDataSources, ArchGDAL
# We'll also load GeoMakie and CairoMakie to plot the data.
using GeoMakie, CairoMakie

# First, we can load a Raster from the [EarthEnv](https://www.earthenv.org) project, which represents habitat or ecosystem heterogeneity.

ras = Raster(EarthEnv{HabitatHeterogeneity}, :homogeneity) # habitat homogeneity to neighbouring pixel
# Let's take a look at this in regular Makie first:
heatmap(ras; axis = (; aspect = DataAspect()))
# We can plot this in any projection:
fig = Figure(); ga = GeoAxis(fig[1, 1])
hm = heatmap!(ga, ras)
fig
# We can also change the projection arbitrarily:
ga.dest[] = "+proj=ortho +lon_0=19 +lat_0=72"
fig
# and all other Makie keyword arguments also apply!
hm.colormap = :isoluminant_cgo_70_c39_n256
fig
# You can also use other recipes like surface:
fig = Figure(); ga = GeoAxis(fig[1, 1])
sp = surface!(ga, ras)
fig
# This looks a bit strange - but you can always disable shading:
sp.shading = NoShading
fig
# See also the Geostationary image and Multiple CRS examples, where we explore how to plot data in different projections.
# make cover image #jl
mkpath("covers") #hide
save("covers/$(splitext(basename(@__FILE__))[1]).png", fig) #hide
nothing #hide
