fig = Figure()
ga = GeoAxis(fig[1, 1]; target_projection = "+proj=ortho +lon_0=19 +lat_0=50", #=limits = ((-90, 90), (-90, 90))=#)
lines!(ga, GeoMakie.coastlines())
surface!(ga, -180..180, -90..90, rand(100, 100))
fig