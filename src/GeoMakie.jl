module GeoMakie

using Statistics, LinearAlgebra

using Reexport

using GeometryBasics, Colors, ImageIO

using Makie
using Makie.MakieCore

import Makie: convert_arguments, convert_attribute, to_value, automatic
using Makie, Makie.FileIO, Makie.GridLayoutBase, Makie.DocStringExtensions
using Makie: Format
using Makie.GridLayoutBase: Side

using GeoJSON, NaturalEarth # for data

import GeometryOps as GO, GeoInterface as GI
using GeoInterface: GeoInterface, coordinates, getfeature
using GeometryBasics: Polygon, MultiPolygon

using Geodesy
using Proj
import GeoFormatTypes

import GeoInterfaceMakie # to activate GI geometry plotting

export GeoInterface

# bring in missing Makie methods required for block definition
using Makie: make_block_docstring

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
include("triangulation3d.jl")
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

include("sphere/unit_sphere_transforms.jl")
include("sphere/icosphere.jl")
include("sphere/globetransform.jl")
include("sphere/globeaxis.jl")

@reexport using Colors, Makie
export Proj

export FileIO

export GeoAxis, automatic
export datalims, datalims!
@deprecate datalims Makie.autolimits
@deprecate datalims! Makie.reset_limits!

end # module
