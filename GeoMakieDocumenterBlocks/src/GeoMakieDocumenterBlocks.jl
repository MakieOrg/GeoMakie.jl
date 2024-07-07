module GeoMakieDocumenterBlocks

using Documenter
using ImageTransformations, ImageIO, Base64, FileIO # for resize
import Documenter: MarkdownAST
using Makie

include("types.jl")
include("ast_utils.jl")
include("build_step.jl")
include("cardmeta.jl")
include("overview.jl")

end