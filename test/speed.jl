# speed.jl -- calibrated wall-clock per level of the decoration graph.
#
# A fixed reference workload (100k points through +proj=robin, and a sort of
# 1e6 floats) gives a machine factor relative to the reference developer
# machine; budgets scale by it, with a hard ceiling.  PROJ calls and
# allocations are reported beside each time, never asserted.

using GeoMakie, CairoMakie, GeometryBasics, Statistics, Test
using GeoMakie: Proj, ComputePipeline
const GM = GeoMakie

isdefined(@__MODULE__, :BoundaryHarness) || include(joinpath(@__DIR__, "boundary", "harness.jl"))
isdefined(@__MODULE__, :DecorationCase) || include(joinpath(@__DIR__, "decorations", "cases.jl"))

const REF_PROJ_S = 2.9e-3        # 100k robin points on the reference machine
const REF_SORT_S = 6.5e-3        # sort of 1e6 Float64 on the reference machine
const LEVEL3_BUDGET_S = 16e-3
const LEVEL4_BUDGET_S = 4e-3
const LEVEL3_CEILING_S = 150e-3
const RUNS = 20

function machine_factor()
    t = Proj.Transformation(GM.LONLAT_CRS, "+proj=robin"; always_xy = true)
    pts = [Point2d(360rand() - 180, 180rand() - 90) for _ in 1:100_000]
    Makie.apply_transform(t, pts[1:100])
    tp = minimum(@elapsed(Makie.apply_transform(t, pts)) for _ in 1:5)
    v = rand(1_000_000)
    sort(v[1:100])
    ts = minimum(@elapsed(sort(v)) for _ in 1:5)
    return max(1.0, 0.5 * (tp / REF_PROJ_S + ts / REF_SORT_S)), tp, ts
end

"Median seconds of `f(k)` over `RUNS` runs after two warm-ups."
function timed(f)
    f(1); f(2)
    return median(@elapsed(f(k)) for k in 3:(RUNS + 2))
end

"Level 3 (zoom / pan): a new limits rectangle, read through to the labels and the bound."
function pan!(ax, r0, k)
    w = widths(r0)
    ax.targetlimits[] = Rect2d(minimum(r0) .+ (0.01k) .* w, w .* (1 + 0.002k))
    ax.graph[:labels][]
    ax.graph[:protrusion_bound][]
    return nothing
end

"Level 4 (resize): a new viewport, read through to the pixels."
function resize_view!(ax, vp0, k)
    ComputePipeline.update!(ax.graph; viewport = Rect2i(minimum(vp0), widths(vp0) .+ (k % 2, (k + 1) % 2)))
    ax.graph[:pixels][]
    return nothing
end

factor, tp, ts = machine_factor()
println("machine factor ", round(factor; digits = 2), "  (proj 100k ", round(tp * 1e3; digits = 1), " ms, sort 1e6 ",
    round(ts * 1e3; digits = 1), " ms)")
budget3 = min(LEVEL3_BUDGET_S * factor * 2, LEVEL3_CEILING_S)
budget4 = LEVEL4_BUDGET_S * factor * 2

@testset "speed" begin
    println(rpad("case", 22), lpad("level 3", 10), lpad("level 4", 10), lpad("PROJ/pan", 10), lpad("alloc/pan", 12))
    for c in vcat(BASELINE_CASES, ISSUE_CASES)
        fig, ax = build_case(c; coastlines = false)
        r0 = ax.targetlimits[]
        vp0 = ax.scene.viewport[]
        builds0 = GM.BOUNDARY_BUILDS[]
        t3 = timed(k -> pan!(ax, r0, k))
        GM.PROJ_CALLS[] = 0
        pan!(ax, r0, RUNS + 3)
        calls = GM.PROJ_CALLS[]
        alloc = @allocated pan!(ax, r0, RUNS + 4)
        t4 = timed(k -> resize_view!(ax, vp0, k))
        # a pan of the camera (limits), a resize, and xlims! rebuild nothing at level 1
        xlims!(ax, minimum(r0)[1], maximum(r0)[1])
        resize!(fig, 700, 450)
        Makie.update_state_before_display!(fig)
        println(rpad(c.name, 22), lpad(string(round(t3 * 1e3; digits = 2), " ms"), 10),
            lpad(string(round(t4 * 1e3; digits = 2), " ms"), 10), lpad(calls, 10),
            lpad(string(round(alloc / 1e6; digits = 2), " MB"), 12))
        @testset "$(c.name)" begin
            @test t3 <= budget3
            @test t4 <= budget4
            @test GM.BOUNDARY_BUILDS[] == builds0
        end
    end
end
