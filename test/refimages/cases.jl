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

# Renders beyond the case matrix: what the predicates cannot see.
const EXTRA_RENDERS = [
    # the graticule behind a plot (gridbehind, #338): markers cover the grid lines they sit on
    "merc_reg_scatter" => () -> begin
        fig, ax = build_case(decoration_case(DECORATION_CASES, "merc_reg"))
        scatter!(ax, [0.0, 10.0, 20.0], [40.0, 45.0, 50.0]; markersize = 30, color = :orange)
        fig
    end,
    # a dark theme: spine and grid follow the Axis theme (#339)
    "merc_reg_dark" => () -> with_theme(theme_dark()) do
        fig, ax = build_case(decoration_case(DECORATION_CASES, "merc_reg"))
        fig
    end,
    # a GeoAxis beside an Axis with the same title, labels and tick geometry: the
    # same size on screen, the labels lined up (Phase 7's manual check)
    "merc_reg_axis_parity" => () -> build_axis_parity()[1],
    # issue 349: hidden y decorations leave equal column gaps
    "issue349_row" => () -> build_issue349()[1],
    # issue 268: a grid of GeoAxes packs like a grid of Axes
    "issue268_grid" => () -> build_issue268()[1],
    # the mask (Phase 8): markers straddling the frame are cut at it, under the spine and the labels
    "lcc_title_scatter" => () -> begin
        fig, ax = build_case(decoration_case(DECORATION_CASES, "lcc_title"))
        scatter!(ax, [-125.0, -68.0, -95.0, -95.0], [50.0, 50.0, 21.0, 52.0]; markersize = 40, color = :orange)
        fig
    end,
    # issue 281: the exact space after tight_ticklabel_spacing! on a limb
    "ortho_tight" => () -> begin
        fig, ax = build_case(decoration_case(DECORATION_CASES, "ortho"))
        tight_ticklabel_spacing!(ax)
        fig
    end,
]

"Every render, by name: the case matrix and the extra renders."
all_renders() = vcat([c.name => (() -> render_case(c)) for c in REFIMAGE_CASES], EXTRA_RENDERS)
