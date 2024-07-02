# # Histogram
# You can use any Makie compatible recipe in GeoMakie, and this includes histograms!
# Until we get the datashader recipe working, you can also consider this a replacement for that
# if you use it with the correct `nbins`.

# We use the excellent [`FHist.jl`](https://github.com/Moelf/FHist.jl) to create the histogram.

using CairoMakie, GeoMakie
using FHist
import CairoMakie: Point2d

# First, we generate random points in a normal distribution:
random_data = randn(Point2d, 100_000) 
# then, we rescale them to be within the lat/long bounds of the Earth:
xmin, xmax = extrema(first, random_data)
ymin, ymax = extrema(last, random_data)
latlong_data = random_data .* (Point2d(1/(xmax - xmin), 1/(ymax - ymin)) * Point2d(360, 180),)
# finally, we can create the histogram.
h = Hist2D((first.(latlong_data), last.(latlong_data)); nbins = (360, 180))
# This is what the histogram looks like without any projection,
plot(h)
# It's simple to plot to GeoAxis:
plot(h; axis = (; type = GeoAxis))
# The projection can also be arbitrary!
plot(h; axis = (; type = GeoAxis, dest = "+proj=tissot +lat_1=60 +lat_2=65"))
#=
```@cardmeta
Title = "Histogram"
Description = "Plotting histograms of points on a GeoAxis"
Cover = plot(h; axis = (; type = GeoAxis, dest = "+proj=tissot +lat_1=60 +lat_2=65"))
```
=#