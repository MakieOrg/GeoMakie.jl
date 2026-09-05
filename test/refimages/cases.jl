# cases.jl -- the reference-image cases: the same matrix as the decorations
# suite (twelve research baselines, two issue reproductions, and the
# most_projections destinations), rendered at 600 x 400.

using GeoMakie, CairoMakie, GeometryBasics
using GeoMakie: Proj

isdefined(@__MODULE__, :BoundaryHarness) || include(joinpath(@__DIR__, "..", "boundary", "harness.jl"))
isdefined(@__MODULE__, :DecorationCase) || include(joinpath(@__DIR__, "..", "decorations", "cases.jl"))

const REFIMAGE_CASES = DECORATION_CASES
const REFIMAGE_DIR = normpath(joinpath(@__DIR__, "..", "..", "test_images", "refimages"))
const RECORDED_DIR = joinpath(REFIMAGE_DIR, "recorded")

"Render one case to a figure."
function render_case(c::DecorationCase)
    fig, ax = build_case(c)
    return fig
end
