module GeoMakie

using Reexport
using GeometryBasics, Colors, Makie.MakieLayout, Makie, ImageMagick
using GeoJSON

using Makie.FileIO
using Makie.MakieLayout: Formatting
using Makie.MakieLayout.GridLayoutBase
using Makie.MakieLayout.GridLayoutBase: Side
using GeoInterface: GeoInterface, coordinates, AbstractPolygon, AbstractMultiPolygon, features, geometry

using Proj4
import Proj4: Projection
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
include("projections.jl")
include("data.jl")

export LonLat, PlateCarree, Mercator, TransverseMercator, UTM, AlbersEqualArea, Robinson, WinkelTripel

@reexport using Colors, Makie
@reexport using Proj4

end # module
