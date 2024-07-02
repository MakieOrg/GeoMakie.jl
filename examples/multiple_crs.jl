# # Multiple CRS in one axis

# This is an example of how you can use multiple CRS in one plot.
using CairoMakie, GeoMakie
using Rasters, RasterDataSources, ArchGDAL

ras = Raster(EarthEnv{HabitatHeterogeneity}, :homogeneity)
#
heatmap(ras; axis = (; aspect = DataAspect()))
# Let's simulate a new CRS, assuming this was an image taken from a geostationary satellite, hovering above 72° E:
projected_ras = Rasters.warp(
        ras,
        Dict(
            "s_srs" => convert(GeoFormatTypes.ProjString, Rasters.crs(ras)).val, # source CRS
            "t_srs" => "+proj=geos +h=3578600 +lon_0=72" # the CRS to which this should be transformed
        )
    )
# This is what the raster would look like, if it were taken directly from a satellite image:
heatmap(projected_ras; axis = (; aspect = DataAspect()))
# Now, we can create a GeoAxis with coastlines in the equal earth projection:
fig = Figure()
ga = GeoAxis(fig[1, 1])
lines!(ga, GeoMakie.coastlines())
fig
# The coastlines function returns points in the (lon, lat) coordinate reference system.

# We will now plot our image, from the geostationary coordinate system:
heatmap!(ga, projected_ras)
fig
# Success!  You can clearly see how the raster was adapted here.

#=
```@cardmeta
Description = "Plotting multiple CRS in one axis"
```
=#