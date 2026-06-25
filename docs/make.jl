using Documenter, DocumenterVitepress, Literate, OhMyCards
using GeoMakie, CairoMakie, Makie

import GLMakie, CairoMakie

# some strategic imports to avoid world age issues
using FHist

# Pre-load Oceananigans (used by the `tripolar` example) up front, swallowing a benign
# init-time warning: TaylorSeries (pulled in via CubedSphere) carries a stale `Requires`
# hook whose IntervalArithmetic integration references `IntervalBox`, removed in recent
# IntervalArithmetic. Loading it here under a `NullLogger` keeps that warning out of the
# rendered `@example` output; the example's own `using Oceananigans` is then a no-op.
using Logging
Logging.with_logger(Logging.NullLogger()) do
    @eval import Oceananigans
end

# Set some global settings
# Good quality CairoMakie with PNG
CairoMakie.activate!(px_per_unit = 2, type = :png)

# DocumenterVitepress picks the highest-`mime_priority` MIME a figure is showable in, and
# its default table ranks JPEG (6) above PNG (4) and SVG (3). Every GLMakie (raster) figure
# advertises JPEG, so any page rendered while GLMakie is the active backend gets saved as
# lossy, blurry JPEG. Demote JPEG below SVG/PNG so figures render as crisp SVG (CairoMakie
# vector pages) or lossless PNG (GLMakie pages) instead. (Method override on a build-time
# helper, intentional, scoped to this docs build.)
DocumenterVitepress.mime_priority(::MIME"image/jpeg") = 2.5
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
GeoMakie.coastlines();
GeoMakie.earth();

using Literate

# Regenerate the projection gallery page (docs/src/projections.md) from its data-driven source of
# truth, so every panel shows a self-contained, copy-pasteable code cell. Edit
# docs/generate_projections.jl, never the generated markdown.
include(joinpath(@__DIR__, "generate_projections.jl"))
generate_projections(joinpath(@__DIR__, "src", "projections.md"))

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
    "polar_stereo.jl",
    "geostationary_image.jl",
    # "multiple_crs.jl",
    "rasters.jl",
    # "raster_warping_masking.jl", # this one fails due to Rasters.boolmask error
    "healpix.jl",
    "is_it_a_plane.jl",
    joinpath("cartopy", "annotation.jl"),
    joinpath("cartopy", "katrina.jl"),
    joinpath("cartopy", "arrows.jl"),
    joinpath("cartopy", "vesta.jl"),
    joinpath("cartopy", "vesta3d.jl"),
    joinpath("cartopy", "streamplot.jl"),
    joinpath("gmt", "antioquia.jl"),
    "german_lakes.jl",
    "field_and_countries.jl",
    "tripolar.jl",
    "meshimage.jl",
    # "projections.jl",
    "tissot.jl",
    "rotating_earth.jl",
    "sticker.jl",
    "piracy_at_sea.jl",
    "geoid.jl",
    joinpath("specialized", "satellite", "dashboard.jl"),
    joinpath("specialized", "satellite", "sweep_points.jl"),
]
example_dir = joinpath(dirname(@__DIR__), "examples")
mkpath(example_dir)
for filename in examples
    file = joinpath(example_dir, filename)
    endswith(file, ".jl") || continue
    Literate.markdown(file, joinpath(@__DIR__, "src", "examples", first(splitdir(filename))); documenter = true)
end

doc = Documenter.makedocs(;
    modules=[GeoMakie],
    format=DocumenterVitepress.MarkdownVitepress(; 
        repo = "https://github.com/MakieOrg/GeoMakie.jl", 
        deploy_url = "https://geo.makie.org",
        devbranch = "master",
        devurl = "dev",
        keep = :patch,
    ),
    pages=[
        "Introduction" => "introduction.md",
        "Gallery" => "examples.md",
        "Projections" => "projections.md",
        "Data" => "data.md",
        "Developer documentation" => [
            "Nonlinear transforms" => "nonlinear_transforms.md",
            "Architecture" => "architecture.md",
            "Adding demos" => "adding_demos.md",
        ],
        "API reference" => "api.md",
        "Examples" => joinpath.(("examples",), replace.(examples, (".jl" => ".md",))),
    ],
    sitename="GeoMakie.jl",
    authors="Anshul Singhvi and the Makie.jl contributors",
    doctest=false,
    warnonly = true,
    # DRAFT=true skips @example/@repl/@setup/@eval evaluation → fast markdown-only build (no code
    # cells run), for iterating on page structure/prose. Default (DRAFT unset) runs everything.
    draft = get(ENV, "DRAFT", "false") == "true",
    plugins = [OhMyCards.ExampleConfig(; dot_slash = true),],
    pagesonly = !(get(ENV, "CI", "false") == "true"),
    debug = true,
);

DocumenterVitepress.deploydocs(; 
    repo="github.com/MakieOrg/GeoMakie.jl", 
    target="build", 
    push_preview = true, 
    forcepush = true
)

if length(doc.internal.errors) > 0
    error("Errors found in documentation build: $(join(doc.internal.errors, "\n"))")
end
