using GeoMakie, GeometryBasics, LinearAlgebra, Statistics, Test, CairoMakie
using GeoMakie: Proj
const GM = GeoMakie

isdefined(@__MODULE__, :BoundaryHarness) || include(joinpath(@__DIR__, "..", "boundary", "harness.jl"))
include("views.jl")

@testset "Frame" begin
    @testset "views" begin
        @test length(VIEWS) == 29
        @test all(v -> !isempty(GM.rim(v.region)), VIEWS)
    end
    @testset "frame" include("frame.jl")
end
