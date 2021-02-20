using Documenter, GeoMakie

# use the README as the home page
cp(joinpath(dirname(@__DIR__), "README.md"), joinpath(@__DIR__, "src", "index.md"); force = true)

index_obj = readlines(joinpath(@__DIR__, "src", "index.md"))

index_obj[2] = "## Geographic plotting utilities for [Makie.jl](https://www.github.com/JuliaPlots/Makie.jl)"

write(joinpath(@__DIR__, "src", "index.md"), join(index_obj, "\n"))

makedocs(;
    modules=[GeoMakie, AbstractPlotting],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
        "Example" => "example.md",
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
    push_preview = true,
    # deploy_config = Local()
)
