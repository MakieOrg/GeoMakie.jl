module GeoMakie

using Reexport
using GeometryBasics, Colors, AbstractPlotting.MakieLayout, AbstractPlotting, ImageMagick
using GeoJSON

using AbstractPlotting.FileIO
using AbstractPlotting.MakieLayout: Formatting
using AbstractPlotting.MakieLayout.GridLayoutBase
using AbstractPlotting.MakieLayout.GridLayoutBase: Side
using GeoInterface: GeoInterface, coordinates, AbstractPolygon, AbstractMultiPolygon, features, geometry

using Proj4
import Proj4: Projection
import AbstractPlotting: convert_arguments, convert_attribute
using AbstractPlotting.DocStringExtensions

# fix conflicts
const AbstractGeometry = GeometryBasics.AbstractGeometry
const Point = AbstractPlotting.Point
const attributes = AbstractPlotting.attributes
const transform! = Proj4.transform!
const volume = AbstractPlotting.volume
const Mesh = GeometryBasics.Mesh
const Text = AbstractPlotting.Text

include("conversions.jl")
include("projections.jl")
include("data.jl")

export LonLat, PlateCarree, Mercator, TransverseMercator, UTM, AlbersEqualArea, Robinson, WinkelTripel

@reexport using Colors, AbstractPlotting
@reexport using Proj4

end # module
