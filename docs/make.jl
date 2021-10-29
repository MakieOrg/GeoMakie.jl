cd(@__DIR__)
using Pkg
CI = get(ENV, "CI", nothing) == "true" || get(ENV, "GITHUB_TOKEN", nothing) !== nothing
CI && Pkg.activate(@__DIR__)
CI && Pkg.instantiate()

using Documenter, GeoMakie

makedocs(;
    modules=[GeoMakie],
    doctest = false,
    format = Documenter.HTML(
        prettyurls = CI,
        assets = [
            "assets/logo.ico",
            asset("https://fonts.googleapis.com/css?family=Quicksand|Montserrat|Source+Code+Pro|Lora&display=swap", class=:css),
            ],
        ),
    pages=[
        "Home" => "index.md",
        "Example" => "example.md",
        "Recipes" => [
            "stock.md"
        ],
        "API Reference" => "api.md"
    ],
    sitename="GeoMakie.jl",
    authors="Anshul Singhvi",
)

deploydocs(;
    repo="github.com/JuliaPlots/GeoMakie.jl",
    push_preview = true,
)
