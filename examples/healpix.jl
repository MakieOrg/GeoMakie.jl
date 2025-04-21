#=
# Healpix.jl 

[Healpix.jl](https://github.com/ziotom78/Healpix.jl) is an equal-area "pixelization" of the 2-sphere.  Here, we show how to plot a Healpix.jl pixelization via GeoMakie.

This is currently a manual process, but we hope to add recipes soon!

=#

# Construct a synthetic Healpix map

using CairoMakie, GeoMakie

using Healpix
nside = 8
m = HealpixMap{Float64, RingOrder}(nside)
m.pixels[:] = 1:length(m.pixels)
m
#
img, _, _ = Healpix.equirectangular(m)
heatmap(img)
# Now we can plot it on a GeoAxis with a Mollweide projection:
meshimage(-180..180, -90..90, reverse(img; dims = 1); npoints = 200, axis = (; type = GeoAxis, dest = "+proj=moll"))
# Finally, we can also try to obtain the image as a Mollweide projected image via Healpix, and then plot it directly.
# For more information on what we're doing here, see the Multiple CRS example.
img, _, _ = Healpix.mollweide(m)
heatmap(img)
# 
fig = Figure()
ax = GeoAxis(fig[1, 1]; dest = "+proj=moll")
hp_bbox = Makie.apply_transform(ax.transform_func[], Makie.BBox(-180, 180, -90, 90)) 
# The rectangle above is the bounding box of the full Earth (or sky, in this case) in the Mollweide projection.
mini = minimum(hp_bbox)
maxi = maximum(hp_bbox)
meshimage!(ax, mini[1]..maxi[1], mini[2]..maxi[2], reverse(img; dims = 1); npoints = 200, source = "+proj=moll")
lines!(ax, GeoMakie.coastlines(); color = :black, xautolimits = false, yautolimits = false)
fig
# Note how the meshimage looks a bit pixelated there - that is because of the mollweide projection!

#=
```@cardmeta
Description = "Spherical pixelizations from Healpix.jl"
Cover=fig
```
=#
