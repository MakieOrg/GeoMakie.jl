```@meta
EditURL = "../../examples/contourf.jl"
```

````@example contourf
using Makie, GeoMakie, CairoMakie

lons = -180:180
lats = -90:90
````

Create some field of values across `lons` and `lats`
This grid can be of any density, but note that the
time it takes to plot scales with the grid size!

````@example contourf
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]
````

Surface example

````@example contourf
fig = Figure()
ax = GeoAxis(fig[1,1])
contourf!(ax, lons, lats, field; shading = NoShading)
fig
````

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

