# Generate examples.md, which holds a lot of the examples
using Base64

example_title_pairs = [
    "Contourf" => "contourf.jl",
    "Axis configuration" => "axis_config.jl",
    "Black Marble" => "blackmarble.jl",
    "Italy's states" => "italy.jl",
    "Projections" => "projections.jl",
    "Orthographic projection" => "orthographic.jl",
    "World Population centers" => "world_population.jl",
    "Field and countries" => "field_and_countries.jl",
    "GraphMakie with GeoMakie" => "graph_on_usa.jl",
]

io = open(joinpath("docs", "src", "examples.md"), "w")

assetpath = mkpath(joinpath("docs", "assets"))

for ext in example_title_pairs

    title   = first(ext)
    example = last(ext)

    filepath = joinpath("examples", example)

    test_image_dir = "test_images"
    base64data = Base64.base64encode(read(joinpath(test_image_dir, splitext(example)[1] * ".png")))
    cp(joinpath(test_image_dir, splitext(example)[1] * ".png"), joinpath(assetpath, splitext(example)[1]*".png"))

    println(io, "## $title")
    println()
    println(io, "```julia")
    println(io, readchomp(filepath))
    println(io, "```\n")
    println(io, "```@raw html")
    println(io, "<img src=\"$(joinpath(assetpath, splitext(example)[1]*".png"))\" alt=\"$title\"></img>") # data:image/png;base64,$(base64data)\
    println(io, "```\n")

end


# Special case for rotating Earth
# since we want a slow video, but
# the generated one would be quite fast.
println(io, "## Rotating Earth")

println(io, "```julia\n$(read(joinpath("examples", "rotating_earth.jl"), String))\n```\n")
println(io,
"""
```@raw html
<video controls autoplay loop>
  <source src="https://user-images.githubusercontent.com/32143268/165003843-db5984f0-9ccf-49f7-847e-88fd63e80bb4.mp4" type="video/mp4">
  Your browser does not support this video.
</video>
```
"""
)
println()

close(io)
