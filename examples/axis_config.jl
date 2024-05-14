# # GeoAxis configuration

# In this example, we show how to configure a GeoAxis.
using Makie, CairoMakie, GeoMakie
CairoMakie.activate!(px_per_unit = 4) # hide

fig = Figure(size = (500,1000))
## GeoAxis defaults to DataAspect()
## Set source projection and destination projection
## source can be overwritten per plot
ax1 = GeoAxis(fig[1, 1]; dest="+proj=ortho")
lines!(ax1, GeoMakie.coastlines())
xlims!(ax1, -89, 89) # xlims!, ylims! and limits! are supported
fig

# But supports any other Makie aspect ratio
ax2 = GeoAxis(fig[2, 1]; aspect=AxisAspect(1.3), xgridstyle=:dashdot, xgridcolor = :blue,
              ygridcolor=(:orange, 0.5), ygridwidth=5.0)
poly!(ax2, GeoMakie.land())
fig
# Notice how the axis above appears squashed - that's because we meddled with the axis!
# In general, you don't want to do this, but the example shows how it can be done if you 
# need this kind of thing.

# You can also customize ticks:
ax3 = GeoAxis(fig[3, 1]; xticks = -180:2:180, limits = (-180, 180, -90, 90))
fig
# Note that the x-ticks are smart enough to not render if they will 
# intersect.  You can't yet turn this off, but that will come in a 
# future version.

# You can also set any attribute post construction, since they're all
# Makie attributes.  This is the same as any Makie Block like `Axis`.
ax3.xticks = -180:30:180
fig