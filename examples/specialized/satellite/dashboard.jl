using GeoMakie, GLMakie
using GeoMakieArtifacts

using Geodesy, Proj
import GeometryOps as GO, GeoInterface as GI
using SatelliteToolbox

# ## Utility functions
# ```@raw html
# <details>
# <summary>Utility functions</summary>
# From gadomski/antimeridian on github
function crossing_latitude_flat(p1, p2)
    latitude_delta = p2[2] - p1[2]
    return if p2[1] > 0
        p1[2] + (180 - p1[1]) * latitude_delta / (p2[1] + 360 - p1[1])
    else
        p1[2] + (p1[1] + 180) * latitude_delta / (p1[1] + 360 - p2[1])
    end
end

const proj_transf_from_cart_to_longlat = GeoMakie.create_transform("+proj=longlat +datum=WGS84", "+proj=cart +type=crs")

function splitify(pos, color)
    newpos = Tuple{Float64, Float64}[]
    sizehint!(newpos, length(pos))
    newcolor = similar(color, 0)
    sizehint!(newcolor, length(color))

    p1 = proj_transf_from_cart_to_longlat(pos[1])[1:2]
    p2 = p1
    push!(newpos, p1)
    push!(newcolor, color[1])
    for i in 2:length(pos)
        p2 = proj_transf_from_cart_to_longlat(pos[i])[1:2]
        
        needs_split, sign = if p2[1] - p1[1] > 180 && p2[1] - p1[1] != 360
            true, -1
        elseif p1[1] - p2[1] > 180 && p1[1] - p2[1] != 360
            true, 1
        else
            false, 0
        end

        if needs_split
            crossing_latitude = sign == -1 ? crossing_latitude_flat(p1, p2) : crossing_latitude_flat(p2, p1)
            push!(newpos, (sign * 180.0, crossing_latitude))
            push!(newcolor, color[i])
            push!(newpos, (NaN, NaN))
            push!(newcolor, color[i])
            push!(newpos, (-sign * 180.0, crossing_latitude))
            push!(newcolor, color[i])
        end
        push!(newpos, p2)
        push!(newcolor, color[i])
        p1 = p2
    end
    return (newpos, newcolor)
end
# ```@raw html
# </details>
# ```

# ## Data acquisition

# ### Background images and attribution
# First, get some data - we have a skymap and a globe image.
skymap_image = joinpath(geomakie_artifact_dir("skymap"), "skymap.png") |> Makie.FileIO.load
skymap_attrib = get_attribution("skymap")

globe_image = joinpath(geomakie_artifact_dir("blue_marble_topo_november"), "image.png") |> Makie.FileIO.load
globe_attrib = get_attribution("blue_marble_topo_november")

# ### Geospatial data
# Let's get some geometries of interest that we can plot on the globe.
# For now, let's take the state of California and the county of Santa Clara.
# We'll use the GADM.jl package to get these.
using GADM
cali = GADM.get("USA", "California")
sc_county = GADM.get("USA", "California", "Santa Clara")

# ### Satellite trajectory
# Let's take the Hubble Space Telescope as an example here.
# We can get the TLE and simulate its orbit from SatelliteToolbox.jl.
# But, any data source will do, so long as it provides position and velocity vectors
# in an earth-centered, earth-fixed frame.
tle = SatelliteToolbox.tle"""
HST                     
1 20580U 90037B   25298.18540833  .00010258  00000+0  36633-3 0  9991
2 20580  28.4680 242.7474 0002152  56.7096 303.3705 15.27131570752566
"""

prop = Propagators.init(Val(:SGP4), tle)
sv_teme = Propagators.propagate!(prop, 0:1:(86400 * 30), OrbitStateVector)
eop = fetch_iers_eop()
sv_itrf = sv_eci_to_ecef.(sv_teme, (TEME(),), (SatelliteToolbox.ITRF(),), (eop,))
# ## Plotting!

# ### Background imagery and orbit lines
# First, let's create a `Figure` and place a `GlobeAxis` in it.
# We'll also add some background imagery: the NASA Blue Marble earth image,
# and a full-sky map from the European Southern Observatory.
#
# A couple things to note here:
# - The `uv_transform` keyword is used to rotate the image so that it looks like it's on the globe.
# - The `zlevel` keyword is used to control the depth of the image.
# - The `xautolimits`, `yautolimits`, and `zautolimits` keywords are used to control the limits of the axis.
# - The `reset_limits` keyword is used to reset the limits of the axis when the camera is moved.
f = with_theme(theme_dark()) do
    Figure(; figure_padding = 0)
end
a = GlobeAxis(f[1, 1]; show_axis = false)
sky_plot = meshimage!(a, -180..180, -90..90, skymap_image; uv_transform = :rotr90, zlevel = 7e7, xautolimits = false, yautolimits = false, zautolimits = false, reset_limits = false)
globe_plot = meshimage!(a, -180..180, -90..90, globe_image; uv_transform = :rotr90, zlevel = 0, reset_limits = false)
f
# ### Camera positioning
# It's possible to directly position the camera in ECEF space, which requires a little bit
# of manual transformation.
# First, we'll get the centroid of the Santa Clara county, which we want the camera to hover over.
sc_centroid = GO.centroid(sc_county)
# Then, we'll update the GeoAxis camera to look at the centroid.
Makie.update_cam!(a; longlat = sc_centroid)
f
# Note that to display the figure faithfully with these exact camera settings,
# you should run `display(f; update = false)` to avoid automatically updating the
# camera.  Similary to save, run `save("dashboard.png", f; update = false)`.
#
# ### Satellite orbit lines
# Now, let's plot the satellite orbit lines.
# This is a simple line plot, but it's **already** in ECEF space!
# So we can just indicate via the `source` keyword that it doesn't need
# to be transformed.  
# 
# But that's not all - you can plot any data from any projection,
# and it will get transformed appropriately.  So a satellite image, for example,
# can go directly onto the globe in its native projection, and will look correct.
orbit_plot = lines!(
    a,
    getproperty.(sv_itrf[1:86400÷2], :r); # get the position from the state vector
    transparency = false, 
    color = :lightblue, 
    source = "+proj=cart +type=crs", 
)
f
## Let's also plot some coastlines just for a visual reference.
coastline_plot = lines!(a, GeoMakie.coastlines(); color = :gray, linewidth = 1, zlevel = 20_000)
f
# ### Areas of interest
# You can use any "sensible" plot recipe on a `GlobeAxis`, it will get transformed correctly
# to the globe.
# Let's plot some 3D bands to highlight areas of interest - in this case,
# California and the Santa Clara county.
cali_lower, cali_upper = GeoMakie.geom_to_bands(cali; height = 25_000)
sc_lower, sc_upper = GeoMakie.geom_to_bands(sc_county; height = 40_000)
cali_band_plot = band!(a, cali_lower, cali_upper; color = :red)
lines!(a, cali_lower; color = :red)
sc_band_plot = band!(a, sc_lower, sc_upper; color = :green)
lines!(a, sc_lower; color = :green)
f
# ### Images
# You can also easily overlay an image, or a series of images, with any colormap,
# transparency, et cetera.
# It's as simple as getting the data and then plotting it, with either the 
# `meshimage!` or `surface!` recipes.
# To begin, let's plot a real satellite image 
using Downloads, FileIO
geostationary_img = FileIO.load(Downloads.download("https://gist.github.com/pelson/5871263/raw/EIDA50_201211061300_clip2.png"))
mi = meshimage!(a,
    -5500000 .. 5500000, -5500000 .. 5500000, geostationary_img;
    source="+proj=geos +h=35786000",
    npoints=1000,
    zlevel = 100_000,
)

# ## Animating the plot
# Let's do an animation of the plot, by showing the satellite orbit over time.
# We'll add a play button and a text field to control the speedup,
# and let the last 90 minutes of the orbit be visible at any point.
orbit_plot.visible[] = false

satellite_graph = Makie.ComputeGraph()

Makie.add_input!(satellite_graph, :time_rel, 0.001)

Makie.map!(satellite_graph, [:time_rel], [:satellite_position, :satellite_trajectory]) do t
    pos = sv_itrf[round(Int, t * 86400) + 1].r
    traj = getproperty.(view(sv_itrf, max(1, round(Int, t * 86400) - 180 * 30):round(Int, t * 86400) + 1), :r)
    return (pos, traj)
end
Makie.map!(satellite_graph, [:satellite_trajectory], [:satellite_trajectory_color]) do traj
    color = if length(traj) == 1
        RGBAf[Makie.wong_colors(1.0)[2]]
    else
        RGBAf.((Makie.wong_colors()[2],), LinRange(0, 1, length(traj)))
    end
    return (color,)
end

satellite_marker_plt = scatter!(
    a.scene, satellite_graph[:satellite_position];
    # marker = satellite_mesh,
)

satellite_trajectory_plt = lines!(
    a.scene,
    satellite_graph[:satellite_trajectory];
    color = satellite_graph[:satellite_trajectory_color]
)

# ### Trace of satellite path on GeoAxis
# We can also plot the trace of the satellite path on a GeoAxis off to the side.
diag_gl = GridLayout(f[1, 2]; alignmode = Outside())
ground_ax = GeoAxis(diag_gl[1, 1]; limits = ((-180, 180), (-90, 90)), title = "Ground Track")
meshimage!(ground_ax, -180..180, -90..90, globe_image; uv_transform = :rotr90)
lines!(ground_ax, GeoMakie.coastlines(); color = :white)
satellite_marker_ground_plt = scatter!(
    ground_ax, 
    satellite_graph[:satellite_position]; 
    source = "+proj=cart +type=crs", 
    marker = :circle, 
    color = :blue, 
    strokecolor = :white, 
    strokewidth = 1
)


map!(splitify, satellite_graph, [:satellite_trajectory, :satellite_trajectory_color], [:satellite_trajectory_cut, :satellite_position_color_cut])

satellite_trajectory_ground_plt = lines!(
    ground_ax,
    satellite_graph[:satellite_trajectory_cut];
    color = satellite_graph[:satellite_position_color_cut]
)


view_label = Label(diag_gl[2, 1], "Satellite View"; halign = :center, font = :bold,tellheight = true, tellwidth = false)
view_ax = GlobeAxis(diag_gl[3, 1]; show_axis = false, center = false)
meshimage!(view_ax, -180..180, -90..90, globe_image; uv_transform = :rotr90)

# Extract camera controls for the view axis
cc = Makie.cameracontrols(view_ax.scene)
# Update the camera when the satellite position changes
cam_controller = on(view_ax.scene, satellite_graph.satellite_position; update = true) do ecef
    time_rel = satellite_graph.time_rel[]
    lookat = Vec3d(0,0,0)
    # TODO: some coordinate system shenanigans here
    eyeposition = ecef .* 2
    upvector = Makie.normalize(sv_itrf[round(Int, time_rel * 86400) + 1].v)
    Makie.update_cam!(view_ax.scene, eyeposition, lookat, upvector)
    return nothing
end
# ## Animation: Play button and dynamic speedup

# Here's the dashboard controls to run the animation interactively.
controls_gl = GridLayout(diag_gl[4, 1]; alignmode = Outside())
play_button = Button(controls_gl[1, 1]; tellwidth = false, tellheight = true, label = "▶")
is_playing = Observable(false)

timestep_field = Textbox(controls_gl[1, 2]; placeholder = "0.001 days/frame", validator = Float64, tellwidth = false, tellheight = false)
timestep = Observable(0.001)
colgap!(controls_gl, 1, 0)

on(timestep_field.stored_string) do stored_string
    timestep[] = parse(Float64, stored_string)
end

play_button_text_listener = on(play_button.clicks; priority = 1000) do _
    is_playing[] = !is_playing[]
    if is_playing[]
        play_button.label[] = "||"
    else
        play_button.label[] = "▶"
    end
end
player_listener = Makie.Observables.on(events(f).tick) do tick
    tr = satellite_graph.time_rel
    if is_playing[]
        tic = time()
        if tr[] > 30 - 52 * timestep[]
            tr[] = 0.001
        else
            tr[] += timestep[]
        end
        yield()
        toc = time()
    else
        # do nothing
    end
end

f