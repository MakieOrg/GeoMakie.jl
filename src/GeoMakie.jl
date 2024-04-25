module GeoMakie

using Statistics, LinearAlgebra

using Reexport

using GeometryBasics, Colors, ImageIO

using Makie

import Makie: convert_arguments, convert_attribute, to_value, automatic
using Makie, Makie.FileIO, Makie.GridLayoutBase, Makie.DocStringExtensions
using Makie: Format
using Makie.GridLayoutBase: Side

using GeoJSON
using GeoInterface: GeoInterface, coordinates, getfeature
using GeometryBasics: Polygon, MultiPolygon
using Geodesy

export GeoInterface


# fix conflicts
const AbstractGeometry = GeometryBasics.AbstractGeometry
const Point = Makie.Point
const attributes = Makie.attributes
const volume = Makie.volume
const Mesh = GeometryBasics.Mesh
const Text = Makie.Text
using Proj

# Quick fix for Makie
Makie.to_colormap(::Nothing) = nothing

# Resolve import conflicts
import Makie: rotate! # use LinearAlgebra.rotate! otherwise

include("geojson.jl") # GeoJSON/GeoInterface support
include("conversions.jl")
include("data.jl")
include("utils.jl")
include("geodesy.jl")

@reexport using Colors, Makie
export Proj

export FileIO

include("geoaxis.jl")
include("makie-axis.jl")

# some basic recipes
include("mesh_image.jl")

export GeoAxis, automatic

end # module
