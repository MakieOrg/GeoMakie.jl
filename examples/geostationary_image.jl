# # Image from satellite

# In this example, we'll show how to plot an image from a 
# geostationary satellite into your chosen projection 
# directly.

# Geostationary satellite images are, naturally, from their 
# perspective.  When projecting them onto maps, you would usually
# have to reproject the entire image to the map's projection, 
# meaning that you will inevitably blur or lose data at small scales.

# One way of getting around this is by rendering the image as a mesh, 
# using GeoMakie's `meshimage` recipe.
#
# This recipe basically creates a mesh in the space of the `source` projection,
# then reprojects the points making up that mesh to the `dest` projection,
# and renders the image on that mesh.  
#
# This means that the correct values are 
# dynamically calculated and interpolated directly onto the screen, 
# leading to less loss of data, and the ability to display much larger images
# or even dynamic images scaled on zoom level, like map tiles.

# First, we load our packages and download the image we want to display, 
# in this case a black-and-white image of the Earth from a satellite in 
# geostationary orbit.
using Makie, GeoMakie, CairoMakie
CairoMakie.activate!(px_per_unit = 4) # hide
using Downloads, FileIO
# Download a geostationary satellite image
img = FileIO.load(Downloads.download("https://gist.github.com/pelson/5871263/raw/EIDA50_201211061300_clip2.png"))
image(img)
# Above, you can see what the image looks like originally.

# Now, we create a GeoAxis in the Natural Earth projection, 
# and plot the coastlines for reference:
fig = Figure()
ga = GeoAxis(fig[1, 1]; dest = "+proj=natearth", title = "Image from geostationary satellite")
lines!(ga, GeoMakie.coastlines())
fig
# Finally, we can plot the image using the `meshimage!` recipe:
mi = meshimage!(ga,
    -5500000 .. 5500000, -5500000 .. 5500000, img;
    source="+proj=geos +h=35786000",
    npoints=100
)
translate!(mi, 0,0,-1) # get this below the coastlines
fig

# Now, if we scale the density of the mesh's grid by increasing
# the value of `npoints`, we get a finer interpolation:

mi.npoints[] = 500
fig

# Note how the jagged edges have decreased substantially.

mi.npoints[] = 1000
fig

# Of course, at some point we hit diminishing returns.

#=
# Surface could be used as well, but is slower!
```julia
surface!(
    ga,
    -5500000..5500000, -5500000..5500000, # the bounding box in input space for the image
    ones(size(img)...); # dummy points to create the surface
    color = img,
    source = "+proj=geos +h=35786000"
)
```
=#