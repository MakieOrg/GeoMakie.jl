# Generate examples.md, which holds a lot of the examples

example_title_pairs = [
    "Black Marble" => "blackmarble.jl",
    "Italy's states" => "italy.jl",
    "Projections" => "projections.jl",
    "Orthographic projection" => "orthographic_proj.jl",
    "World Population centers" => "world_population.jl",

]

io = open(joinpath("src", "examples.md"), "w")

for example, title in example_title_pairs

    println(io, "## $title")

    println(io, "```@example MAIN")
    println(io, readchomp(joinpath("examples", example)))
    println(io, "```")
    print(io, "\n\n\n")

end
