fig = Figure()
ax1 = Axis(fig[1, 1])
mi = meshimage!(ax1, rotr90(Makie.logo()))
fig
save("simple_scaling.png", fig)
ax1.xscale = log10
ax1.yscale = log
save("log_scaling.png", fig)
fig = Figure()
ax1 = GeoAxis(fig[1, 1]; target_projection = "+proj=igh")
mi = meshimage!(ax1, -180..180, -90..90, rotr90(Makie.logo()))
fig
save("geo_scaling.png", fig)