module GeoMakie

using Reexport
using GeometryBasics, Colors, Makie.MakieLayout, Makie, ImageMagick
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

include("conversions.jl")
include("data.jl")

@reexport using Colors, Makie
using Proj4
export Proj4

include("api.jl")

export GeoAxis

end # module
