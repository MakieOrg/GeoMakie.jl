```@cardmeta
Title = "Raster warping, masking, plotting"
Description = "Semi involved example showing raster warping and masking, and plotting matrix lookup gridded data on a globe."
Cover = fig
```

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
#
land_raster = deepcopy(blue_marble_raster)
land_raster[(!).(land_mask)] .= RGBA{Makie.Colors.N0f8}(0.0, 0.0, 0.0, 0.0)
land_raster

sea_raster = deepcopy(blue_marble_raster)
sea_raster[land_mask] .= RGBA{Makie.Colors.N0f8}(0.0, 0.0, 0.0, 0.0)
sea_raster

# ## Constructing fake data

# Now, we construct fake data.
field = [exp(cosd(x)) + 3(y/90) for x in -180:180, y in -90:90]

ras = Raster(field, (X(LinRange(-30, 30, size(field, 1))), Y(LinRange(-5, 5, size(field, 2)))); missingval = NaN)

# We rotate the raster and then translate it to approximate the position in the image.
rotmat = Makie.rotmatrix2d(-π/5)

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

fig = Figure(size = (1000, 1000))
ax = GeoAxis(fig[1, 1]; dest = "+proj=ortho +lon_0=0 +lat_0=0")

sea_plot = meshimage!(ax, sea_raster; source = "+proj=longlat +datum=WGS84 +type=crs", npoints = 300)

land_plot = meshimage!(ax, land_raster; source = "+proj=longlat +datum=WGS84 +type=crs", npoints = 300)

data_plot = surface!(ax, transformed; shading = NoShading)
# Get the land plot above all other plots in the geoaxis.
translate!(land_plot, 0, 0, 1)
# Display the figure...
fig

# For extra credit, we'll find the center of the raster and transform the orthographic projection to be centered on it:

xy_matrix = Rasters.DimensionalData.DimPoints(transformed) |> collect
center_x = mean(first.(xy_matrix))
center_y = mean(last.(xy_matrix))

# We'll use the `ortho` projection, which is centered on the point we just found.
ax.dest = "+proj=ortho +lon_0=$(center_x) +lat_0=$(center_y)"

fig

# ## Plotting on the 3D globe

# Super bonus points: plot the data on the globe

using Geodesy

# fig = Figure(size = (1000, 1000));
fig = Figure()

ax = LScene(fig[1, 1])

sea_plot = meshimage!(ax, sea_raster; npoints = 300)

land_plot = meshimage!(ax, land_raster; npoints = 300)

data_plot = surface!(ax, transformed; shading = NoShading)

land_plot.z_level[] = 1000

sea_plot.transformation.transform_func[] = Geodesy.ECEFfromLLA(Geodesy.WGS84())
land_plot.transformation.transform_func[] = Geodesy.ECEFfromLLA(Geodesy.WGS84())
data_plot.transformation.transform_func[] = Geodesy.ECEFfromLLA(Geodesy.WGS84())

fig