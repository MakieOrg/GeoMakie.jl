# # Gridded arrows
# This example was taken from the [Cartopy gridded arrow example].  

# The big idea is to plot arrows from one CRS in another!

using GeoMakie, CairoMakie

xs = LinRange(311.9, 391.1, 30)
ys = LinRange(-23.6, 24.8, 20)

us = @. 1 * (2 * cos(2 * deg2rad(xs) + 3 * deg2rad(ys' + 30)) ^ 2)
vs = @. 2 * cos(6 * deg2rad(xs)) .+ ys' * 0 # that last part is just to establish the shape

pole_longitude=177.5
pole_latitude=37.5
arrow_crs = "+proj=ob_tran +o_proj=latlon +o_lon_p=0 +o_lat_p=$(pole_latitude) +lon_0=$(180+pole_longitude) +to_meter=$(deg2rad(1) * 6378137.0)"

f, a, p = arrows(
    xs, ys, us, vs; 
    arrowsize = 4,
    source = arrow_crs, 
    axis = (; type = GeoAxis, dest = "+proj=ortho +lon_0=-10 +lat_0=45")
)
# Now we plot the background:
ep = surface!(a, 
    -180..180, -90..90, 
    zeros(axes(rotr90(GeoMakie.earth()))); 
    shading = NoShading, color = rotr90(GeoMakie.earth())
)
translate!(ep, 0, 0, -1)
f

# ```@cardmeta
# Title = "Arrows"
# Description = "Gridded arrows"
# Cover = f
# ```

