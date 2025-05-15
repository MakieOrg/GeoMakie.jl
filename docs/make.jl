using Documenter, DocumenterVitepress, Literate, OhMyCards
using GeoMakie, CairoMakie, Makie, GeoInterfaceMakie

# some strategic imports to avoid world age issues
using FHist

# Set some global settings
# Good quality CairoMakie with PNG
CairoMakie.activate!(px_per_unit = 2, type = :png)
# Rasters should download into the artifacts folder (so they can be cached :D)
raster_data_sources_path = joinpath(first(Base.DEPOT_PATH), "artifacts")
if haskey(ENV, "CI")
    # override the given setting so we don't run into path not created problems.
    ENV["RASTERDATASOURCES_PATH"] = raster_data_sources_path
else
    # on local machine, so respect the given setting if it exists.
    get!(ENV, "RASTERDATASOURCES_PATH", raster_data_sources_path)
end
# invoke some geomakie things to be sure it works
GeoMakie.coastlines()
GeoMakie.earth()

using Literate

examples = String[
    "basic.jl",
    # "new.jl",
    "axis_config.jl",
    "italy.jl",
    "histogram.jl",
    "contours.jl",
    "world_population.jl",
    "graph_on_usa.jl",
    "orthographic.jl",
    # "geostationary_image.jl",
    # "multiple_crs.jl",
    "rasters.jl",
    # "raster_warping_masking.jl", # this one fails due to Rasters.boolmask error
    "healpix.jl",
    # "is_it_a_plane.jl",
    joinpath("cartopy", "annotation.jl"),
    joinpath("cartopy", "katrina.jl"),
    joinpath("cartopy", "arrows.jl"),
    # # joinpath("cartopy", "vesta.jl"),
    joinpath("cartopy", "streamplot.jl"),
    joinpath("gmt", "antioquia.jl"),
    "german_lakes.jl",
    "field_and_countries.jl",
    "meshimage.jl",
    # "projections.jl",
    "tissot.jl",
    # "rotating_earth.jl",
]
example_dir = joinpath(dirname(@__DIR__), "examples")
mkpath(example_dir)
for filename in examples
    file = joinpath(example_dir, filename)
    endswith(file, ".jl") || continue
    Literate.markdown(file, joinpath(@__DIR__, "src", "examples", first(splitdir(filename))); documenter = true)
end

Documenter.makedocs(;
    modules=[GeoMakie],
    doctest=false,
    format=DocumenterVitepress.MarkdownVitepress(; 
        repo = "https://github.com/MakieOrg/GeoMakie.jl", 
        deploy_url = "https://geo.makie.org",
        devbranch = "master",
        devurl = "dev",
    ),
    pages=[
        "Introduction" => "introduction.md",
        "Gallery" => "examples.md",
        "Data" => "data.md",
        "Developer documentation" => [
            "Nonlinear transforms" => "nonlinear_transforms.md",
            "Architecture" => "architecture.md",
            "Adding demos" => "adding_demos.md",
        ],
        "Examples" => joinpath.(("examples",), replace.(examples, (".jl" => ".md",))),
    ],
    sitename="GeoMakie.jl",
    authors="Anshul Singhvi and the Makie.jl contributors",
    warnonly = true,
    draft = false,
    plugins = [OhMyCards.ExampleConfig(),],
)

DocumenterVitepress.deploydocs(; 
    repo="github.com/MakieOrg/GeoMakie.jl", 
    target="build", 
    push_preview = true, 
    forcepush = true
)
