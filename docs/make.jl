cd(@__DIR__)
using Pkg
CI = get(ENV, "CI", nothing) == "true" || get(ENV, "GITHUB_TOKEN", nothing) !== nothing
Pkg.activate(@__DIR__)
CI && Pkg.instantiate()

using Documenter, GeoMakie

makedocs(;
    modules=[GeoMakie],
    doctest = false,
    format = Documenter.HTML(
        prettyurls = CI, collapselevel = 3,
    ),
    pages=[
        "GeoMakie.jl" => "index.md",
    ],
    sitename="GeoMakie.jl",
    authors = "Makie.jl contributors",
)

if CI
    deploydocs(;
        repo="github.com/JuliaPlots/GeoMakie.jl",
        target = "build",
        push_preview = true,
    )
end