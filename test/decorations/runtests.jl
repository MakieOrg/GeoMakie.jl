using GeoMakie, GeometryBasics, LinearAlgebra, Statistics, Test, CairoMakie
using GeoMakie: Proj
const GM = GeoMakie

isdefined(@__MODULE__, :BoundaryHarness) || include(joinpath(@__DIR__, "..", "boundary", "harness.jl"))
include("cases.jl")
include("predicates.jl")

@testset "Decorations" begin
    include("ticks.jl")
    include("suite.jl")
    include("placement.jl")
    include("layout.jl")
end
