using Documenter, GeoMakie

# use the README as the home page
cp(joinpath(dirname(@__DIR__), "README.md"), joinpath(@__DIR__, "src", "README.md"); force = true)

makedocs(;
    modules=[GeoMakie, AbstractPlotting],
    format=Documenter.HTML(),
    pages=[
        "Home" => "README.md",
        "Recipes" => [
            "geoaxis.md",
            "stock.md"
        ],
        "API Reference" => "api.md"
    ],
    repo="https://github.com/JuliaPlots/GeoMakie.jl/blob/{commit}{path}#L{line}",
    sitename="GeoMakie.jl",
    authors="Anshul Singhvi",
)

deploydocs(;
    repo="github.com/JuliaPlots/GeoMakie.jl",
    push_preview = true
)
