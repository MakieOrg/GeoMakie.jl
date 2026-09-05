using GeoMakie, GeometryBasics, CairoMakie, Test
import Makie.SpecApi as S

Makie.set_theme!(Theme(
    Heatmap = (rasterize = 5,),
    Image   = (rasterize = 5,),
    Surface = (rasterize = 5,),
))
@testset "GeoMakie" begin
    @testset "Basics" include("basics.jl")
    @testset "LineSplitting" include("linesplitting.jl")
    @testset "MeshImage" include("meshimage.jl")
    @testset "GeoAxis" include("geoaxis.jl")
    @testset "GlobeAxis" include("globeaxis.jl")
    @testset "Boundary" include("boundary/runtests.jl")
    @testset "Frame" include("frame/runtests.jl")
    @testset "Decorations" include("decorations/runtests.jl")
    @testset "Speed" include("speed.jl")
end
