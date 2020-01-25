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
include("projections.jl")
include("utils.jl")
include("recipes/geoaxis.jl")

isdefined(MakieLayout, :WilkinsonTicks) || include("tick_compat.jl")

# export recipes

export geoaxis, geoaxis!

# export projections

export LonLat, PlateCarree, Mercator, TransverseMercator, UTM, AlbersEqualArea, Robinson, WinkelTripel

# export utilities

export rec_project, rec_point, triangulated_grid

end # module

## TODOS
# TODO note you need to return a tuple rom conv-arg
