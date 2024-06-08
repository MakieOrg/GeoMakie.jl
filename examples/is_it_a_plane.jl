# # Geodesic paths - animation

# Let's take the great circle flight path from New York (JFK) 
# to Singapore (SIN) airport. 

using GeoMakie, CairoMakie
using Proj, Animations

JFK = Point2f(-73.7789, 40.6397)
SIN = Point2f(103.9894, 1.3592)

# First, we define the globe, as the WGS84 ellipsoid:
geod = Proj.geod_geodesic(6378137, 1/298.257223563)
# Then, we can solve the inverse geodesic problem, which provides 
# the shortest path between two points on our defined ellipsoid:
inv_line = Proj.geod_inverseline(geod, reverse(JFK)..., reverse(SIN)...)
# Just for reference, this is the path:
f, a, p = lines(reverse(Proj.geod_path(geod, reverse(JFK)..., reverse(SIN)...))...; linewidth = 3, axis = (; type = GeoAxis, dest = "+proj=natearth")); lines!(a, GeoMakie.coastlines(), color = (:black, 0.4)); f

# We'll use a satellite view for this, and alter the projection as a way of controlling the animation.

# First, we'll create 2 observables which control the position of the "camera":
# distance along path (from 0 to 1) and altitude (in meters)!

# The projection will always be centered at wherever the plane is.

# We first create an animation through time, representing times (as hours),
# relative distances along the path, and altitudes of observation, as 
# a function of time.  This is done by using the Animations.jl library.

times = [0.0, 3.5, 14.5, 18]
distances = [0.0, 0.05, 0.95, 1]
altitudes = [357860.0*2, 35786000, 35786000, 357860*2]
distance_animation = Animation(times, distances, linear())
altitude_animation = Animation(times, altitudes, sineio())


# In order to investigate this kind of projection, you can create 
# a GeoAxis with the projection you want, and then change the
# altitude to see how the zoom works in real time!

fig = Figure()
satview_projection = Observable("+proj=nsper +h=$(first(altitudes)) +lon_0=$(SIN[1]) +lat_0=$(SIN[2])")
ga = GeoAxis(fig[1, 1]; dest = satview_projection)
surface!(ga, -180..180, -90..90, zeros(axes(GeoMakie.earth() |> rotr90)); color = GeoMakie.earth() |> rotr90, shading = NoShading)
lines!(ga, GeoMakie.coastlines())
fig

#

record(fig, "plane.mp4", LinRange(0, 1, 240)) do i
    current_position = Proj.geod_position_relative(inv_line, i)
    current_time = i * last(times)
    ga.dest[] = "+proj=nsper +h=$(round(Int, at(altitude_animation, current_time))) +lon_0=$(current_position[2]) +lat_0=$(current_position[1])"
end
# ![](plane.mp4)

# ```@cardmeta
# Description = "A great circle flight from JFK to SIN"
# Cover = fig
# ```

