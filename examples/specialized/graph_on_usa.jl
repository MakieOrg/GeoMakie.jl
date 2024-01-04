# This example was adapted from code in https://discourse.julialang.org/t/combine-makie-with-gmt-jl/74347
using GeoMakie, CairoMakie
using GraphMakie, Graphs, Downloads
using GeoMakie.GeoJSON, GeoMakie.GeoInterface

states = Downloads.download("https://raw.githubusercontent.com/PublicaMundi/MappingAPI/master/data/geojson/us-states.json")
states_geo = GeoJSON.read(read(states, String))
# Get rid of Alaska
filter!((x->!(x.properties["name"] ∈ ("Alaska", "Hawaii", "Puerto Rico"))), states_geo.features)

n = length(states_geo)

#g = wheel_graph(10)
gpos = Dict(
    (-96.5967, 38.9617) => "KSCYng",
    (-122.3, 47.6) => "STTLng",
    (-105.0, 40.75) => "DNVRng",
    (-122.026, 37.3858) => "SNVAng",
    (-87.6167, 41.8333) => "CHINng",
    (-85.5, 34.5) => "ATLAng",
    (-77.0268, 38.8973) => "WASHng",
    (-73.9667, 40.7833) => "NYCMng",
    (-86.1595, 39.7806) => "IPLSng",
    (-95.5174, 29.77) => "HSTNng",
    (-118.25, 34.05) => "LOSAng",
    (-84.3833, 33.75) => "ATLAM5")

g = complete_graph(length(keys(gpos)))
positions = Point2f.(collect(keys(gpos)))

fig = Figure(size = (1200, 800), fontsize = 22)
ga = GeoAxis(
    fig[1, 1],
    source = "+proj=longlat +datum=WGS84",
    dest = "+proj=lcc +lon_0=-100 +lat_1=33 +lat_2=45",
    title = "Projection: lcc +lon_0=-100 +lat_1=33 +lat_2=45",
    coastlines = false,
    lonlims = automatic, latlims = automatic,
)

poly!(
    ga, states_geo;
    color = 1:n, colormap = (:viridis, 0.25),
    strokecolor = :black, strokewidth = 1
)

graphplot!(
    ga, g;
    layout = _ -> positions, node_size = 1,
    edge_color = cgrad(:plasma)[LinRange(0, 1, 66)],
    node_color = cgrad(:plasma)[LinRange(0, 1, length(keys(gpos)))]
)

# Set the limits to the extrema of the data
# (this is why we removed Alaska)
datalims!(ga)

fig
