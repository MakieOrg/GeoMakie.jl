using Makie, CairoMakie, GeoMakie

fig = Figure(resolution = (1000,1000))

axes = [GeoAxis(fig[i, j]) for i in 1:2, j in 1:2]

# axis 1 - I want an orthographic projection.
axes[1, 1].scene.transformation.transform_func[] = Proj.Transformation("+proj=latlong","+proj=ortho")
xlims!(axes[1, 1], -90, 90)

# axis 2 - wacky spines
axes[1, 2].topspinevisible = false
axes[1, 2].rightspinecolor = :red
axes[1, 2].spinewidth      = 5

# axis 3 - messing with grids
axes[2, 1].xgridcolor = :blue
axes[2, 1].xgridstyle = :dashdot
axes[2, 1].ygridcolor = (:orange, 0.5)
axes[2, 1].ygridwidth = 2.0

# axis 4 - customizing ticks
axes[2, 2].xticks = LinearTicks(20)
axes[2, 2].xticklabelsvisible[] = false
hidexdecorations!(axes[2, 2])
fig
