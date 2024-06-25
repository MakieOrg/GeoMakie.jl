module GeoMakieDocumenterBlocks

using Documenter
using ImageTransformations, ImageIO, Base64, FileIO # for resize
import Documenter: MarkdownAST
using Makie

const GALLERY_DICT = Dict{String, Any}()

export GALLERY_DICT

include("cardmeta.jl")
include("overview.jl")

end