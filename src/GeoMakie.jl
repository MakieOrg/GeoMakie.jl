module GeoMakie

using Reexport
using GeometryTypes, EarCut, Colors, MakieLayout, AbstractPlotting

using MakieLayout: Formatting

@reexport using Colors, AbstractPlotting
@reexport using GeoInterface, Proj4

import AbstractPlotting: convert_arguments, convert_attribute

# fix conflicts
const AbstractGeometry = GeometryTypes.AbstractGeometry
const Point = AbstractPlotting.Point
const attributes = AbstractPlotting.attributes
const transform! = Proj4.transform!
const volume = AbstractPlotting.volume

include("conversions.jl")
include("utils.jl")
include("recipes/geoaxis.jl")


# export recipes

export geoaxis, geoaxis!

# export projections

export WGS84

# export utilities

export rec_project, rec_point

end # module

## TODOS
# TODO note you need to return a tuple rom conv-arg
