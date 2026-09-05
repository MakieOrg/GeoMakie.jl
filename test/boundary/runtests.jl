using GeoMakie, GeometryBasics, LinearAlgebra, Statistics, Test
using GeoMakie: Proj
const GM = GeoMakie

isdefined(@__MODULE__, :BoundaryHarness) || include("harness.jl")

@testset "Boundary" begin
    @testset "Oracle" include("oracle.jl")
    @testset "Regions" include("regions.jl")
    @testset "Analytic" include("analytic.jl")
    @testset "Identify" include("identify.jl")
    @testset "Probe" include("probe.jl")
end
