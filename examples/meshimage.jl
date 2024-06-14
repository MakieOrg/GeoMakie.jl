# # The `meshimage` recipe

# GeoMakie presents a `meshimage` recipe to render images in
# projected spaces, without having to reproject.  

# You can generally think of these as discretized versions of the 
# true continuous reprojection.

# `meshimage` works best with the GL-backends (GLMakie/WGLMakie) 
# because they have the best inbuilt support for meshes.  CairoMakie
# also supports `meshimage`, but the quality of the image will be worse
# unless your mesh is very fine (`npoints > 1000` usually).

#=
```julia
using GeoMakie, GLMakie
```
=#
using GeoMakie, CairoMakie # hide
Makie.set_theme(Attributes(; MeshImage = (; npoints = 300,))) # hide
# ## Affine transform (no nonlinearity)
fig = Figure()
ax1 = Axis(fig[1, 1])
mi = meshimage!(ax1, (Makie.logo()))
fig
# `save("simple_scaling.png", fig)`
# ## Nonlinear but separable (log scaling)
fig = Figure()
ax1 = Axis(fig[1, 1]; xscale = log, yscale = log10)
lg = (Makie.logo())
mi = meshimage!(ax1, 1 .. size(lg, 1), 1 .. size(lg, 2), lg)
fig
# `save("log_scaling.png", fig)`
# ## Nonlinear and non-separable (geographic transformation)
fig = Figure()
ax1 = GeoAxis(fig[1, 1]; dest = "+proj=igh")
mi = meshimage!(ax1, -169..169, -90..90, (Makie.logo()); npoints = 400)
fig
# This is peak graphic art right here!
# `save("geo_scaling.png", fig)`
# ## Logo!
# Finally, we create a kludged together GeoMakie logo
# with the Earth in the background, and the Makie logo at the fore!
fig = Figure()
ax1 = GeoAxis(fig[1, 1]; dest = "+proj=igh")
s1 = surface!(ax1, (-180f0)..(180f0), -90f0..90f0, zeros(size(GeoMakie.earth() |> rotr90)); shading = NoShading, color = GeoMakie.earth() |> rotr90)
fig
#

# m1 = meshimage!(ax1, -100..100, -40..40, (Makie.logo()); npoints = 300)
m1 = meshimage!(ax1, -166..169, -90..90, (Makie.logo()); npoints = 400)
hidedecorations!(ax1)
fig


#=
```@cardmeta
Description = "The meshimage recipe"
Cover = fig
```
=#