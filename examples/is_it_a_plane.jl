# # Geodesic paths - animation

# Let's take the great circle flight path from New York (JFK) 
# to Singapore (SIN) airport. 

using GeoMakie, CairoMakie
CairoMakie.activate!(px_per_unit = 2) # hide
using Proj, Animations

jfk = Point2f(-73.7789, 40.6397)
sin = Point2f(103.9894, 1.3592)

# First, we define the globe, as the WGS84 ellipsoid:
geod = Proj.geod_geodesic(6378137, 1/298.257223563)
# Then, we can solve the inverse geodesic problem, which provides 
# the shortest path between two points on our defined ellipsoid:
inv_line = Proj.geod_inverseline(geod, reverse(jfk)..., reverse(sin)...)
# Just for reference, this is the path:
f, a, p = lines(reverse(Proj.geod_path(geod, reverse(jfk)..., reverse(sin)...))...; linewidth = 3, axis = (; type = GeoAxis, dest = "+proj=natearth")); lines!(a, GeoMakie.coastlines(), color = (:black, 0.4)); f

# We'll use a satellite view for this, and alter the projection as a way of controlling the animation.

# First, we'll create 2 observables which control the position of the "camera":
# distance along path (from 0 to 1) and altitude (in meters)!

# The projection will always be centered at wherever the plane is.

# We first create an animation through time, representing times (as hours),
# relative distances along the path, and altitudes of observation, as 
# a function of time.  This is done by using the Animations.jl library.

times = [0, 0.5, 17.5, 18]
distances = [0, 0.05, 0.95, 1]
altitudes = [357860, 35786000/2, 35786000/2, 357860]
distance_animation = Animation(times, distances, linear())
altitude_animation = Animation(times, altitudes, sineio())


# In order to investigate this kind of projection, you can create 
# a GeoAxis with the projection you want, and then change the
# altitude to see how the zoom works in real time!

fig = Figure()
sl = Slider(fig[2, 1], range = exp.(LinRange(log(357860), log(35786000), 30)), startvalue = 35786000)
satview_projection = lift(sl.value) do alt
    "+proj=geos +h=$(round(Int, alt)) +lon_0=$(sin[1]) +lat_0=$(sin[2])"
end
ga = GeoAxis(fig[1, 1]; dest = satview_projection)
meshimage!(ga, -180..180, -90..90, GeoMakie.earth(), shading = NoShading)
fig


record(fig, "plots/plane.mp4", LinRange(0, 1, 120)) do i
    satview_projection[] = "+proj=geos +h=$(round(Int, at(altitude_animation, i*18))) +lon_0=$(Proj.geod_position_relative(inv_line, i)[2]) +lat_0=$(Proj.geod_position_relative(inv_line, i)[1])"
    yield()
end
# ![](plane.mp4)

fig = Figure()
ga = GeoAxis(fig[1, 1]; dest = "+proj=nsper +h=3000000 +lat_0=-20 +lon_0=145")
meshimage!(ga, -180..180, -90..90, GeoMakie.earth(), shading = NoShading)
fig
#
# make cover image #jl
mkpath("covers") #hide
save("covers/$(splitext(basename(@__FILE__))[1]).png", fig) #hide
nothing #hide
