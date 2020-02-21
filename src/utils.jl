########################################
#            Side constants            #
########################################

const TOP = Top()
const LEFT = Left()
const RIGHT = Right()
const BOTTOM = Bottom()


################################################################################
#                              Utility functions                               #
################################################################################

to2tuple(x1, x2) = (x1, x2)

"""
Recursively convert every element in the collection to a Point2f0.
"""
rec_point(x::Vector{<: AbstractFloat}) = Point2f0(x)
rec_point(x) = rec_point.(x)

"""
Recurses through the given structure until it reaches a Point2f0, then projects it.
"""
rec_project(source::Projection, dest::Projection, array) = rec_project.(source, dest, array)
rec_project(source::Projection, dest::Projection, point::Point2f0) = transform(source, dest, point)


########################################
#          Grid tessellation           #
########################################

"""
    grid_triangle_faces(lats, lons)

Returns a series of triangle indices from naive triangulation.
"""
function grid_triangle_faces(lons, lats)
    faces = Array{Int, 2}(undef, (length(lons)-1)*(length(lats)-1)*2, 3)

    xmax = length(lons)

    i = 1
    # TODO optimize this with broadcast
    for lon in eachindex(lons)[1:end-1]

        for lat in eachindex(lats)[1:end-1]

            cpos = lon + (lat-1)*xmax

            faces[i, :] = [cpos, cpos+1, cpos+xmax+1]

            faces[i+1, :] = [cpos, cpos+xmax, cpos+xmax+1]

            i += 2

        end
    end

    return faces

end

"""
    gridpoints(xs, ys)

Returns a Vector of Points of a grid formed by xs and ys.
"""
gridpoints(xs, ys) = vec([Point2f0(x, y) for y in ys, x in xs])

"""
    triangulated_grid(xs, ys) -> points, faces

Takes in two ranges, and returns a triangulated regular grid based on those ranges.
"""
triangulated_grid(xs, ys) = (gridpoints(xs, ys), grid_triangle_faces(xs, ys))

date_regex(dirname, ext) = Regex("$(dirname)_(\\d{4})-(\\d{2}).$(uppercase(ext))")
imflip(img) = reverse(vec(transpose(reverse(img; dims=2))))

########################################
#       Nested array flattening        #
########################################

"""
    to_nansep_vec([f::Function,] data::Vector{Vector{T}};
        outtype = Point2f0, length_of_data = sum(length.(data)) + length(data)
    )

Flattens the given Vector of Vectors into a single Vector,
while inserting NaN separations between each individual sub-
vector.

If `f` is given, then `f` will be executed on each subvector
before it is merged into the main vector.  If it is not, the data
will remain unchanged (i.e., `f` is just `identity`).
"""
function to_nansep_vec(f::Function, data::AbstractVector{T}; outtyp = Point2f0, length_of_data = sum(length.(data)) + length(data)) where T

    lvec = Vector{outtyp}(undef, length_of_data)

    pos = 1

    for (i, datum) in enumerate(data)
        output = f(datum)
        lvec[pos:(pos+length(output)-1)] .= output
        pos += length(output)
        lvec[pos] = outtyp(NaN)
        pos += 1
    end

    return lvec

end

to_nansep_vec(data::Vector{Vector{T}}; outtyp = Point2f0) where T = to_nansep_vec(identity, data; outtyp = outtyp)

########################################
#     Matrix-based grid generation     #
########################################

"""
    xygrid(lons::Vector, lats::Vector; projection = LatLon()) -> (x::Matrix, y::Matrix)

Generates a grid of x and y coordinates in lat-lon space from the given ranges.

Optionally, also projects them into the specified CRS before returning them.

!!! note
    Materializing the matrices is necessary for C-interoperability,
    since passing the matrix to C implies that it can't
    be stored lazily and generated on the fly.
"""
function xygrid(lons::AbstractVector{<: Number}, lats::AbstractVector{<: Number}; projection = LonLat(), source = LonLat())

    lats = Float64.(lats)
    lons = Float64.(lons)

    xs = [lon for lon in lons, lat in lats]  # xs / longitudes
    ys = [lat for lon in lons, lat in lats]  # ys / latitudes

    # this will internally reinterpret the matrices as vectors,
    # and transform them in place in C.  The matrices will
    # then hold the modified values.
    # Proj4.transform!(source, projection, vec(xs), vec(ys))

    return xs, ys

end

"""
    wrap_lon(x)

Wraps the input longitude (or Vector of longitudes)
into the domain `(-180, 180)`.
"""
wrap_lon(x) = -180 .+ (360 .+ ((x.+180) .% 360)) .% 360

# function Base.:(==)(a::Projection, b::Projection)
#     return Bool(
#         Proj4.proj_is_equivalent_to(
#             a.rep,
#             b.rep,
#             Proj4.PJ_COMP_EQUIVALENT
#         )
#     )
# end
