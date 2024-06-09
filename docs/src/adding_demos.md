# Adding demos

To add a demo / example, you can add a Julia file to the folder in `examples` which best fits its purpose.

## File structure

GeoMakie uses [Literate.jl](https://github.com/fredrikekre/Literate.jl) to generate the examples, so the files must conform to its syntax.

Functional requirements are:
- A title as a level-1 heading
- Saving the cover image in the `covers` folder - each example has such code.
- At each stage, return a `FigureLike`.  You can simply dispose of things for it to work...


When adding the code to save to `covers`, you must add the following code to the bottom of your Julia file:
````julia
# ```@cardmeta
# Cover = fig
# Description = "A very short description of the example"
# Title = "Some title, optional"
# ```
````
assuming `fig` is the main figure of that example.

Note that all of this code is commented out - this is important, otherwise Documenter.jl will not be able to pick it up.

You can even pass a compound expression as `Cover = begin ... end` if you want to create a custom cover figure.  This will all be evaluated in the same scope as your example, but after all the code is executed.

We also require that the comments in the file be of sufficient quantity and quality to explain what is going on to a newcomer.