using Rasters, ArchGDAL, Downloads
using GeoMakie, GLMakie 

path = Downloads.download("https://cdn.proj.org/us_nga_egm96_15.tif")
gravitational_potential_ras = Raster(path) # geoid undulation, metres
# The Proj provided EGM files are slightly weird in format, and thus off by 
# half a pixel from where they should be due to point/area misunderstandings.
# To fix this, we need to shift the raster by half a pixel.
xdim, ydim = dims(gravitational_potential_ras, (X, Y))
dx, dy = step(xdim), step(ydim)
gravitational_potential_ras = set(gravitational_potential_ras, X => xdim .+ dx/2, Y => ydim .+ dy/2)  

fig = Figure(size = (700, 700))
ax  = GlobeAxis(fig[1,1])
sp = surface!(ax, gravitational_potential_ras .* 10_000; colormap = :turbo)
cl = lines!(ax, GeoMakie.coastlines(); color = :black, linewidth = 0.5, depth_shift = -.01)
display(fig)   # let the camera/limits settle before reading them

# --- Geocentric datum line + reference ellipsoid silhouette ----------------
# Pick a (lon, lat) — here we just snapshot the current camera longitude/latitude —
# and draw the geocentric vertical at that point: a dashed line from the Earth's
# centre out through the surface tangent point. Then overlay a smooth red circle
# at the un-exaggerated WGS84 semi-major axis, perpendicular to the (post-orbit)
# view direction. Compared with the bumpy geoid surface (whose N is exaggerated
# 10000×) this shows the ideal vs. real shape, the contrast in the reference figure.
using LinearAlgebra: norm, cross, normalize

cc = cameracontrols(ax.scene)
lon, lat, _ = Makie.apply_transform(ax.inv_transform_func[], cc.eyeposition[])

centre     = Point3f(0, 0, 0)
surface_pt = Point3f(Makie.apply_transform(ax.transform_func[], Point3d(lon, lat, 0.0)))

# Reference-ellipsoid silhouette in the plane perpendicular to the final view
final_eye = Makie.apply_transform(ax.transform_func[], Point3d(lon - 90, 0.0, 0.0))
d̂  = normalize(Vec3f(final_eye))
u1 = normalize(cross(d̂, Vec3f(0, 0, 1)))
u2 = normalize(cross(d̂, u1))
a_wgs84 = 6_378_137.0
ellipsoid_silhouette = [Point3f(a_wgs84 * (cos(t) * u1 + sin(t) * u2)) for t in range(0, 2π; length = 361)]
lines!(ax.scene, ellipsoid_silhouette;
       color = :red, linewidth = 2.5, overdraw = true)

# Plot into ax.scene (not ax) so the (lon,lat,alt)→ECEF transform isn't applied;
# overdraw lets the segment buried inside the globe show through.
lines!(ax.scene, [centre, surface_pt];
       color = :red, linestyle = :dash, linewidth = 3, overdraw = true)
scatter!(ax.scene, [centre, surface_pt];
         color = [:black, :white], strokecolor = :black, strokewidth = 2,
         markersize = 28, overdraw = true)
text!(ax.scene, [centre, surface_pt];
      text  = ["geocentre",
               "$(round(lon;digits=1))°E, $(round(lat;digits=1))°N"],
      align = [(:left, :bottom), (:right, :bottom)],
      offset = [(12, 12), (-12, 12)],
      fontsize = 16, overdraw = true)

# Move the camera 90° around in longitude so the line is seen edge-on,
# and tighten the FOV so the globe fills the square frame.
update_cam!(ax; longlat = (lon - 90, 0.0), fov = 28)
fig
