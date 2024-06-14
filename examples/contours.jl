# # Contours

using Makie, GeoMakie, CairoMakie

lons = -180:180
lats = -90:90
# Create some field of values across `lons` and `lats`.
#
# This grid can be of any density, but note that the
# time it takes to plot scales with the grid size!
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]
# Makie provides two main recipes for contours = `contour` for lines, and `contourf` for fills.  
# In this example, we'll see examples of both.
fig = Figure(size = (1000, 750), Contour = (; labelsize = 14, labelfont = :bold), Text = (; strokecolor = :gray, strokewidth = .3))
ax1 = GeoAxis(fig[1,1]; title = "Plain contour")
contour!(ax1, lons, lats, field)
fig
# Makie also offers filled contours via the `contourf` recipe:
ax2 = GeoAxis(fig[1,2]; title = "Filled contour")
contourf!(ax2, lons, lats, field)
fig
# The `contour` recipe also offers labels, which we can activate via keyword:
ax3 = GeoAxis(fig[2,1]; title = "Contour with labels")
contour!(ax3, lons, lats, field; labels = true)
fig
# Finally, we can get a filled contour plot with labels by connecting the two:
ax4 = GeoAxis(fig[2,2]; title = "Filled contour with labels")
cfp = contourf!(ax4, lons, lats, field)
clp = contour!(
    ax4, lons, lats, field; 
    color = :black, labels = true, 
    levels = cfp._computed_levels
)
fig
# In order to control the levels, we need only set the levels for the first filled contour plot:
cfp.levels[] = -2:5
fig

#=
```@cardmeta
Title = "Contours"
Description = "Contour plots with fills and labels"
Cover = fig
```
=#