#=
# Inset map of the USA

This example shows how to create an inset map of the USA, that preserves areas as best as possible.

This example is based on https://geocompx.github.io/geocompkg/articles/us-map.html

=#

using GeoMakie, GLMakie
import GeoDataFrames
import GeometryOps as GO, GeoInterface as GI, GeoFormatTypes as GFT

#=
# Data preparation

The first step is to decide on the best projection for each individual inset. 
For this case, we decided to use equal area projections for the maps of the 
contiguous 48 states, Hawaii, and Alaska. 
While the dataset of Hawaii and Alaska already have this type of projections, 
we still need to reproject the `us_states` object to US National Atlas Equal Area:
=#

using NaturalEarth, DataFrames
us_states = DataFrame(naturalearth("admin_1_states_provinces", 50))
filter!(:gu_a3 => ==("USA"), us_states)
# Work around https://github.com/JuliaGeo/GeometryOps.jl/issues/215
us_states = us_states[!, [:geometry, :name]]
#
us_states2163 = GO.reproject(us_states, GFT.EPSG(4326), GFT.EPSG(2163))
# We also extract the two states of Hawaii and Alaska from the dataset.
hawaii = filter(:name => ==("Hawaii"), us_states2163).geometry |> only
hawaii = GO.reproject(hawaii, GI.crs(hawaii), GFT.ProjString("+proj=aea +lat_0=13 +lon_0=-157 +lat_1=8 +lat_2=18 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs +type=crs"))

alaska = filter(:name => ==("Alaska"), us_states2163).geometry |> only
alaska = GO.reproject(alaska, GI.crs(alaska), GFT.EPSG(3467))

#=
# Ratio calculation
The second step is to calculate scale relations between the main map 
(the contiguous 48 states) and Hawaii, and between the main map and Alaska. 
To do so we can calculate areas of the bounding box of each object:
=#

us_states_range = GI.extent(us_states2163.geometry |> GI.GeometryCollection).Y[2] - GI.extent(us_states2163.geometry |> GI.GeometryCollection).Y[1]
hawaii_range = GI.extent(hawaii).Y[2] - GI.extent(hawaii).Y[1]
alaska_range = GI.extent(alaska).Y[2] - GI.extent(alaska).Y[1]

# Next, we can calculate the ratio between their areas:

us_states_hawaii_ratio = hawaii_range / us_states_range
us_states_alaska_ratio = alaska_range / us_states_range
(; us_states_hawaii_ratio, us_states_alaska_ratio) # hide

#=
# Map creation

We can now create the inset maps.

Here, we diverge from the original example, since Makie.jl does not 
support creating axes independently of a Figure easily.

=#

# First, we instantiate the figure and the axes:
fig = Figure(size = (1200, 800))
## Alaska takes the top row
ax_alaska = GeoAxis(fig[1, 1]; source = GI.crs(alaska), dest = GI.crs(alaska), tellheight = false, tellwidth = false)
poly!(ax_alaska, alaska; source = GI.crs(alaska), color = :lightgray, strokewidth = 0.75, strokecolor = :darkgray)
## The contiguous 48 states take the bottom row
ax_cont48 = GeoAxis(fig[2, 1]; source = GI.crs(us_states2163), dest = GI.crs(us_states2163), tellheight = false, tellwidth = false)
poly!(ax_cont48, filter(:name => ∉(("Alaska", "Hawaii")), us_states2163).geometry; source = GI.crs(us_states2163), color = :lightgray, strokewidth = 0.75, strokecolor = :darkgray)
## Hawaii will be an inset, so we don't assign it a grid cell yet:
ax_hawaii = GeoAxis(fig; source = GI.crs(hawaii), dest = GI.crs(hawaii), tellheight = false, tellwidth = false)
poly!(ax_hawaii, hawaii; source = GI.crs(hawaii), color = :lightgray, strokewidth = 0.75, strokecolor = :darkgray)

hidedecorations!(ax_alaska)
hidedecorations!(ax_cont48)
hidedecorations!(ax_hawaii)
fig
# Now, we can set the row heights:
rowsize!(fig.layout, 1, Auto(false, us_states_alaska_ratio))
rowsize!(fig.layout, 2, Auto(false, 1))
rowgap!(fig.layout, 0)
fig

# Now, we move Hawaii to its rightful place:
fig[2, 1] = ax_hawaii
ax_hawaii.valign[] = 0.07
ax_hawaii.halign[] = 0
ax_hawaii.height[] = Auto(false, us_states_hawaii_ratio / (us_states_alaska_ratio + 1))
#=

=#
fig