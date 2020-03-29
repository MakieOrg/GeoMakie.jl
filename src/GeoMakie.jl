module GeoMakie

using Reexport
using GeometryTypes, EarCut, Colors, MakieLayout, AbstractPlotting, ImageMagick, GeoJSON, Glob

using MakieLayout: Formatting

using MakieLayout.GridLayoutBase
using MakieLayout.GridLayoutBase: Side

@reexport using Colors, AbstractPlotting
@reexport using GeoInterface, Proj4, NASAEarthObservations

import AbstractPlotting: convert_arguments, convert_attribute
using AbstractPlotting.DocStringExtensions

# fix conflicts
const AbstractGeometry = GeometryTypes.AbstractGeometry
const Point = AbstractPlotting.Point
const attributes = AbstractPlotting.attributes
const transform! = Proj4.transform!
const volume = AbstractPlotting.volume

include("conversions.jl")
include("projections.jl")
include("utils.jl")
include("tick_compat.jl")
include("data.jl")

include("recipes/geoaxis.jl")
include("recipes/stock.jl")


# export recipes

export geoaxis, geoaxis!

# export projections

export LonLat, PlateCarree, Mercator, TransverseMercator, UTM, AlbersEqualArea, Robinson, WinkelTripel

# export utilities

export rec_project, rec_point, xygrid

# function __init__()
#     Base.delete_method(methods(coastlines!).ms[6])
#     Base.delete_method(methods(earth!).ms[6])
# end

end # module

## TODOS
# TODO note you need to return a tuple rom conv-arg
