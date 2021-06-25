module GeoMakie

using Reexport
using GeometryBasics, Colors, Makie.MakieLayout, Makie, ImageMagick
using GeoJSON

using Makie.FileIO
using Makie.MakieLayout: Formatting
using Makie.MakieLayout.GridLayoutBase
using Makie.MakieLayout.GridLayoutBase: Side
using GeoInterface: GeoInterface, coordinates, AbstractPolygon, AbstractMultiPolygon, features, geometry

using Proj4: Proj4
import Makie: convert_arguments, convert_attribute
using Makie.DocStringExtensions

# fix conflicts
const AbstractGeometry = GeometryBasics.AbstractGeometry
const Point = Makie.Point
const attributes = Makie.attributes
const transform! = Proj4.transform!
const volume = Makie.volume
const Mesh = GeometryBasics.Mesh
const Text = Makie.Text

include("conversions.jl")
include("data.jl")

@reexport using Colors, Makie
export Proj4

end # module
