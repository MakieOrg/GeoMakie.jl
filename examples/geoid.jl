#=
# Geoid + datum reference

A globe with an exaggerated EGM96 geoid surface, overlaid with the WGS84 geocentric datum and a translated "local" datum to illustrate how regionally-fit ellipsoids deviate from the geocentric reference.

```@cardmeta
Description = "Geoid surface with geocentric and local datum silhouettes"
Cover = fig
```
=#

using Rasters, ArchGDAL, Downloads
using GeoMakie

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

# Drape coastlines onto the (exaggerated) geoid surface itself by sampling the raster
# at each (lon, lat). This puts them at the same radial distance as the surface so
# depth testing hides back-of-globe coastlines naturally — no depth_shift hack needed.
draped = Point3f[]
for ls in GeoMakie.coastlines()
    for pt in ls.points
        z = 10_000 * gravitational_potential_ras[X(Near(pt[1])), Y(Near(pt[2]))]
        push!(draped, Point3f(pt[1], pt[2], z))
    end
    push!(draped, Point3f(NaN, NaN, NaN))
end
cl = lines!(ax, draped; color = :black, linewidth = 0.5)

# --- Geocentric datum + local datum silhouettes ----------------------------
# Plot two reference ellipsoid silhouettes against the bumpy geoid surface
# (whose undulation N is exaggerated 10000×): the global geocentric datum
# (WGS84, centred at Earth's mass centre) as a solid black circle, and a
# local datum — a regional ellipsoid translated to better fit the geoid in
# the visible area — as a dashed pink circle. Mirrors r.geocompx.org's
# 02_datum_fig.png.
using LinearAlgebra: norm, cross, normalize

cc = cameracontrols(ax.scene)
lon, lat, _ = Makie.apply_transform(ax.inv_transform_func[], cc.eyeposition[])

surface_pt = Point3f(Makie.apply_transform(ax.transform_func[], Point3d(lon, lat, 0.0)))

# Build screen-aligned orthonormal frame in the plane perpendicular to the
# (post-orbit) view direction. Flipped so +u1 = screen-right, +u2 = screen-up.
final_eye = Makie.apply_transform(ax.transform_func[], Point3d(lon - 90, 0.0, 0.0))
d̂  = normalize(Vec3f(final_eye))
u1 = -normalize(cross(d̂, Vec3f(0, 0, 1)))   # screen-right
u2 =  normalize(cross(d̂, u1))                # screen-up
a_wgs84 = 6_378_137.0
ts = range(0, 2π; length = 361)
pink = RGBf(0.93, 0.27, 0.6)

# Geocentric datum: solid black circle at WGS84 semi-major axis, centred at origin.
geocentric = [Point3f(a_wgs84 * (cos(t) * u1 + sin(t) * u2)) for t in ts]
lines!(ax.scene, geocentric;
       color = :black, linewidth = 2.5, overdraw = true)

# Local datum: pink dashed circle, translated toward the surface region of
# interest so it bulges out on that side and tucks inside on the opposite —
# the visual signature of a regionally-fit ellipsoid.
offset = 0.04 * a_wgs84 * normalize(surface_pt)
local_datum = [Point3f(offset + a_wgs84 * (cos(t) * u1 + sin(t) * u2)) for t in ts]
lines!(ax.scene, local_datum;
       color = pink, linestyle = :dash, linewidth = 2.5, overdraw = true)

# Thin crosshairs through the geocentre, in the view plane.
hl = 1.04 * a_wgs84
lines!(ax.scene, [Point3f(-hl * u1), Point3f(hl * u1)];
       color = :black, linewidth = 0.6, overdraw = true)
lines!(ax.scene, [Point3f(-hl * u2), Point3f(hl * u2)];
       color = :black, linewidth = 0.6, overdraw = true)

# Annotation labels: top-left for Geocentric (index ≈ 135°), right for Local (index ≈ 0°).
text!(ax.scene, geocentric[136];
      text = "Geocentric\ndatum",
      align = (:right, :bottom), offset = (-8, 4),
      fontsize = 16, color = :black, overdraw = true)
text!(ax.scene, local_datum[1];
      text = "Local\ndatum",
      align = (:left, :center), offset = (10, 0),
      fontsize = 16, color = pink, overdraw = true)

# Move the camera 90° around in longitude so the datum line is seen edge-on,
# and tighten the FOV so the globe fills the square frame.
update_cam!(ax; longlat = (lon - 90, 0.0), fov = 22)
fig
