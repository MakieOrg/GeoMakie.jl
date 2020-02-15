using Documenter, GeoMakie

makedocs(;
    modules=[GeoMakie],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/JuliaPlots/GeoMakie.jl/blob/{commit}{path}#L{line}",
    sitename="GeoMakie.jl",
    authors="Anshul Singhvi",
)

deploydocs(;
    repo="github.com/JuliaPlots/GeoMakie.jl",
    push_preview = true
)
