module GeoMakie

# Because we override a MakieCore method here, we can't precompile.
# However, what we can do is potentially eval the method into Makie 
# at `__init__`, but that would also invalidate lots of Makie caches.
# One way might be to define a const array in MakieCore which can be 
# pushed to by different packages...
__precompile__(false)

using Statistics, LinearAlgebra

using Reexport

using GeometryBasics, Colors, ImageIO

using Makie

import Makie: convert_arguments, convert_attribute, to_value, automatic
using Makie, Makie.FileIO, Makie.GridLayoutBase, Makie.DocStringExtensions
using Makie: Format
using Makie.GridLayoutBase: Side

using GeoJSON, NaturalEarth # for data
using GeoInterface: GeoInterface, coordinates, getfeature
using GeometryBasics: Polygon, MultiPolygon
using Geodesy
using Proj
import GeoFormatTypes

export GeoInterface


# fix conflicts
import Makie: rotate! # use LinearAlgebra.rotate! otherwise

const AbstractGeometry = GeometryBasics.AbstractGeometry
const Point = Makie.Point
const attributes = Makie.attributes
const volume = Makie.volume
const Mesh = GeometryBasics.Mesh
const Text = Makie.Text

# Quick fix for GeometryBasics
Base.convert(::Type{Rect{N, Float64}}, x::Rect{N}) where N = Rect{N, Float64}(x)

include("makie_piracy.jl")
include("geojson.jl") # GeoJSON/GeoInterface support
include("conversions.jl")
include("data.jl")
include("utils.jl")
include("geodesy.jl")
include("geoticks.jl")
include("projection.jl")

include("geoaxis.jl")
include("makie-axis.jl")

# some basic recipes
include("mesh_image.jl")
include("linesplitting.jl")

@reexport using Colors, Makie
export Proj

export FileIO

export GeoAxis, datalims, datalims!, automatic

end # module
