using Documenter, Literate
using GeoMakie, CairoMakie
CairoMakie.activate!()

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
deleteat!(examples, collect(axes(examples, 1))[(!).(isfile.(examples))])
for example in examples
    Literate.markdown(example, joinpath(@__DIR__, "src"); documenter = true)
end

makedocs(;
    modules=[GeoMakie],
    doctest=false,
    format=Documenter.HTML(; prettyurls=deploy, collapselevel=3),
    pages=[
        "GeoMakie.jl" => "index.md",
        "Examples" => [
            "Basic examples" => "basic.md",
            "Geostationary satellite image" => "geostationary_image.md",
            "Contourf" => "contourf.md",
            "Axis configuration" => "axis_config.md",
            "Geodetic transformation to the sphere" => "geodesy.md",
            # "Italy's states" => "italy.md",
            "Most Projections" => "most_projections.md",
            "Projections" => "projections.md",
            "Orthographic projection" => "orthographic.md",
            "World Population centers" => "world_population.md",
            "Field and countries" => "field_and_countries.md",
            "Mesh image recipe" => "meshimage.md",
            # "GraphMakie with GeoMakie" => "graph_on_usa.md",
        ],
        "Nonlinear transforms" => "nonlinear_transforms.md",
        "Developer documentation" => [
            "Architecture" => "architecture.md"
        ]
        ],
    sitename="GeoMakie.jl",
    authors="Anshul Singhvi and the Makie.jl contributors",
    strict=true)

deploy && deploydocs(; repo="github.com/MakieOrg/GeoMakie.jl", target="build", push_preview=true)
