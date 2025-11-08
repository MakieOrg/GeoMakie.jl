#=
```@cardmeta
Title = "Making a sticker"
Cover = fig
Description = "GeoMakie logo cropped by a polygon"
```

We make a sticker by finding the cropping polygon of the interrupted Goode homolosine.
=#

using GeoMakie, CairoMakie
import GeoInterface as GI, GeometryOps as GO, GeoFormatTypes as GFT

# Obtain boundary points
n = 31
minlon = -180
maxlon = 180
epsilon = 1e-10
central_longitude = 0
top_interrupted_lons = (-40.0,)
bottom_interrupted_lons = (80.0, -20.0, -100.0)
## if emphasis == "ocean":
    ## top_interrupted_lons = (-90.0, 60.0)
    ## bottom_interrupted_lons = (90.0, -60.0)
## end
lons = zeros((2 + 2 * (length(top_interrupted_lons) + length(bottom_interrupted_lons))) * n + 1)
lats = zeros((2 + 2 * (length(top_interrupted_lons) + length(bottom_interrupted_lons))) * n + 1)
stop = 1

## Left boundary
lons[stop:stop + n-1] .= minlon
lats[stop:stop + n-1] .= LinRange(-90, 90, n)
stop += n

## Top boundary
for lon in top_interrupted_lons
    lons[stop:stop + n-1] .= lon - epsilon + central_longitude
    lats[stop:stop + n-1] .= LinRange(90, 0, n)
    stop += n
    lons[stop:stop + n-1] .= lon + epsilon + central_longitude
    lats[stop:stop + n-1] .= LinRange(0, 90, n)
    stop += n
end

## Right boundary
lons[stop:stop + n-1] .= maxlon
lats[stop:stop + n-1] .= LinRange(90, -90, n)
stop += n

## Bottom boundary
for lon in bottom_interrupted_lons
    lons[stop:stop + n-1] .= lon + epsilon + central_longitude
    lats[stop:stop + n-1] .= LinRange(-90, 0, n)
    stop += n
    lons[stop:stop + n-1] .= lon - epsilon + central_longitude
    lats[stop:stop + n-1] .= LinRange(0, -90, n)
    stop += n
end

## Close loop
lons[end] = minlon
lats[end] = -90

ring = GI.LinearRing(tuple.(lons, lats))
projected_ring = GO.reproject(ring, GFT.EPSG(4326), GFT.ProjString("+proj=igh +type=crs"))
ext = GI.extent(projected_ring)
ext_ring = GI.LinearRing([(ext.X[1], ext.Y[1]), (ext.X[1], ext.Y[2]), (ext.X[2], ext.Y[2]), (ext.X[2], ext.Y[1]), (ext.X[1], ext.Y[1]), ])
cropping_poly = GI.Polygon([ext_ring, projected_ring])

#

fig = Figure()
ax = GeoAxis(fig[1, 1]; dest = "+proj=igh")
background_plot = meshimage!(ax, -180..180, -90..90, rotr90(GeoMakie.earth()); npoints = 500)
logo_plot = meshimage!(ax, -180..180, -90..90, rotr90(Makie.logo()); npoints = 500)

hidedecorations!(ax)
xgrid_plot = lines!(ax.scene, ax.elements[:xgrid][1]; color = ax.xgridcolor, alpha = 0.5)
ygrid_plot = lines!(ax.scene, ax.elements[:ygrid][1]; color = ax.ygridcolor, alpha = 0.5)

cropping_plot = poly!(ax.scene, cropping_poly; color = :white, strokecolor = ax.xgridcolor)
fig