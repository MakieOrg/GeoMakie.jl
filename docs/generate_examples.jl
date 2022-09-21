# Generate examples.md, which holds a lot of the examples

example_title_pairs = [
    "Contourf" => "contourf.jl",
    "Axis configuration" => "axis_config.jl",
    "Italy's states" => "italy.jl",
    "Projections" => "projections.jl",
    "Orthographic projection" => "orthographic.jl",
    "World Population centers" => "world_population.jl",
    "Field and countries" => "field_and_countries.jl",
    "GraphMakie with GeoMakie" => "graph_on_usa.jl",
]

example_path(files...) = abspath(joinpath(@__DIR__, "..", "examples", files...))
doc_src(files...) = abspath(joinpath(@__DIR__, "src", files...))

if !isdir(doc_src("images"))
    mkpath(doc_src("images"))
end

open(doc_src("examples.md"), "w") do io

    for ext in example_title_pairs
        title = first(ext)
        example = last(ext)

        filepath = example_path(example)
        !isfile(filepath) && continue
        println("Including example: $(filepath)")
        name = splitext(example)[1] * ".png"
        img = doc_src("images", name)

        println("    running example!")
        include(filepath)
        CairoMakie.save(img, Makie.current_figure(); px_per_unit=2)

        println(io, "## $title")
        println()
        println(io, "```julia")
        println(io, readchomp(filepath))
        println(io, "```\n")
        println(io, "![$title](images/$name)")
        println(io)
    end


    # Special case for rotating Earth
    # since we want a slow video, but
    # the generated one would be quite fast.
    println(io, "## Rotating Earth")

    println(io, "```julia\n$(read(example_path("rotating_earth.jl"), String))\n```\n")
    println(io,
    """
    ```@raw html
    <video controls autoplay loop>
    <source src="https://user-images.githubusercontent.com/32143268/165003843-db5984f0-9ccf-49f7-847e-88fd63e80bb4.mp4" type="video/mp4">
    Your browser does not support this video.
    </video>
    ```
    """)

    println(io)
end
