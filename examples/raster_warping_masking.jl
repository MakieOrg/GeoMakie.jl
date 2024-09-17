```@cardmeta
Title = "Raster warping, masking, plotting"
Description = "Semi involved example showing raster warping and masking, and plotting matrix lookup gridded data on a globe."
Cover = fig
```

#=

In this example, we want to show how you can create manipulate rasters for the purpose of visualization.

=#

using CairoMakie, GeoMakie
using Rasters, ArchGDAL,NaturalEarth, FileIO

# ## Background setup
# Set up the background.  First, load the image,
blue_marble_image = FileIO.load(FileIO.query(download("https://eoimages.gsfc.nasa.gov/images/imagerecords/76000/76487/world.200406.3x5400x2700.jpg"))) |> rotr90 .|> RGBA{Makie.Colors.N0f8}
# Your other choice is:
blue_marble_image = GeoMakie.earth() |> rotr90 .|> RGBA{Makie.Colors.N0f8}
# For the purposes of this example, we'll use the Natural Earth background image,
# since it's significantly smaller and the poor CI machine can't handle huge images.

# We wrap the image as a Raster for easy masking.
blue_marble_raster = Raster(
    blue_marble_image, # the contents
    ( # the dimensions go in this tuple.  `X` and `Y` are defined by the Rasters ecosystem.
        X(LinRange(-180, 180, size(blue_marble_image, 1))), 
        Y(LinRange(-90, 90, size(blue_marble_image, 2)))
    )
)
# Construct a mask of land using Natural Earth land polygons
land_mask = Rasters.boolmask(NaturalEarth.naturalearth("land", 10); to = blue_marble_raster)
# Now, create a new raster as a copy of the background image, 
# and set the values of all sea areas to be transparent.
land_raster = deepcopy(blue_marble_raster)
land_raster[(!).(land_mask)] .= RGBA{Makie.Colors.N0f8}(0.0, 0.0, 0.0, 0.0)
land_raster
# Do the same for the sea.
sea_raster = deepcopy(blue_marble_raster)
sea_raster[land_mask] .= RGBA{Makie.Colors.N0f8}(0.0, 0.0, 0.0, 0.0)
sea_raster

# ## Constructing fake data

# Now, we construct fake data.  
# First, we create a matrix of values.
field = [exp(cosd(x)) + 3(y/90) for x in -180:180, y in -90:90]
# Then, we wrap it in a Raster.  This is now gridded data, along the specified `X` and `Y` dimensions.
# Note the `missingval = NaN` keyword argument.  This is used to indicate that if the raster does have missing values,
# they should be represented as `NaN`, and not 0, for example.
ras = Raster(field, (X(LinRange(-30, 30, size(field, 1))), Y(LinRange(-5, 5, size(field, 2)))); missingval = NaN)

# We rotate the raster and then translate it to approximate the position in the image.
rotmat = Makie.rotmatrix2d(-π/5)

# We warp the raster by the parameters below.  This is in total basically
# rotating the raster by the rotation matrix `rotmat`, and then translating it 
# by 30 units in the x direction and -36 in the y direction.
# 
# This is where the `missingval` keyword argument comes in.  If we didn't have it,
# the values that are now `NaN` because they are outside the original raster would be filled by `0`, which is not what we want.
#
# Rasters.warp is pretty much a wrapper around [GDAL's `gdalwarp` program](https://gdal.org/en/latest/programs/gdalwarp.html), so all of the options are available.  It's incredibly versatile and flexible but is a bit tricky to use.
transformed = Rasters.warp(
    ras,
    Dict(
        "r" => "bilinear", 
        "ct" => #= see https://gdal.org/en/latest/programs/gdalwarp.html =# """
        +proj=pipeline
        +step +proj=affine +xoff=$(30) +yoff=$(-36) +s11=$(rotmat[1,1]) +s12=$(rotmat[1,2]) +s21=$(rotmat[2,1]) +s22=$(rotmat[2,2])
        """,
        "s_srs" => "+proj=longlat +datum=WGS84 +type=crs",
        "t_srs" => "+proj=longlat +datum=WGS84 +type=crs",
    )
)

# ## Plotting the data
# We use an orthographic GeoAxis to show the data.
# First, we create the figure and the axis,
fig = Figure()
ax = GeoAxis(fig[1, 1]; dest = "+proj=ortho +lon_0=0 +lat_0=0")
# Then, we plot the sea and land rasters.  These are our background images.
sea_plot = meshimage!(ax, sea_raster; source = "+proj=longlat +datum=WGS84 +type=crs", npoints = 300)

land_plot = meshimage!(ax, land_raster; source = "+proj=longlat +datum=WGS84 +type=crs", npoints = 300)
# Finally, we plot the transformed data.
data_plot = surface!(ax, transformed; shading = NoShading)
# Get the land plot above all other plots in the geoaxis.
translate!(land_plot, 0, 0, 1)
# Display the figure...
fig

# For extra credit, we'll find the center of the raster and transform the orthographic projection to be centered on it:

using Statistics
xy_matrix = Rasters.DimensionalData.DimPoints(transformed) |> collect
center_x = mean(first.(xy_matrix))
center_y = mean(last.(xy_matrix))

# We'll use the `ortho` projection, which is centered on the point we just found.
ax.dest[] = "+proj=ortho +lon_0=$(center_x) +lat_0=$(center_y)"
# Somehow, the limits are set to the wrong thing, so we'll set them manually and let the axis take care of it.
ax.limits[] = (-180, 180, -90, 90)
fig

# ## Plotting on the 3D globe

# Super bonus points: plot the data on the globe

using Geodesy

# fig = Figure(size = (1000, 1000));
fig2 = Figure()

ax = LScene(fig2[1, 1])

sea_plot = meshimage!(ax, sea_raster; npoints = 300)

land_plot = meshimage!(ax, land_raster; npoints = 300)

data_plot = surface!(ax, transformed; shading = NoShading)

land_plot.z_level[] = 1000 # this means raising land by 1 km over the sea!

sea_plot.transformation.transform_func[] = Geodesy.ECEFfromLLA(Geodesy.WGS84())
land_plot.transformation.transform_func[] = Geodesy.ECEFfromLLA(Geodesy.WGS84())
data_plot.transformation.transform_func[] = Geodesy.ECEFfromLLA(Geodesy.WGS84())

fig2