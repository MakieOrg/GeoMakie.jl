using Documenter, GeoMakie

# use the README as the home page
readme = read(joinpath(dirname(@__DIR__), "README.md"), String)
# HTML not supported in the Markdown parser used by Documenter
href = """<a href = "https://www.github.com/JuliaPlots/Makie.jl"><img src="https://raw.githubusercontent.com/JuliaPlots/Makie.jl/master/assets/logo.png" alt="Makie.jl" height="30" align = "top"></a>"""
homepage = replace(readme, href => "Makie.jl")
write(joinpath(@__DIR__, "src", "index.md"), homepage)

makedocs(;
    modules=[GeoMakie],
    format=Documenter.HTML(),
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
