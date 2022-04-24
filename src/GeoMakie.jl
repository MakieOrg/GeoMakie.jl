module GeoMakie

using Reexport
using GeometryBasics, Colors, Makie.MakieLayout, Makie, ImageIO
using GeoJSON

using Makie.FileIO
using Makie.MakieLayout: Formatting
using Makie.MakieLayout.GridLayoutBase
using Makie.MakieLayout.GridLayoutBase: Side
using GeoInterface: GeoInterface, coordinates, AbstractPolygon, AbstractMultiPolygon, features, geometry
export GeoInterface

import Makie: convert_arguments, convert_attribute
using Makie.DocStringExtensions

# fix conflicts
const AbstractGeometry = GeometryBasics.AbstractGeometry
const Point = Makie.Point
const attributes = Makie.attributes
const volume = Makie.volume
const Mesh = GeometryBasics.Mesh
const Text = Makie.Text
using Proj


include("conversions.jl")
include("data.jl")
include("utils.jl")

@reexport using Colors, Makie
export Proj

include("geoaxis.jl")

export GeoAxis, geo2basic

end # module
