using Documenter, DocumenterVitepress, Literate
using GeoMakie, CairoMakie, Makie, GeoInterfaceMakie
# Set some global settings
# Good quality CairoMakie with PNG
CairoMakie.activate!(px_per_unit = 4, type = :png)
# Rasters should download into the artifacts folder (so they can be cached :D)
ENV["RASTERDATASOURCES_PATH"] = joinpath(first(Base.DEPOT_PATH), "artifacts")

# invoke some geomakie things to be sure
GeoMakie.coastlines()
GeoMakie.earth()

deploy = length(ARGS) == 1 && ARGS[1] == "deploy"
if deploy && !haskey(ENV, "GITHUB_TOKEN")
    @warn("Not deploying, no GITHUB_TOKEN not found in ENV")
    deploy = false
end

# use Literate for examples
examples = readdir(joinpath(dirname(@__DIR__), "examples"); join = true)
exclude = Set(["geodesy.jl", "makiecon_examples.jl", "multiple_crs.jl"])
filter!(examples) do file
    isfile(file) && !(basename(file) in exclude) && endswith(file, ".jl")
end
# for example in examples
#     Literate.markdown(example, joinpath(@__DIR__, "src", "examples"); documenter = true)
# end

makedocs(;
    modules=[GeoMakie],
    doctest=false,
    format=DocumenterVitepress.MarkdownVitepress(; 
        repo = "https://github.com/MakieOrg/GeoMakie.jl", 
        deploy_url = "https://geo.makie.org",
        devbranch = "master",
        devurl = "dev",
    ),
    pages=[
        "Introduction" => "introduction.md",
        "Nonlinear transforms" => "nonlinear_transforms.md",
        # "Examples" => [
        #     "Basic examples" => "examples/basic.md",
        #     "New API" => "examples/new.md",
        #     "Orthographic projection" => "examples/orthographic.md",
        #     "German Lakes" => "examples/german_lakes.md",
        #     "Geostationary satellite image" => "examples/geostationary_image.md",
        #     "Contourf" => "examples/contourf.md",
        #     # "Multiple CRS" => "examples/multiple_crs.md",
        #     "World Population centers" => "examples/world_population.md",
        #     "Field and countries" => "examples/field_and_countries.md",
        #     "Mesh image recipe" => "examples/meshimage.md",
        #     # "Geodetic transformation to the sphere" => "examples/geodesy.md",
        #     "Axis configuration" => "examples/axis_config.md",
        #     # "Italy's states" => "examples/italy.md",
        #     # "Most Projections" => "examples/most_projections.md",
        #     "Projections" => "examples/projections.md",
        #     # "GraphMakie with GeoMakie" => "examples/graph_on_usa.md",
        # ],
        "Developer documentation" => [
            "Architecture" => "architecture.md",
        ]
        ],
    sitename="GeoMakie.jl",
    authors="Anshul Singhvi and the Makie.jl contributors",
    warnonly = true,
)

isdir(joinpath(@__DIR__, "src", "examples")) && rm.(readdir(joinpath(@__DIR__, "src", "examples"); join = true); force = true)

deploy && deploydocs(; repo="github.com/MakieOrg/GeoMakie.jl", target="build", push_preview=true)
