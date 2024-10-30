using GLMakie, GeoMakie, Geodesy
 
transf = Geodesy.ECEFfromLLA(Geodesy.WGS84())

f, a, p = meshimage(-180..180, -90..90, GeoMakie.earth(); npoints = 100, z_level = 0, axis = (; type = LScene));
lp = lines!(a, Point3f.(1:10, 1:10, 110); color = :red, linewidth = 2)
cc = cameracontrols(a.scene)
cc.settings.mouse_translationspeed[] = 0.0
cc.settings.zoom_shift_lookat[] = false
Makie.update_cam!(a.scene, cc)
p.transformation.transform_func[] = transf
lp.transformation.transform_func[] = transf
f

# Now, you can scroll around the globe, and the axis will not zoom at all!


# Create a white background to obscure some lines you're plotting on the globe:

random_latlong_points = Point2f.(rand(12) .* 360 .- 180, rand(12) .* 180 .- 90)

f, a, bg_plot = meshimage(-180..180, -90..90, GeoMakie.earth(); npoints = 100, z_level = -20_000, axis = (; type = LScene))
bg_plot.transformation.transform_func[] = transf

# Now, plot some lines on the globe:

lineplot = lines!(a, GO.segmentize(GO.GeodesicSegments(; max_distance = 100_000), random_latlong_points); color = :black, linewidth = 2)
lineplot.transformation.transform_func[] = transf

f