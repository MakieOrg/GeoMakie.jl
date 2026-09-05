# layout.jl -- the layout loop cannot run away: the protrusions are a bound
# computed before the viewport is known, so an equatorial laea with a title
# (the stack overflow of 098fb1b) constructs at once, and construction writes
# the protrusions at most twice (once with the limits in, once more when the
# layout hands the axis its viewport).

using GeoMakie, CairoMakie, GeometryBasics, Test
const GM = GeoMakie

isdefined(@__MODULE__, :BoundaryHarness) || include(joinpath(@__DIR__, "..", "boundary", "harness.jl"))
isdefined(@__MODULE__, :DecorationCase) || include(joinpath(@__DIR__, "cases.jl"))

"Construct a titled axis on `dest`, returning the seconds it took and the protrusion writes it made."
function construct_counted(dest; size = (600, 400), attrs...)
    GM.PROTRUSION_WRITES[] = 0
    local ax
    t = @elapsed begin
        fig = Figure(; size)
        ax = GeoAxis(fig[1, 1]; dest, title = "x", attrs...)
        Makie.update_state_before_display!(fig)
    end
    return t, GM.PROTRUSION_WRITES[], ax
end

@testset "layout has no feedback" begin
    # a first construction pays compilation; the timed one does not
    construct_counted("+proj=laea +lat_0=0")
    t, writes, ax = construct_counted("+proj=laea +lat_0=0")
    @test writes <= 2
    @test t < 5.0
    p = ax.layoutobservables.protrusions[]
    @test all(isfinite, (p.left, p.right, p.bottom, p.top))
    @test p.top > 0                       # the title is reserved
    @test p == GM.decorations(ax).protrusions
    # the same holds for every baseline case
    for c in BASELINE_CASES
        _, writes, _ = construct_counted(c.dest; (c.limits === nothing ? (;) : (; limits = c.limits))...)
        @test writes <= 2
    end
    # a resize is at most one more write, a title change exactly one
    fig = Figure(size = (600, 400))
    ax = GeoAxis(fig[1, 1]; dest = "+proj=laea +lat_0=0", title = "x")
    Makie.update_state_before_display!(fig)
    GM.PROTRUSION_WRITES[] = 0
    resize!(fig, 800, 500)
    Makie.update_state_before_display!(fig)
    @test GM.PROTRUSION_WRITES[] <= 1
    GM.PROTRUSION_WRITES[] = 0
    top = ax.layoutobservables.protrusions[].top
    ax.titlesize = 2 * ax.titlesize[]
    @test GM.PROTRUSION_WRITES[] == 1
    @test ax.layoutobservables.protrusions[].top > top
end
