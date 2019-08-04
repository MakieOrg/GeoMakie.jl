using Documenter, GeoMakie

makedocs(;
    modules=[GeoMakie],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/asinghvi17/GeoMakie.jl/blob/{commit}{path}#L{line}",
    sitename="GeoMakie.jl",
    authors="Anshul Singhvi",
    assets=String[],
)

deploydocs(;
    repo="github.com/asinghvi17/GeoMakie.jl",
)
