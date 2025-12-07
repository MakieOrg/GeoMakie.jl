module GeoMakie

using Statistics, LinearAlgebra

using Reexport

using GeometryBasics, Colors, ImageIO

using Makie


import Makie: _create_plot!, mixin_generic_plot_attributes, mixin_colormap_attributes

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

include("makie_piracy.jl")    # Quick patches for Makie
include("geojson.jl")         # GeoJSON/GeoInterface support - should be deprecated at some point
include("conversions.jl")     # basic conversion functions - not sure if these are needed with GeometryOps now being a thing, or used anywhere
include("data.jl")            # data loading functions - `coastlines`, `earth`, `land`
include("utils.jl")           # utility functions - `geo2basic`, `to_multipoly`, `to_multilinestring`
include("geodesy.jl")         # Integrating Geodesy.jl coordinate transformations into Makie's transformation system
include("projection.jl")      # Integrating Proj.jl transformations into Makie's transformation system

# GeoAxis
include("geoaxis/geoaxis.jl")    # GeoAxis definition
include("geoaxis/makie-axis.jl") # Makie function overloads and integration for GeoAxis
include("geoaxis/geoticks.jl")   # Geo specific tick finder (again, not used at the moment, but should be)

# GlobeAxis
include("sphere/unit_sphere_transforms.jl") # Transformations from plate-carree to unit sphere - we should just use the implementation in GeometryOps now
include("sphere/icosphere.jl")              # Icosphere for full-globe plots, not yet used but should be used soon
include("sphere/globetransform.jl")         # GlobeTransform definitions for going to/from ellipsoids
include("sphere/globeaxis.jl")              # GlobeAxis definition and Makie function overloads

# some basic recipes
include("mesh_image.jl")    # Mesh image recipe - interpolate an image onto a projected mesh, saving a lot of cost compared to reprojecting the image
include("linesplitting.jl") # Line splitting submodule - used for splitting lines at the antimeridian

# This has to be last because it uses types introduced in other files
include("triangulation3d.jl") # 3D polygon triangulation for geospatial cases

@reexport using Colors, Makie
export Proj

export FileIO

export GeoAxis, automatic
export datalims, datalims!
@deprecate datalims Makie.autolimits
@deprecate datalims! Makie.reset_limits!

end # module
