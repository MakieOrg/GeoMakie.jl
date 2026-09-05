# # GeoAxis configuration
using Makie, CairoMakie, GeoMakie

fig = Figure(size = (500,1000))
## GeoAxis defaults to DataAspect()
## Set source projection and destination projection
## source can be overwritten per plot
ax1 = GeoAxis(fig[1, 1]; source="+proj=latlong", dest="+proj=ortho")
xlims!(ax1, -90, 90) # xlims!, ylims! and limits! are supported

# The frame of the orthographic view is its limb, and the tick labels sit
# outside it where the meridians and parallels leave the disc.  Any other
# Makie aspect ratio is supported too, and the grid takes the usual `Axis`
# grid attributes:
ax2 = GeoAxis(fig[2, 1]; aspect=AxisAspect(1.3), xgridstyle=:dashdot, xgridcolor = :blue,
              ygridcolor=(:orange, 0.5), ygridwidth=5.0)
fig

# axis 3 - customizing ticks.  Any Makie tick finder, a range, a vector or a
# `(values, labels)` tuple works; the default `GeographicTicks()` picks a step
# from the visible extent.  Asking for a meridian every two degrees draws all
# of them, but labels that would overlap are thinned, keeping the rounder
# values (`0°`, `90°W`, ...): see `ticklabelmingap` and `ticklabelreport`.
ax3 = GeoAxis(fig[3, 1]; xticks = -180:2:180)
fig

#=
```@cardmeta
Title = "Axis configuration"
Description = "Messing around with the GeoAxis"
Cover = fig
```
=#
