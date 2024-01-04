# using GLMakie

using GeoMakie
using GLMakie
GLMakie.activate!()
fig = Figure(size = (600,600))
ax = GeoAxis(fig[1, 1]; source="+proj=latlong", dest="+proj=natearth")
lines!(ax, GeoMakie.coastlines())

# ax2 = GeoAxis(fig[1, 2]; aspect=nothing, source="+proj=latlong", dest="+proj=natearth")
# lines!(ax2, GeoMakie.coastlines())
# xlims!(ax, -20, 20)
fig
