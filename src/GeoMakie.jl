module GeoMakie

using GeometryTypes, EarCut, Colors, MakieLayout, AbstractPlotting

using MakieLayout: Formatting

using GeoInterface, Proj4

import AbstractPlotting: convert_arguments, convert_attribute



include("conversions.jl")
include("recipes/geoaxis.jl")

export geoaxis, WGS84

end # module

## TODOS
# TODO note you need to return a tuple rom conv-arg
