# # GeoAxis configuration
using Makie, CairoMakie, GeoMakie

fig = Figure(size = (500,1000))
## GeoAxis defaults to DataAspect()
## Set source projection and destination projection
## source can be overwritten per plot
ax1 = GeoAxis(fig[1, 1]; source="+proj=latlong", dest="+proj=ortho")
xlims!(ax1, -90, 90) # xlims!, ylims! and limits! are supported

# But supports any other Makie aspect ratio
ax2 = GeoAxis(fig[2, 1]; aspect=AxisAspect(1.3), xgridstyle=:dashdot, xgridcolor = :blue,
              ygridcolor=(:orange, 0.5), ygridwidth=5.0)
fig

# axis 3 - customizing ticks
ax2 = GeoAxis(fig[3, 1]; xticks = -180:2:180)
fig

#
# make cover image #jl
mkpath("covers") #hide
save("covers/$(splitext(basename(@__FILE__))[1]).png", fig) #hide
nothing #hide
