# # OSMMakie + GeoMakie

using LightOSM, OSMMakie
using GeoMakie, CairoMakie
CairoMakie.activate!(px_per_unit = 4) # hide

# This works with GLMakie as well,
# if you want interactivity!

download_osm_network(:bbox; # rectangular area
    minlat = 51.5015, # bottom left corner
    minlon = -0.0921,
    maxlat = 51.5154, # top right corner
    maxlon = -0.0662,
    network_type = :drive, # download motorways
    save_to_file_location = "london_drive.json"
);

# load as OSMGraph
osm = graph_from_file("london_drive.json";
    graph_type = :light, # SimpleDiGraph
    weight_type = :distance
)

fig = Figure()
ga = GeoAxis(fig[1, 1]; dest="+proj=eqearth +lon_0=25")

osmplot!(ga, osm)
datalims!(ga)
fig

download_osm_buildings(:bbox;
    minlat = 51.5015,
    minlon = -0.0921,
    maxlat = 51.5154,
    maxlon = -0.0662,
    metadata = true,
    download_format = :osm,
    save_to_file_location = "london_buildings.osm",
);

# load as Buildings Dict

buildings = buildings_from_file("london_buildings.osm");

# plot London map with buildings

fig = Figure();
ga = GeoAxis(fig[1, 1]; dest="+proj=ortho +lon_0=0 +lat_0=51.5", lonlims = (0, 1), latlims=(50, 51))
plot = osmplot!(ga, osm; buildings)
datalims!(ga)
fig
#
# make cover image #jl
mkpath("covers") #hide
save("covers/$(splitext(basename(@__FILE__))[1]).png", fig) #hide
nothing #hide