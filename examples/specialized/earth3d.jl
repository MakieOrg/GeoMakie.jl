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
