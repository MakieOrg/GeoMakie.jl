# setup
using ZipFile

function get_coastline_shapefile()
    dir = mktempdir()
    zip = Base.download("https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/physical/ne_110m_coastline.zip")

    # read the Zip file
    r = ZipFile.Reader(zip);

    # populate the folder
    cd(dir) do
        for f in r.files
            open(f.name, "w") do file
                write(file, read(f, String))
            end
        end
    end

    return dir
end

using Proj4, Shapefile, GeoInterface, Makie, MakieLayout, PlotUtils

# path to shapefile of coastline
path = "ne_110m_coastline/ne_110m_coastline.shp"

# plain projection
src_proj = Projection("+proj=longlat +datum=WGS84 +no_defs")

# Robinson projection
dest_proj = Projection("+proj=robin")

# load the shapefile
table = Shapefile.Table(path)

# remove any missing elements (of which there are none)
shapes = collect(skipmissing(Shapefile.shapes(table)))

# index into all arrays once - there is one extra layer of arrays
data = getindex.(GeoInterface.coordinates.(shapes), 1)

# compute the length of the eventual padded array
length_of_data = sum(length.(data)) + length(data)

# preallocate an array
linevec_transformed = Vector{Point2f0}(undef, length_of_data)
linevec_original = Vector{Point2f0}(undef, length_of_data)

function to_nansep_vec(f::Function, data::Vector{Vector{T}}) where T

    length_of_data = sum(length.(data)) + length(data)

    lvec = Vector{T}(undef, length_of_data)

    pos = 1

    for (i, datum) in enumerate(data)
        lvec[pos:(pos+length(datum)-1)] .= f(datum)
        pos += length(datum)
        lvec[pos] = Point2f0(NaN, NaN)
        pos += 1
    end

    return lvec

end

linevec_transformed = to_nansep_vec(data) do datum
    transform.(src_proj, dest_proj, datum)
end

plv = Point2f0.(linevec_transformed)

linevec_original = to_nansep_vec(identity, data) .|> Point2f0

# loop through all linestrings, transform, and merge
# (you can also skip the merging, and make individual lineplots)
# for (i, datum) in enumerate(data)
#     global pos
#     linevec_transformed[pos:(pos+length(datum)-1)] .= transform.(src_proj, dest_proj, datum)
#     linevec_original[pos:(pos+length(datum)-1)]    .= datum
#
#     pos += length(datum)
#     linevec_transformed[pos] = Point2f0(NaN, NaN)
#     linevec_original[pos]    = Point2f0(NaN, NaN)
#     pos += 1
# end

# rudimentary comparison plot
scene, layout = layoutscene()

sc1 = layout[1, 1] = LAxis(scene, title = "Lat/Long", xticks = AutoLinearTicks(100f0), yticks = AutoLinearTicks(100f0), aspect = AxisAspect(1))
sc2 = layout[1, 2] = LAxis(scene, title = "Robinson", xticks = AutoLinearTicks(500f0), yticks = AutoLinearTicks(500f0), aspect = AxisAspect(1))


lines!(sc1, linevec_original;    color = Makie.Colors.colorant"#add8e6", linewidth = 2)
lines!(sc2, linevec_transformed; color = Makie.Colors.colorant"#add8e6", linewidth = 2)

display(scene)

"""
    axis_points_for_geo(xmin, xmax, ymin, ymax)

Returns a vector of NaN separated Point2 series which represent the sampled axis
for transformation.
"""
function axis_grid_for_geo(xmin, xmax, ymin, ymax; density = 100, x_k_min=5, x_k_max=10, x_k_ideal=7, y_k_min=5, y_k_max=10, y_k_ideal=7)

    xticks = PlotUtils.optimize_ticks(xmin, xmax; k_min = x_k_min, k_max = x_k_max, k_ideal = x_k_ideal, extend_ticks = true)[1]
    yticks = PlotUtils.optimize_ticks(ymin, ymax; k_min = y_k_min, k_max = y_k_max, k_ideal = y_k_ideal, extend_ticks = true)[1]

    numticks = length(xticks) + length(yticks)

    linevec = Vector{Point2f0}()

    for xtick in [xticks]
        append!(linevec, transform.(src_proj, dest_proj, Point2f0.(xtick, LinRange(ymin, ymax, density))))
        push!(linevec, Point2f0(NaN))
    end
    for ytick in yticks
        append!(linevec, transform.(src_proj, dest_proj, Point2f0.(LinRange(xmin, xmax, density), ytick)))
        push!(linevec, Point2f0(NaN))
    end

    return linevec

end

"""
    axis_points_for_geo(xmin, xmax, ymin, ymax)

Returns a vector of NaN separated Point2 series which represent the sampled axis
frame which has been transformed..
"""
function axis_frame_for_geo(xmin, xmax, ymin, ymax; density = 100)
    linevec = Vector{Point2f0}(undef, (density+1)*4)

    append!(linevec, transform.(src_proj, dest_proj, Point2f0.(xmin, LinRange(ymin, ymax, density))))
    push!(linevec, Point2f0(NaN))

    append!(linevec, transform.(src_proj, dest_proj, Point2f0.(xmax, LinRange(ymin, ymax, density))))
    push!(linevec, Point2f0(NaN))

    append!(linevec, transform.(src_proj, dest_proj, Point2f0.(LinRange(xmin, xmax, density), ymin)))
    push!(linevec, Point2f0(NaN))

    append!(linevec, transform.(src_proj, dest_proj, Point2f0.(LinRange(xmin, xmax, density), ymax)))
    push!(linevec, Point2f0(NaN))

    return linevec

end

xmin, xmax = (-180, 180)
ymin, ymax = (-90, 90)

sc = lines(transform.(src_proj, dest_proj, linevec_original); color = Makie.Colors.colorant"#add8e6", linewidth = 2, show_axis = false)
lines!(sc, axis_points_for_geo(xmin, xmax, ymin, ymax); color = RGBA(Makie.Colors.colorant"light grey", 0.7))
lines!(sc, axis_frame_for_geo(xmin, xmax, ymin, ymax))

display(sc) # projected thingamajig

function draw_geo_axis!(
        scene,
        data,
        attributes::Attributes;
        source = crs(data) === nothing ? Projection("+proj=longlat +datum=LonLat +no_defs") : crs(data),
        dest = Projection("+proj=longlat +datum=LonLat +no_defs")
    )

    limits = boundingbox(data)



end
