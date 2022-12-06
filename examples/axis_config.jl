using Makie, CairoMakie, GeoMakie

fig = Figure(resolution = (1000,1000))

axs = [GeoAxis(fig[i, j]) for i in 1:2, j in 1:2]

# axis 1 - I want an orthographic projection.
axs[1, 1].scene.transformation.transform_func[] = Proj.Transformation("+proj=latlong","+proj=ortho")
xlims!(axs[1, 1], -90, 90)

# axis 2 - wacky spines
axs[1, 2].topspinevisible = false
axs[1, 2].rightspinecolor = :red
axs[1, 2].spinewidth      = 5

# axis 3 - messing with grids
axs[2, 1].xgridcolor = :blue
#axs[2, 1].xgridstyle = :dashdot # bug ! not working now, open independent issue for it
axs[2, 1].ygridcolor = (:orange, 0.5)
axs[2, 1].ygridwidth = 2.0

# axis 4 - customizing ticks
axs[2, 2].xticks = -180:10:180
axs[2, 2].xticklabelsvisible[] = false
hidexdecorations!(axs[2, 2])
fig
