using GeoMakie, GLMakie

using Rasters, NCDatasets
import GeoInterface as GI, GeometryOps as GO
using Proj, Geodesy

# TODO: spin up a GeoMakieData.jl that has all these random files
file = "/Users/anshul/Downloads/ascat_20250718_101800_metopc_34742_eps_o_coa_3301_ovw.l2/ascat_20250718_101800_metopc_34742_eps_o_coa_3301_ovw.l2.nc"

ncd = NCDatasets.NCDataset(file)
# TODO: Rasters can't understand this file yet, it has a few bugs, so we have to do a few things manually
# this applies missing value and replaces it to nan.  It seems CDM deals with the scale/offset.
function juliarize(var)
    return replace((var), NCDatasets.attribs(var)["missing_value"] => NaN, missing => NaN)
end
lat = juliarize(ncd["lat"])
lon = juliarize(ncd["lon"])

# Split up the measurements into two halves,
# since there are actually two sensors - just
# integrated into the same file for some reason.
lat1 = lat[1:(end÷2), :]
lon1 = lon[1:(end÷2), :]

lat2 = lat[(end÷2 + 1):end, :]
lon2 = lon[(end÷2 + 1):end, :]

wind_speed = juliarize(ncd["wind_speed"])
wind_speed1 = wind_speed[1:(end÷2), :]
wind_speed2 = wind_speed[(end÷2 + 1):end, :]
# background image setup

# Full-sky mosaic from the European Southern Observatory.
# [Source webpage here.](https://www.eso.org/public/images/eso0932a/)
if !isfile("eso0932a.tif")
    download("https://cdn.eso.org/images/original/eso0932a.tif", "eso0932a.tif")
end
# NASA full-earth blue marble in July.
# [acknowledgment](https://visibleearth.nasa.gov/images/74092/july-blue-marble-next-generation)
if !isfile("bluemarble.png")
    download("https://eoimages.gsfc.nasa.gov/images/imagerecords/76000/76487/world.200406.3x5400x2700.png", "bluemarble.png")
end
# Load these images into memory as matrices of RGB
using FileIO, ImageIO
blue_marble_img = load("bluemarble.png")
starry_background_img = load("eso0932a.tif")

fig = with_theme(theme_dark()) do
    Figure(; figure_padding = 0)
end
ax = GlobeAxis(fig[1, 1]; show_axis = false)
cc = cameracontrols(ax.scene)
background_plot = meshimage!(
    ax, -180..180, -90..90, blue_marble_img; 
    uv_transform = :rotr90, zlevel = -20_000
)
sky_plot = meshimage!(
    ax, -180..180, -90..90, starry_background_img; 
    uv_transform = :rotr90, zlevel = 1e8,
)

img_plot1 = surface!(
    ax, 
    lon1, lat1, rand(Float64, size(lon1));
    shading = NoShading, 
    color = wind_speed1, 
    colorrange = Makie.zscale(wind_speed)
)
img_plot2 = surface!(
    ax, 
    lon2, lat2, rand(Float64, size(lon2));
    shading = NoShading, 
    color = wind_speed2, 
    colorrange = Makie.zscale(wind_speed)
)
Makie.update_state_before_display!(fig)

cc.eyeposition[] = [2e7, 2e7, 2e7]
cc.lookat[] = [0.0, 0.0, 0.0]
cc.upvector[] = [0.0, 0.0, 1.0]
update_cam!(ax.scene, cc)

display(fig; update = false)

# Now that we've plotted the raw data, let's look at the satellite.
# We use the timestamps from the file and assume the satellite is at the 
# center of each row of observation.

t = datetime2julian.(ncd["time"][1, :])
trange = LinRange(extrema(t)..., 100)[2:end]

satellite_lon = sum(@views lon[(end÷2):(end÷2+1), :]; dims = 1) ./ 2 |> vec
satellite_lat = sum(@views lat[(end÷2):(end÷2+1), :]; dims = 1) ./ 2 |> vec
satellite_alt = fill(1000_000, length(satellite_lon)) # TODO placeholder :D 

control_gl = GridLayout(fig[2, 1]; tellheight = true)
l1 = Label(control_gl[1, 1], "Time")
sl = Slider(control_gl[1, 2], range = trange, startvalue = trange[1], tellheight = false, tellwidth = true)
pb = Button(control_gl[1, 3], label = "▷")

satellite_marker = lift(sl.value) do ti
    idx = searchsortedfirst(t, ti)
    [Point3d(satellite_lon[idx], satellite_lat[idx], satellite_alt[idx])]
end

line_computation_graph = Makie.ComputeGraph()
Makie.add_input!(line_computation_graph, :t, sl.value[])

Makie.map!(line_computation_graph, [:t], [:points, :colors]) do ti
    idx = searchsortedfirst(t, ti)
    points = Point3d.(satellite_lon[1:idx], satellite_lat[1:idx], satellite_alt[1:idx])
    colors = RGBAf.((Makie.wong_colors()[2],), LinRange(0, 1, length(points)))
    return (points, colors)
end

on(sl.value) do ti
    Makie.update!(line_computation_graph; :t => ti)
end

marker_plt = scatter!(ax, satellite_marker; color = Cycled(1), markersize = 15, strokewidth = 0)
trajectory_plt = lines!(ax, line_computation_graph.points; color = line_computation_graph.colors)


is_playing = Ref(false)
on(pb.clicks) do clicks
    is_playing[] = !is_playing[]
    pb.label[] = is_playing[] ? "||" : "▷"
end
on(events(fig).tick) do tick
    if is_playing[]
        t_idx = mod1(searchsortedfirst(trange, sl.value[]) + 1, length(trange))
        Makie.set_close_to!(sl, trange[t_idx])
    end
end

extra_spicy = true
if extra_spicy
    
on(sl.value) do ti
    idx = searchsortedfirst(t, ti)
    data1 = deepcopy(wind_speed1)
    data2 = deepcopy(wind_speed2)

    data1[:, idx:end] .= NaN
    data2[:, idx:end] .= NaN

    update!(img_plot1; color = data1)
    update!(img_plot2; color = data2)
end
end
