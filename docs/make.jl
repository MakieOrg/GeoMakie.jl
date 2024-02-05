using Documenter, Literate
using GeoMakie, CairoMakie, Makie
# Set some global settings
# Good quality CairoMakie with PNG
CairoMakie.activate!(px_per_unit = 4, type = :png)
# Rasters should download into the artifacts folder (so they can be cached :D)
ENV["RASTERDATASOURCES_PATH"] = joinpath(first(Base.DEPOT_PATH), "artifacts")

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
exclude = Set(["geodesy.jl", "makiecon_examples.jl", "multiple_crs.jl"])
filter!(examples) do file
    isfile(file) && !(basename(file) in exclude) && endswith(file, ".jl")
end
for example in examples
    Literate.markdown(example, joinpath(@__DIR__, "src"); documenter = true)
end

makedocs(;
    modules=[GeoMakie],
    doctest=false,
    format=Documenter.HTML(; prettyurls=deploy, collapselevel=3),
    pages=[
        "GeoMakie.jl" => "index.md",
        "Nonlinear transforms" => "nonlinear_transforms.md",
        "Examples" => [
            "Basic examples" => "basic.md",
            "New API" => "new.md",
            "Orthographic projection" => "orthographic.md",
            "Geostationary satellite image" => "geostationary_image.md",
            "Contourf" => "contourf.md",
            # "Multiple CRS" => "multiple_crs.md",
            "World Population centers" => "world_population.md",
            "Field and countries" => "field_and_countries.md",
            "Mesh image recipe" => "meshimage.md",
            # "Geodetic transformation to the sphere" => "geodesy.md",
            "Axis configuration" => "axis_config.md",
            # "Italy's states" => "italy.md",
            "Most Projections" => "most_projections.md",
            "Projections" => "projections.md",
            # "GraphMakie with GeoMakie" => "graph_on_usa.md",
        ],
        "Developer documentation" => [
            "Architecture" => "architecture.md",
        ]
        ],
    sitename="GeoMakie.jl",
    authors="Anshul Singhvi and the Makie.jl contributors",
)

deploy && deploydocs(; repo="github.com/MakieOrg/GeoMakie.jl", target="build", push_preview=true)
