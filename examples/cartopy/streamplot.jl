# # Streamplot

# This example was translated from the [Cartopy streamplot example](https://scitools.org.uk/cartopy/docs/latest/gallery/vector_data/streamplot.html#sphx-glr-gallery-vector-data-streamplot-py).

using CairoMakie, GeoMakie
using Interpolations # for Streamplot on gridded data if necessary

stream_f(x::Point2{T}) where T = Point2{T}(
    10 * (2 * cos(2 * deg2rad(x[1]) + 3 * deg2rad(x[2] + 30)) ^ 2),
    20 * cos(6 * deg2rad(x[1]))
)

pole_longitude=177.5
pole_latitude=37.5
fig, ax, plt = streamplot(
    stream_f, 311.9..391.1, -23.6..24.8;
    arrow_size = 6,
    source = "+proj=ob_tran +o_proj=latlon +o_lon_p=0 +o_lat_p=$(pole_latitude) +lon_0=$(180+pole_longitude) +to_meter=$(deg2rad(1) * 6378137.0)",
    axis = (;
        type = GeoAxis,
        title = "Streamplot",
    )
)
lp = lines!(ax, GeoMakie.coastlines(); linewidth = 0.5, color = :black, xautolimits = false, yautolimits = false)
translate!(lp, 0, 0, -1)
fig


# ## Gridded data
# You can also do a streamplot on gridded data via Interpolations.jl:
using Interpolations
xs = range(311.9, 391.1, 100)
ys = range(-23.6, 24.8, 100)
uvs = stream_f.(Point2f.(xs, ys'))
#
uv_itp = LinearInterpolation((xs, ys), uvs)
#
fig2, ax2, plt2 = streamplot(
    x -> uv_itp(x...), 311.9..391.1, -23.6..24.8; 
    arrow_size = 6, 
    source = "+proj=ob_tran +o_proj=latlon +o_lon_p=0 +o_lat_p=$(pole_latitude) +lon_0=$(180+pole_longitude) +to_meter=$(deg2rad(1) * 6378137.0)",
    axis = (;
        type = GeoAxis,
        title = "Streamplot on gridded data",
    )
)
# and it looks pretty much the same!

#=
```@cardmeta
Description = "A streamplot on gridded data."
Cover = fig2
```
=#