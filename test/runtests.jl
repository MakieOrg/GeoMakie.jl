using GeoMakie, GeometryBasics, CairoMakie, Test
import Makie.SpecApi as S

Makie.set_theme!(Theme(
    Heatmap = (rasterize = 5,),
    Image   = (rasterize = 5,),
    Surface = (rasterize = 5,),
))
@testset "GeoMakie" begin
    @testset "Basics" include("basics.jl")
    @testset "MeshImage" include("meshimage.jl")
    @testset "GeoAxis" include("geoaxis.jl")
    @testset "Graticule" include("graticule.jl")
    @testset "GeoAxis tick labels" include("geoticklabels.jl")
    @testset "GlobeAxis" include("globeaxis.jl")
end
