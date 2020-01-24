const TOP = Top()
const LEFT = Left()
const RIGHT = Right()
const BOTTOM = Bottom()

to2tuple(x1, x2) = (x1, x2)

rec_point(x::Vector{<: AbstractFloat}) = Point2f0(x)
rec_point(x) = rec_point.(x)

rec_project(source::Projection, dest::Projection, array) = rec_project.(source, dest, array)
rec_project(source::Projection, dest::Projection, point::Point2f0) = transform(source, dest, point)

"""
    grid_triangle_faces(lats, lons)

Returns a series of triangle indices from naive triangulation.
"""
function grid_triangle_faces(lons, lats)
    faces = Array{Int, 2}(undef, (length(lons)-1)*(length(lats)-1)*2, 3)

    xmax = length(lons)

    i = 1

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

"""
    to_nansep_vec([f::Function,] data::Vector{Vector{T}}) where T

Flattens the given Vector of Vectors into a single Vector,
while inserting NaN separations between each individual sub-
vector.

If `f` is given, then `f` will be executed on each subvector
before it is merged into the main vector.  If it is not, the data
will remain unchanged.
"""
function to_nansep_vec(f::Function, data::AbstractVector{AbstractVector{T}}) where T

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

to_nansep_vec(data::Vector{Vector{T}}) where T = to_nansep_vec(identity, data)
