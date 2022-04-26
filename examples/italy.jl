using CairoMakie, GeoMakie
using GeoMakie.GeoJSON
using Downloads
# Acquire data
it_states = Downloads.download("https://github.com/openpolis/geojson-italy/raw/master/geojson/limits_IT_provinces.geojson")
geo = GeoJSON.read(read(it_states, String))
basic = GeoMakie.geo2basic(geo)

fig = Figure()
ga = GeoAxis(fig[1, 1]; dest = "+proj=ortho +lon_0=12.5 +lat_0=42", lonlims=(12, 13), latlims = (40, 44))
plot!.(ga, basic; strokecolor = :blue, strokewidth = 1, color = (:blue, 0.5), shading = false);
datalims!(ga)

fig



fig_anim = Figure()
ga_anim = GeoAxis(fig_anim[1, 1]; dest = "+proj=ortho", lonlims=(-90,90), coastlines=true)

record(fig_anim, "try_3.mp4", 0:89) do i
    xlims!(ga_anim, -90+i, 90-i)
    ylims!(ga_anim, -90+i/2, 90-i/2)
end


record(fig_anim, "try_4.mp4", 0:89) do i
    xlims!(ga_anim, -90+i/2, 90-i)
    ylims!(ga_anim, -90+i, 90-i)
end
