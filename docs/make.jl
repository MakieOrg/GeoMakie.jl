using Documenter, GeoMakie, CairoMakie
CairoMakie.activate!()

# invoke some geomakie things to be sure
GeoMakie.coastlines()
GeoMakie.earth()

deploy = length(ARGS) == 1 && ARGS[1] == "deploy"
if deploy && !haskey(ENV, "GITHUB_TOKEN")
    @warn("Not deploying, no GITHUB_TOKEN not found in ENV")
    deploy = false
end

include("generate_examples.jl")

makedocs(;
    modules=[GeoMakie],
    doctest=false,
    format=Documenter.HTML(; prettyurls=deploy, collapselevel=3),
    pages=[
        "GeoMakie.jl" => "index.md",
        "Examples" => "examples.md",
        "Nonlinear transforms" => "nonlinear_transforms.md",
        "Developer documentation" => [
            "Architecture" => "architecture.md"
        ]
        ],
    sitename="GeoMakie.jl",
    authors="Anshul Singhvi and the Makie.jl contributors",
    strict=true)

deploy && deploydocs(; repo="github.com/MakieOrg/GeoMakie.jl", target="build", push_preview=true)
