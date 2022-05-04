module GeoMakie

using Statistics, LinearAlgebra

using Reexport

using GeometryBasics, Colors, ImageIO

using Makie

import Makie: convert_arguments, convert_attribute, to_value, automatic
using Makie.MakieLayout, Makie.FileIO, Makie.MakieLayout.GridLayoutBase, Makie.DocStringExtensions
using Makie.MakieLayout: Formatting
using Makie.MakieLayout.GridLayoutBase: Side

using GeoJSON
using GeoInterface: GeoInterface, coordinates, AbstractPolygon, AbstractMultiPolygon, features, geometry
export GeoInterface


# fix conflicts
const AbstractGeometry = GeometryBasics.AbstractGeometry
const Point = Makie.Point
const attributes = Makie.attributes
const volume = Makie.volume
const Mesh = GeometryBasics.Mesh
const Text = Makie.Text
using Proj4
const Proj = Proj4
# using Proj

# Quick fix for Makie
Makie.to_colormap(::Nothing) = nothing

# Resolve import conflicts
import Makie: rotate! # use LinearAlgebra.rotate! otherwise

include("conversions.jl")
include("data.jl")
include("utils.jl")

@reexport using Colors, Makie
export Proj

export FileIO

include("geoaxis.jl")

export GeoAxis, geo2basic, datalims, datalims!, automatic

end # module
