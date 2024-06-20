using Test
using Makie, GeoMakie

@testset "Meshimage color attribute passthrough" begin
    img = rand(10, 10)
    f, a, p = meshimage(0..1, 0..1, img)
    @test p.colormap[] == :viridis
    @test p.plots[1].colormap[] == :viridis
    p.colormap[] = :jet
    @test p.colormap[] == :jet
    @test p.plots[1].colormap[] == :jet
end
