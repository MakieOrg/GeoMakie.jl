# # Frame styles
#
# A `GeoAxis` draws its frame on whatever shape the projection gives it: the
# limb of an orthographic view, the rectangle of a Mercator region, the ellipse
# of Equal Earth.  `framestyle = :plain` (the default) strokes that curve once;
# `framestyle = :fancy` adds a band outside it, `framewidth` pixels wide,
# alternating between the two `framecolors` at every tick, in the manner of
# GMT and cartopy's fancy frames.

using GeoMakie, CairoMakie

fig = Figure(size = (900, 700))
for (col, style) in enumerate((:plain, :fancy))
    ax1 = GeoAxis(fig[1, col]; dest = "+proj=ortho +lon_0=-20 +lat_0=30",
        framestyle = style, title = "framestyle = :$style")
    lines!(ax1, GeoMakie.coastlines())
    ax2 = GeoAxis(fig[2, col]; dest = "+proj=merc", limits = ((-20, 40), (30, 70)),
        framestyle = style)
    lines!(ax2, GeoMakie.coastlines())
end
fig

# The band follows the ticks, so a different tick step or `framecolors` changes
# it; `framewidth` sets how far it reaches outside the frame, and the tick
# labels move out with it.

fig = Figure(size = (600, 450))
ax = GeoAxis(fig[1, 1]; dest = "+proj=merc", limits = ((-20, 40), (30, 70)),
    framestyle = :fancy, framewidth = 10, framecolors = (:navy, :white),
    xticks = -20:10:40, yticks = 30:10:70, spinecolor = :navy,
    xminorticksvisible = true, yminorticksvisible = true, title = "A navy band")
lines!(ax, GeoMakie.coastlines())
fig

# `hidespines!(ax)` hides the spine and the band together, since a map's frame
# is one closed curve rather than four sides.

#=
```@cardmeta
Title = "Frame styles"
Description = "Plain and fancy frames on curved and rectangular maps"
Cover = fig
```
=#
