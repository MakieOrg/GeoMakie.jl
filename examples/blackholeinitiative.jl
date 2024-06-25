#=
Makie x Black Hole Initiative
=#

# # The structure of a Makie plot
# Figures are basically used to manage layout - all the rendering goes on in the Scene tree.

# Scenes are fundamental building blocks of Makie figures.
# A Scene is like a container for Plots and other Scenes and a Camera. 
# Scenes have Plots and Subscenes associated with them. 
# Every Scene also has a transformation, made up of scale, translation, and rotation, as well as a
# "black-box" nonlinear transform function.

# Plots are basically descriptions of how to render some input.  They have child plots, which are basically
# decompositions of this data, until they are decomposed to an "atomic" form - a set of some basic plot types
# which the backend knows how to render.

# All of these things are connected by Observables - basically, "boxes" that can hold a value.
# Observables have the property that they can signal "observer functions" whenever their value
# changes.  This allows us to eagerly integrate changes at an incremental level.

using Makie
using FileIO
using CairoMakie # backend

fig, ax, plt = lines(rand(Point2f, 10))

# The way the Makie pipeline works now, is that dimensions are first 
args = Makie.expand_dimensions(Makie.PointBased(), rand(10)) 
args = Makie.expand_dimensions(Makie.PointBased(), rand(Point2f, 10)) 
# check if we should extract dims.
Makie.convert_arguments(Makie.PointBased(), args...)

plt.converted[1]

plt.color[] = :red

plt.args#[1][] = randn(100)

ax.blockscene.plots[2].color[] = :blue#RGBAf(1, 0, 0, 1)


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

cow_img = load(Makie.assetpath("cow.png"))

using CoordinateTransformations
SPHERICAL_TRANSFORM_FUNC = Makie.PointTrans{3}() do point
    θ, ϕ, r = point # we interpret this way so that e.g. surface works correctly.
    CoordinateTransformations.CartesianFromSpherical()(Spherical(r + 1, θ, ϕ))
end

f, a, p = lines(rand(Point3f, 100))
p.transformation.transform_func[] = SPHERICAL_TRANSFORM_FUNC
f

using GeoMakie
f, a, p = meshimage(-π/2..π/2, -π..π, cow_img; axis = (; type = LScene,))
p.transformation.transform_func[] = SPHERICAL_TRANSFORM_FUNC
f

p.plots[1].color[] = cow_img

cameracontrols(a.scene)
f

Makie.apply_transform(SPHERICAL_TRANSFORM_FUNC, Point3f(1, 1, 0))


# You can also plot directly on a spherical mesh:

mesh(
    Sphere(Point3f(0), 1),
    color =
)