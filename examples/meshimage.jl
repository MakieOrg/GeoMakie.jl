using GeoMakie, GLMakie
GLMakie.activate!(px_per_unit = 4)

# Note that CairoMakie not have great mesh UV support.
# [W]GLMakie meshes have better UV support and will result in a sharper
# image.

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
mi = meshimage!(ax1, -180..180, -90..90, (Makie.logo()))
fig
# This is peak graphic art right here!
# `save("geo_scaling.png", fig)`
