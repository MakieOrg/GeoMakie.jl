```@meta
EditURL = "../../examples/axis_config.jl"
```

How to mess with GeoAxis
!!! warning
    This was written for the old API and doesn't work for the new one!

````@example axis_config
using Makie, CairoMakie, GeoMakie

fig = Figure(size = (500,1000))
````

GeoAxis defaults to DataAspect()
Set source projection and destination projection
source can be overwritten per plot

````@example axis_config
ax1 = GeoAxis(fig[1, 1]; aspect=nothing, source="+proj=latlong", dest="+proj=ortho")
xlims!(ax1, -90, 90) # xlims!, ylims! and limits! are supported
````

But supports any other Makie aspect ratio

````@example axis_config
ax2 = GeoAxis(fig[2, 1]; aspect=AxisAspect(1.3), xgridstyle=:dashdot, xgridcolor = :blue,
              ygridcolor=(:orange, 0.5), ygridwidth=5.0)
````

axis 3 - customizing ticks

````@example axis_config
ax2 = GeoAxis(fig[3, 1]; xticks = -180:2:180)
fig
````

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

