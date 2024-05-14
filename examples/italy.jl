#=
# States of Italy

This example shows how to get data from a source and plot it using 
GeoMakie.  It's more to show how to hybridize two data sources than 
anything else.
=#
using CairoMakie, GeoMakie
CairoMakie.activate!(px_per_unit = 4) # hide
using GADM, DataFrames
import GeometryOps as GO
using GeoInterfaceMakie # hide
GeoInterfaceMakie.@enable GADM.ArchGDAL.IGeometry # hide

# Acquire data
ita_df = GADM.get("ITA"; depth = 1) |> DataFrame
ita_centroid = GO.centroid(ita_df.geom)
# Plot the data
fig = Figure()
ga = GeoAxis(
    fig[1, 1]; 
    dest = "+proj=ortho +lon_0=$(ita_centroid[1]) +lat_0=$(ita_centroid[2])"
)
poly!(
    ga, ita_df.geom; 
    color = 1:size(ita_df, 1), # this could be any vector of length `size(ita_df, 1)`
    strokecolor = :blue, strokewidth = 1, shading = NoShading
    )
fig
# That looks like a lot of ticks.  Let's simplify the grid:
ga.xticks = Makie.WilkinsonTicks(5; k_min = 3)
ga.yticks = Makie.WilkinsonTicks(10; k_min = 5)
fig
# Whoops, this doesn't cover the whole of Italy!
# No worries, we'll have a spine eventually to show this.

