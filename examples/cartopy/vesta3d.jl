using CairoMakie, GeoMakie
using FlyThroughPaths # to move the camera around the globe!
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
        "https://photojournal.jpl.nasa.gov/jpeg/PIA17037.jpg",
    )
)
# Now, we can load the image and create a `Raster` from it.  This is stored in memory.
vesta_image_matrix = FileIO.load(joinpath(DataDeps.datadep"vesta_image", "PIA17037.jpg"))

const SEMI_MAJOR_AXIS = 285000
const SEMI_MINOR_AXIS = 229000

VestaTransform = Makie.PointTrans{3}() do longlat

end