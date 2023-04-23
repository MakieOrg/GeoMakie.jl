using GeoMakie
using Rasters

# First, load the Raster.
env_transfer_raster = Rasters.Raster(joinpath(homedir(), "Downloads", "GEOSCarb_CASAGFED3v3_Flux.3hour.x576_y361.200301.nc"); lazy = true)
# Let's make sure our method works, so we can intitialize plots.
#
# First, we extract a slice of the datacube in time:
current_raster = env_transfer_raster[Ti(axes(env_transfer_raster, 3)[1])]
# then, convert it using Makie's `convert_arguments` functionality, which replaces e.g. missing with NaN and straightens axes.
x, y, z = Makie.convert_arguments(Makie.ContinuousSurface(), current_raster)
# We want any place with missing data to show up as black, so we replace all NaNs with 0.  
# For the type of data we're using, and the type of visualization, this is a reasonable assumption.
transform_z = replace(z, NaN => 0.0)
# Now, we use a utility from CairoMakie to transform this grid of xs, ys, and zs into a matrix with representation
surface_mesh = CairoMakie.surface2mesh(x, y, transform_z .* 1e8)
# Let's now construct the plot.
f, a, p, title = with_theme(theme_black()) do
    f, a, p = mesh(surface_mesh; color = z, nan_color = :black, axis = (; type = LScene, show_axis = false))
    f, a, p, Label(f[begin-1, :], "Title", fontsize = 20, font = :bold, tellwidth = false)
end 
# Having done all this construction, we set the transformation function:
p.transformation.transform_func[] = Geodesy.ECEFfromLLA(Geodesy.WGS84())
f
# finally, we can record an animation using the same steps as above:
record(f, "earth_climate_deformations.mp4", axes(env_transfer_raw_raster, 3); framerate = 30) do i
    title.text = string(dims(env_transfer_raster, 3)[i])
    current_raster = env_transfer_raster[Ti(i)]
    x, y, z = Makie.convert_arguments(Makie.ContinuousSurface(), current_raster)
    transform_z = replace(z, NaN => 0.0) # we want a solid Earth in the mesh.
    surface_mesh = CairoMakie.surface2mesh(x, y, transform_z .* 1e8) # 1e8 is a scale factor to make deformations look good!
    p.input_args[1][] = surface_mesh
end

