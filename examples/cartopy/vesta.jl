# # Plotting in SPACE

#=
```@cardmeta
Description = "A plot of Vesta's surface, on a nonstandard ellipsoid."
Cover = fig
```
=#
using GeoMakie, CairoMakie
using Rasters, ArchGDAL
using ImageIO, DataDeps

# We use the DataDeps.jl package to register the image, and avoid
# repeated downloads - especially on CI.
DataDeps.register(
    DataDeps.DataDep(
        "vesta_image",
        """
        An image of Vesta's topography.
        Image credit: NASA/JPL-Caltech/UCLA/MPS/DLR/IDA/PSI
        """,
        "https://assets.science.nasa.gov/content/dam/science/psd/photojournal/pia/pia17/pia17037/PIA17037.jpg",
    )
)
# Now, we can load the image and create a `Raster` from it.  This is stored in memory.
vesta_image_matrix = FileIO.load(joinpath(DataDeps.datadep"vesta_image", "PIA17037.jpg"))
vesta_image_matrix = vesta_image_matrix[begin:2:end, begin:2:end] # hide
# Since this is an image of Vesta, we need to define its coordinate reference system (CRS).
# We use Proj's [ellipsoid parameters](https://proj.org/en/9.3/usage/ellipsoids.html#ellipsoid-size-parameters)
# to define the ellipsoid of Vesta, specifically the semi-major and semi-minor axes (`+a` and `+b` respectively).
vesta_crs = GeoMakie.GeoFormatTypes.ProjString("+proj=longlat +a=285000 +b=229000 +type=crs")
# Additionally, since the Vesta CRS is on a non-Earth datum, we have to set this environment variable
# so that Proj knows that we are aware of this problem:
ENV["PROJ_IGNORE_CELESTIAL_BODY"] = "yes"
# Now, we can create a `Raster` from the image.
vesta_raster = Raster(
    rotr90(vesta_image_matrix); 
    dims = (
        X(LinRange(-180, 180, size(vesta_image_matrix, 2))), 
        Y(LinRange(-90, 90, size(vesta_image_matrix, 1)))
    ),
    crs = vesta_crs
)

# Now that we have the data, we can go ahead and plot it:
fig = Figure()
ga = GeoAxis(fig[1, 1]; source = vesta_crs, dest = "+proj=geos +h=35785831 +a=285000 +b=229000")
mi = meshimage!(ga, -180..180, -90..90, vesta_image_matrix; shading = NoShading)
limits!(ga, (-180, 180), (-90, 90))
ga.title = "The surface of Vesta"
fig

# ## Using GlobeAxis!
f, a, p = meshimage(
    -180..180, -90..90, vesta_image_matrix;
    uv_transform = :rotr90,
    axis = (;
        type = GlobeAxis,
        dest = GeoMakie.Geodesy.Ellipsoid(; a = "285000", b="229000"),
        camera_longlat = (0, 0),
    )
)
