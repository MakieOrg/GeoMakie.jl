#=
Makie x Black Hole Initiative
=#

# # The structure of a Makie plot
# Figures are basically used to manage layout - all the rendering goes on in the Scene tree.

# Scenes are fundamental building blocks of Makie figures.
# A Scene is like a container for Plots and other Scenes. 
# Scenes have Plots and Subscenes associated with them. 
# Every Scene also has a transformation, made up of scale, translation, and rotation, as well as a
# "black-box" nonlinear transform function.

# Plots are basically descriptions of how to render some input.  They have child plots, which are basically
# decompositions of this data, until they are decomposed to an "atomic" form - a set of some basic plot types
# which the backend knows how to render.

# All of these things are connected by Observables - basically, "boxes" that can hold a value.
# Observables have the property that they can signal "observer functions" whenever their value
# changes.  This allows us to eagerly integrate changes at an incremental level.

fig, ax, plt = lines(rand(10))

fig.scene

fig.layout

ax.blockscene

ax.scene

# To investigate this in more detail, we can extract the Scene graph as a graph,
# and plot it using GraphMakie.  


# See the GraphMakie scene graph example (PR ) for more.

# # Plotting on the sphere

# We can use a transformation function to treat input values as spherical coordinates,
# and transform to Cartesian space which will be visualized.

SPHERICAL_TRANSFORM_FUNC = Makie.PointTrans{3}() do point
    ϕ, θ, r = point # we interpret this way so that e.g. surface works correctly.
    return Point3(
        (r + 1) * cos(ϕ) * sin(θ),
        (r + 1) * sin(ϕ) * sin(θ),
        (r + 1) * cos(θ)
    )
end

f, a, p = meshimage(-π..π, -π..π, rand(10, 10) ./ 10; axis = (; type = LScene,));
p.transformation.transform_func[] = SPHERICAL_TRANSFORM_FUNC
a.scene

f