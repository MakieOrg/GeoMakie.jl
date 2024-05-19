using Documenter, DocumenterVitepress, Literate
using GeoMakie, CairoMakie, Makie, GeoInterfaceMakie

include("gallery_setup.jl")
# Set some global settings
# Good quality CairoMakie with PNG
CairoMakie.activate!(px_per_unit = 3, type = :png)
# Rasters should download into the artifacts folder (so they can be cached :D)
ENV["RASTERDATASOURCES_PATH"] = joinpath(first(Base.DEPOT_PATH), "artifacts")
# invoke some geomakie things to be sure it works
GeoMakie.coastlines()
GeoMakie.earth()

deploy = length(ARGS) == 1 && ARGS[1] == "deploy"
if deploy && !haskey(ENV, "GITHUB_TOKEN")
    @warn("Not deploying, no GITHUB_TOKEN not found in ENV")
    deploy = false
end

using Literate

examples = [
    "basic.jl",
    "new.jl",
    "axis_config.jl",
    "italy.jl",
    "graph_on_usa.jl",
    "orthographic.jl",
    "german_lakes.jl",
    "geostationary_image.jl",
    "contourf.jl",
    "world_population.jl",
    "field_and_countries.jl",
    "meshimage.jl",
    "projections.jl",
    "tissot.jl",
    # "rotating_earth.jl",
    # joinpath("gmt", "antioquia.jl"),
]
example_dir = joinpath(dirname(@__DIR__), "examples")
for file in joinpath.((example_dir,), examples)
    endswith(file, ".jl") || continue
    Literate.markdown(file, joinpath(@__DIR__, "src", "examples"); documenter = true)
end

Documenter.makedocs(;
    modules=[GeoMakie],
    doctest=false,
    format=DocumenterVitepress.MarkdownVitepress(; 
        repo = "https://github.com/MakieOrg/GeoMakie.jl", 
        deploy_url = "https://geo.makie.org",
        devbranch = "master",
        devurl = "dev",
        build_vitepress = false,
    ),
    pages=[
        "Introduction" => "introduction.md",
        "Data" => "data.md",
        "Examples" => "examples.md",
        "Developer documentation" => [
            "Nonlinear transforms" => "nonlinear_transforms.md",
            "Architecture" => "architecture.md",
            "Adding demos" => "adding_demos.md",
            "hide" => [
            "hide" => ["hide" => ["hide" => joinpath.(("examples",), replace.(examples, (".jl" => ".md",)))]]
            ],
        ],
        ],
    sitename="GeoMakie.jl",
    authors="Anshul Singhvi and the Makie.jl contributors",
    warnonly = true,
)

publicpath = joinpath(@__DIR__, "build", ".documenter", "public")
mkpath(publicpath)
mv(joinpath(@__DIR__, "build", ".documenter", "examples", "covers"), joinpath(publicpath, "covers"))

DocumenterVitepress.build_docs(joinpath(@__DIR__, "build"))

rm(joinpath(@__DIR__, "build", ".documenter"); recursive = true, force = true)
contents = readdir(joinpath(@__DIR__, "build", "final_site"))
for item in contents
    src = joinpath(joinpath(@__DIR__, "build"), "final_site", item)
    dst = joinpath(joinpath(@__DIR__, "build"), item)
    cp(src, dst)
end
rm(joinpath(@__DIR__, "build", "final_site"); recursive = true)


# isdir(joinpath(@__DIR__, "src", "examples")) && rm.(readdir(joinpath(@__DIR__, "src", "examples"); join = true); force = true)

deploy && deploydocs(; repo="github.com/MakieOrg/GeoMakie.jl", target="build", push_preview=true, forcepush = true)


        # "Examples" => [
        #     "Basic examples" => "examples/basic.md",
        #     "New API" => "examples/new.md",
        #     "Orthographic projection" => "examples/orthographic.md",
        #     "German Lakes" => "examples/german_lakes.md",
        #     "Geostationary satellite image" => "examples/geostationary_image.md",
        #     "Contourf" => "examples/contourf.md",
        #     # "Multiple CRS" => "examples/multiple_crs.md",
        #     "World Population centers" => "examples/world_population.md",
        #     "Field and countries" => "examples/field_and_countries.md",
        #     "Mesh image recipe" => "examples/meshimage.md",
        #     # "Geodetic transformation to the sphere" => "examples/geodesy.md",
        #     "Axis configuration" => "examples/axis_config.md",
        #     # "Italy's states" => "examples/italy.md",
        #     # "Most Projections" => "examples/most_projections.md",
        #     "Projections" => "examples/projections.md",
        #     # "GraphMakie with GeoMakie" => "examples/graph_on_usa.md",
        # ],

    
# # use Literate for examples
# examples = readdir(example_dir; join = true)
# exclude = Set(["geodesy.jl", "makiecon_examples.jl", "multiple_crs.jl"])
# filter!(examples) do file
#     isfile(file) && !(basename(file) in exclude) && endswith(file, ".jl")
# end


# for example in examples
#     Literate.markdown(example, joinpath(@__DIR__, "src", "examples"); documenter = true)
# end

# documenter_example_paths = joinpath.(
#     ("examples"), 
#     first.(splitext.(last.(splitdir.(examples)))) .* (".md",)
# )