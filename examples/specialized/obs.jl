using NetCDF, GeoMakie
const Node = Observable
using CairoMakie # hide
CairoMakie.activate!(px_per_unit = 4) # hide

# Open the NetCDF file
f = NetCDF.open("/Users/anshul/Downloads/CERES_EBAF-TOA_Ed4.1_Subset_200003-201910.nc"; readdimvar = true)

lat = f.dim["lat"].vals
lon = f.dim["lon"].vals

t = 1 # time
f.vars["toa_net_all_mon"][:, :, t][:, :, 1] # this hack seems necessary for NetCDF, but I'm not sure why


field = Observable{Matrix{Float64}}(f.vars["toa_net_all_mon"][:, :, t][:, :, 1])

cf = Observable(copy(field[]))

source = Projection("+proj=lonlat +lon_0=180 +pm=180")
dest   = Projection("+proj=moll +lon_0=0")
projtup = Observable([source, dest])

pm = Observable(0)
oxs, oys = xygrid(lon, lat)

xs, ys = Observable(copy(oxs)), Observable(copy(oys))


projtup[] = [source, dest]

figure = Figure()
ga = GeoAxis(figure[1, 1]; dest = "+proj=moll")
surfplot = surface!(ga, xs, ys; color = field, shading = NoShading)

ph = on(pm) do pm
    projtup[] = [Projection("+proj=lonlat +lon_0=180 +pm=$pm"), Projection("+proj=moll +lon_0=-pm +pm=$pm")]
    circshift!(cf.val, field[], pm)
    cf[] = cf[]
end

record(scene, "test.mp4", 0:10:180; framerate = 2) do i
    pm[] = i
end
