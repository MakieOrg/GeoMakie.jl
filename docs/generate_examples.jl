# Generate examples.md, which holds a lot of the examples

example_title_pairs = [
    "Contourf" => "contourf.jl",
    "Axis configuration" => "axis_config.jl",
    "Black Marble" => "blackmarble.jl",
    "Italy's states" => "italy.jl",
    "Projections" => "projections.jl",
    "Orthographic projection" => "orthographic.jl",
    "World Population centers" => "world_population.jl",
    "Field and countries" => "field_and_countries.jl",

]

io = open(joinpath("src", "examples.md"), "w")

for ext in example_title_pairs

    title   = first(ext)
    example = last(ext)

    println(io, "## $title")

    println(io, "```@example MAIN")
    println(io, readchomp(joinpath("..", "examples", example)))
    println(io, "```")
    print(io, "\n\n\n")

end

close(io)
