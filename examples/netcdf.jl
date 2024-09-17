#=
# Data from netCDF
Here, we show how to plot data from a netCDF file via GeoMakie.
The example uses global sea surface temperature.
=#

using NCDatasets
using GeoMakie
using CairoMakie

# Download the data
src = "https://www.unidata.ucar.edu/software/netcdf/examples/tos_O1_2001-2002.nc"
dst = "tos_O1_2001-2002.nc"
download(src, dst)

# Read latitude and longitude coordinates + sea surface temperature
# Temperature has a time index... just select the first time step
ds = NCDataset("tos_O1_2001-2002.nc", "r")
lat = ds["lat"][:]
lon = ds["lon"][:]
temp = ds["tos"][:,:,1]
close(ds)
rm("tos_O1_2001-2002.nc")

# Longitude ranges from 0 to 360
# Convert to -180 to 180 and sort temp accordingly
lon[lon .> 180] .-= 360
sort_idx = sortperm(lon)
lon = lon[sort_idx]
temp = temp[sort_idx,:]

# Plot the data as a heatmap with coastlines and a colorbar
fig = Figure(size=(900,500))
ax = GeoAxis(fig[1,1]; dest="+proj=longlat +datum=WGS84", xgridwidth=0.15, ygridwidth=0.15)
sp = GeoMakie.heatmap!(ax, lon, lat, temp; colormap=cgrad(:viridis))
lines!(ax, GeoMakie.coastlines(); color = :black, linewidth=1.0)
cb = Colorbar(fig[1, 2], sp, width=30, height=Relative(0.7), label="Sea Surface Temperature (K)")
fig

#=
```@cardmeta
Cover = fig
Description = "Plotting data from a netCDF file"
```
=#