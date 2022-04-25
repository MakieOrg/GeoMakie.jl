using Documenter, GeoMakie

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
        "Examples" => "examples.md"
        ],
    sitename="GeoMakie.jl",
    authors="Makie.jl contributors")

deploy && deploydocs(; repo="github.com/JuliaPlots/GeoMakie.jl", target="build", push_preview=true)
