# # Axis configuration

# !!! warning
#     This was written for the old API and doesn't work for the new one!

using Makie, CairoMakie, GeoMakie
CairoMakie.activate!(px_per_unit = 4) # hide

fig = Figure(size = (500,1000))
## GeoAxis defaults to DataAspect()
## Set source projection and destination projection
## source can be overwritten per plot
ax1 = GeoAxis(fig[1, 1]; source="+proj=latlong", dest="+proj=ortho")
lines!(ax1, GeoMakie.coastlines())
xlims!(ax1, -89, 89) # xlims!, ylims! and limits! are supported

# But supports any other Makie aspect ratio
ax2 = GeoAxis(fig[2, 1]; aspect=AxisAspect(1.3), xgridstyle=:dashdot, xgridcolor = :blue,
              ygridcolor=(:orange, 0.5), ygridwidth=5.0)
poly!(ax2, GeoMakie.land())

# axis 3 - customizing ticks
ax3 = GeoAxis(fig[3, 1]; xticks = -180:2:180)
fig
