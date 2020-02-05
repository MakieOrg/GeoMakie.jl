using NetCDF, GeoMakie
const Node = Observable

# Open the NetCDF file
f = NetCDF.open("/Users/anshul/Downloads/CERES_EBAF-TOA_Ed4.1_Subset_200003-201910.nc"; readdimvar = true)

lat = f.dim["lat"].vals
lon = f.dim["lon"].vals

t = 1 # time
f.vars["toa_net_all_mon"][:, :, t][:, :, 1] # this hack seems necessary for NetCDF, but I'm not sure why


field = Node{Matrix{Float64}}(f.vars["toa_net_all_mon"][:, :, t][:, :, 1])

cf = Node(copy(field[]))

source = Projection("+proj=lonlat +lon_0=180 +pm=180")
dest   = Projection("+proj=moll +lon_0=0")
projtup = Node([source, dest])

pm = Node(0)
oxs, oys = xygrid(lon, lat)

xs, ys = Node(copy(oxs)), Node(copy(oys))

on(projtup) do projtup
    # restore the arrays to their original values
    xs.val .= oxs
    ys.val .= oys
    source, dest = projtup
    # Transform the underlying array
    Proj4.transform!(source, dest, vec(xs.val), vec(ys.val))
    # Notify the arrays that they've been updated
    xs[] = xs[]
    ys[] = ys[]
end

projtup[] = [source, dest]

scene = surface(xs, ys; color = cf, shading = false, show_axis = false)

ph = on(pm) do pm
    projtup[] = [Projection("+proj=lonlat +lon_0=180 +pm=$pm"), Projection("+proj=moll +lon_0=-pm +pm=$pm")]
    circshift!(cf.val, field[], pm)
    cf[] = cf[]
end

record(scene, "test.mp4", 0:10:180; framerate = 2) do i
    pm[] = i
end
