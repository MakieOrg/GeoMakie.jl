# Adding demos

To add a demo / example, you can add a Julia file to the folder in `examples` which best fits its purpose.  You must also add the name of the file to the overview gallery blocks in `docs/src/examples.md`, and the whitelist array in `docs/src/make.jl`.  

[This PR](https://github.com/MakieOrg/GeoMakie.jl/pull/246) is an example of how to do this.

## File structure

GeoMakie uses [Literate.jl](https://github.com/fredrikekre/Literate.jl) to generate the examples, so the files must conform to its syntax.

Functional requirements are:
- A title as a level-1 heading at the top of the page.
- Declaring metadata at the bottom of the page via a `@cardmeta` block.
- At each stage, return a `FigureLike`.


When adding the code to save to `covers`, you must add the following code to your Julia file:
````julia
#=
```@cardmeta
Cover = fig
Description = "A very short description of the example"
Title = "Some title, optional"
```
=#
````
assuming `fig` is the main figure of that example.

Note that all of this code is commented out - this is important, otherwise Documenter.jl will not be able to pick it up.

You can even pass a compound expression as `Cover = begin ... end` if you want to create a custom cover figure.  This will all be evaluated in the same scope as your example, but **after all the code is executed**.

We also require that the comments in the file be of sufficient quantity and quality to explain what is going on to a newcomer.

## What is actually going on 

In GeoMakie, we've created two custom Documenter blocks - `@cardmeta` and `@overviewgallery`.  The `@cardmeta` block adds metadata (cover image, title, description, etc) to a global dict.

The `@overviewgallery` block retrieves this metadata and renders a grid of example cards in HTML, styled by the styles in `styles.css`.  

There are two stages to the cardmeta pipeline.  First, we go through the document via a Documenter.jl build stage which is inserted after doctest, but before expand pipelines. This build stage parses each file for cardmeta, and if it is encountered, moves it to the absolute bottom of the file.  This means that when `ExpandTemplates` begins, it is guaranteed to execute cardmeta at the very end of the file.