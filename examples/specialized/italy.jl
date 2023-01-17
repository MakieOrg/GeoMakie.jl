using Pkg
using CairoMakie, GeoMakie
using GeoMakie.GeoJSON
using Downloads
using GeometryBasics
using GeoInterface

# Acquire data
all_states = Downloads.download("") # TODO: get a better Italy file!!
geo = GeoJSON.read(read(all_states))

fig = Figure()
ga = GeoAxis(fig[1, 1]; dest = "+proj=ortho +lon_0=12.5 +lat_0=42", lonlims=(12, 13), latlims = GeoMakie.automatic)
poly!(ga, geo; strokecolor = :blue, strokewidth = 1, color = (:blue, 0.5), shading = false);
autolimits!(ga)

fig



# using Makie, CairoMakie, GeoMakie

# destnode = Observable("+proj=ortho")

# fig = Figure()
# ga = GeoAxis(
#     fig[1, 1],
#     coastlines = true,
#     dest = destnode,
#     lonlims = Makie.automatic
# )
# image!(-180..180, -90..90, rotr90(GeoMakie.earth()); interpolate = false)
# hidedecorations!(ga)

# record(fig, "rotating_earth_ortho.mp4"; framerate=30) do io
#     for lon in -55:55
#         ga.title[] = string(lon) * "°"
#         xlims!(ga, lon-30, lon+30)
#         ylims!(ga, lon-30, lon+30)
#         destnode[] = "+proj=ortho +lon_0=$lon +lat_0=$lon"

#         recordframe!(io)
#     end
# end

# xs = collect(1:50.0)
# ys = collect(1:50.0)

# xs[23:27] .= NaN
# ys[23:27] .= NaN

# zs = randn(length(xs), length(ys))

# msh = CairoMakie.surface2mesh(xs, ys, zs)

# CairoMakie.nan_aware_decompose_normals(msh)

# surface(xs, ys, zs)

# col = rand(length(xs)*length(ys))
# GLMakie.activate!(inline = true)
# mesh(msh; color = col, shading = false)
# CairoMakie.activate!()
# mesh(msh; color = col, shading = false)

# h5open("/Users/anshul/desktop/test.h5") do file
#     global cth = file["cth"][:,:]
#     global lat = file["lat"][:,:]
#     global lon = file["lon"][:,:]
#  end

# fig = Figure()
# ga = GeoAxis(fig[1,1]; coastlines=true, dest = "+proj=ortho", lonlims = (-10,10), latlims=(35,55));
# surface!(ga, lon, lat, cth; shading = false)
# fig