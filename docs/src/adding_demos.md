# Adding demos

To add a demo / example, you can add a Julia file to the folder in `examples` which best fits its purpose.

## File structure

GeoMakie uses [Literate.jl](https://github.com/fredrikekre/Literate.jl) to generate the examples, so the files must conform to its syntax.

Functional requirements are:
- A title as a level-1 heading
- Saving the cover image in the `covers` folder - each example has such code.
- At each stage, return a `FigureLike`.  You can simply dispose of things for it to work...


When adding the code to save to `covers`, you must add the following exactly:
```julia
#
# make cover image #jl
mkpath("covers") #hide
save("covers/$(splitext(basename(@__FILE__))[1]).png", fig) #hide
nothing #hide
```
assuming `fig` is the main figure of that example.

The first comment is important, so that there is a separation between the code block above this one, and this one.  Otherwise, the last figure will not be displayed!

We also require that the comments in the file be of sufficient quantity and quality to explain what is going on to a newcomer.