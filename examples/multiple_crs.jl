# # Multiple CRS in one axis

# This is an example of how you can use multiple CRS in one plot.
using Makie, GeoMakie, Rasters
worldclim_temp = Raster(WorldClim{Climate}, :tmax; month = 1)
# Let's simulate a new CRS, assuming this was an image taken from a satellite:
new_worldclim = Rasters.warp(
        worldclim_temp,
        Dict(
            "s_srs" => convert(GeoFormatTypes.ProjString, Rasters.crs(worldclim_temp)).val, # source CRS
            "t_srs" => "+proj=geos +h=3578600 +lon_0=72" # the CRS to which this should be transformed
        )
    )
# This is what the raster would look like, if it were taken directly from a satellite image:
heatmap(new_worldclim; axis = (; aspect = DataAspect()))
# Now, we can create a GeoAxis with coastlines in the equal earth projection:
fig = Figure()
ga = GeoAxis(fig[1, 1])
lines!(ga, GeoMakie.coastlines())
fig
# The coastlines function returns points in the (lon, lat) coordinate reference system.

# We will now plot our image, from the geostationary coordinate system:
surface!(ga, new_worldclim; shading = NoShading, source = convert(GeoFormatTypes.ProjString, Rasters.crs(new_worldclim)).val)
fig
# Success!  You can clearly see how the raster was adapted here.
