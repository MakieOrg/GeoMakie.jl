module GeoMakie

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

export GeoInterface


# fix conflicts
import Makie: rotate! # use LinearAlgebra.rotate! otherwise

const AbstractGeometry = GeometryBasics.AbstractGeometry
const Point = Makie.Point
const attributes = Makie.attributes
const volume = Makie.volume
const Mesh = GeometryBasics.Mesh
const Text = Makie.Text

# Quick fixes for Makie
Makie.to_colormap(::Nothing) = nothing
# Since Makie explicitly sets its allow list, this is definitely piracy,
# but if we don't do this then passing `source` or `dest` almost universally
# errors.
function Makie.MakieCore.attribute_name_allowlist()
    (:xautolimits, :yautolimits, :zautolimits, :label, :rasterize, :model, :transformation, :dest, :source, :specular, :matcap, :backlight, :shininess, :interpolate, :diffuse, :dim_conversions)
end

include("geojson.jl") # GeoJSON/GeoInterface support
include("conversions.jl")
include("data.jl")
include("utils.jl")
include("geodesy.jl")

include("geoaxis.jl")
include("makie-axis.jl")

# some basic recipes
include("mesh_image.jl")

@reexport using Colors, Makie
export Proj

export FileIO

export GeoAxis, datalims, datalims!, automatic

end # module
