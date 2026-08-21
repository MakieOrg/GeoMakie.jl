# # General utility functions

function find_transform_limits(ptrans; lonrange = (-180, 180), latrange = (-90, 90))
    # Search for a good bound with decent accuracy
    lons = Float64.(LinRange(lonrange..., 360 * 2))
    lats = Float64.(LinRange(latrange..., 180 * 2))
    # avoid PROJ wrapping 180 to -180
    lons[1]   = nextfloat(lons[1])   |> nextfloat
    lons[end] = prevfloat(lons[end]) |> prevfloat
    lats[1]   = nextfloat(lats[1])   |> nextfloat
    lats[end] = prevfloat(lats[end]) |> prevfloat

    points = Point2{Float64}.(lons, lats')
    tpoints = ptrans.(points)
    itpoints = Makie.apply_transform(Makie.inverse_transform(ptrans), tpoints)

    finite_inds = findall(isfinite, itpoints)

    min, max = getindex.(Ref(itpoints), finite_inds[[begin, end]])
    return (min[1], max[1], min[2], max[2])
end

# This is the code for the function body of `apply_transform(f::Proj4.Transformation, r::Rect2)` once Proj4.jl is renamed to Proj.jl
# out_xmin = Ref{Float64}(0.0)
# out_ymin = Ref{Float64}(0.0)
# out_xmax = Ref{Float64}(0.0)
# out_ymax = Ref{Float64}(0.0)
# try
#     Proj.proj_trans_bounds(C_NULL, f.pj, Proj.PJ_FWD, minimum(r)..., maximum(r)..., out_xmin, out_ymin, out_xmax, out_ymax, N)
# catch e
#     @show r
#     @show out_xmin[] out_xmax[] out_ymin[] out_ymax[]
#     rethrow(e)
# end
#
# return Rect2{T}((out_xmin[], out_xmax[] - out_xmin[]), (out_ymin[], out_ymax[] - out_ymin[]))


############################################################
#                                                          #
#              Tick and tick label utilities               #
#                                                          #
############################################################

"""
    geoformat_ticklabels(nums::Vector)

A semi-intelligent formatter for geographic tick labels.  Append `"ᵒ"` to the end
of each tick label, to indicate degree.

This will check whether the ticklabel is an integer value (`round(num) == num`).
If so, label as an Int (1 instead of 1.0) which looks a lot cleaner.

## Example
```julia-repl
julia> geoformat_ticklabels([1.0, 1.1, 2.5, 25])
4-element Vector{String}:
 "1ᵒ"
 "1.1ᵒ"
 "2.5ᵒ"
 "25ᵒ"
```
"""
function geoformat_ticklabels(nums)
    labels = fill("", length(nums))
    for i in 1:length(nums)
        labels[i] = if round(nums[i]) == nums[i]
            string(Int(nums[i]), 'ᵒ')
        else
            string(nums[i], 'ᵒ')
        end
    end
    return labels
end

function side_degree_format(nums, negative_char, positive_char, delim)
    labels = fill("", axes(nums))
    for i in eachindex(nums)
        east_or_west = nums[i] < 0 ? negative_char : nums[i] > 0 ? positive_char : ' '
        labels[i] = if round(nums[i]) == nums[i]
            string(Int(abs(nums[i])), delim * east_or_west)
        else
            string(abs(nums[i]), delim * east_or_west)
        end
    end
    return labels
end

longitude_format(nums) = side_degree_format(nums, 'W', 'E', 'ᵒ')
latitude_format(nums) = side_degree_format(nums, 'S', 'N', 'ᵒ')

function _replace_if_automatic(typ::Type{T}, attribute::Symbol, auto) where T
    default_attr_vals = Makie.default_attribute_values(T, nothing)

    if to_value(get(default_attr_vals, attribute, automatic)) == automatic
        return auto
    else
        return to_value(default_attr_vals[attribute])
    end
end

# Project any point to coordinates in pixel space
function project_to_pixelspace(scene, point::Point{N, T}) where {N, T}
    @assert N ≤ 3
    return Point{N, T}(
        Makie.project(
            # obtain the camera of the Scene which will project to its screenspace
            camera(scene),
            # go from dataspace (transformation applied to inputspace) to pixelspace
            :data, :pixel,
            # apply the transform to go from inputspace to dataspace
            Makie.apply_transform(
                scene.transformation.transform_func[],
                point
            )
        )
    )
end

function project_to_pixelspace(scene, points::AbstractVector{Point{N, T}}) where {N, T}
    Point{N, T}.(
        Makie.project.(
            # obtain the camera of the Scene which will project to its screenspace
            Ref(Makie.camera(scene)),
            # go from dataspace (transformation applied to inputspace) to pixelspace
            Ref(:data), Ref(:pixel),
            # apply the transform to go from inputspace to dataspace
            Makie.apply_transform(
                scene.transformation.transform_func[],
                points
            )
        )
    )
end

function rotmat(θ)
    return Mat{2, 2}(cos(θ), sin(θ), -sin(θ), cos(θ))
end

"""
    geom_to_bands(geom; height = 100_000, base = 0)::Tuple{Vector{Point3d}, Vector{Point3d}}

Reduce a geometry to a NaN-separated list of points, and
return a pair of vectors of points in the same CRS - 
one with z coordinate `base`, and one at z coordinate
`base +height`.

Returns a tuple of `(lower_band, upper_band)`.

This can be directly splatted into Makie's `band!` recipe,
which will create a 3D band.  Especially useful in [`GlobeAxis`](@ref).


Accepts any GeoInterface-compatible geometry that is composed of curves
(linestrings or linear rings) or a higher level structure composed of such.

So any Polygon, MultiPolygon, LineString, MultiLineString, etc., but also
a vector of those, a table (from Tables.jl), or a feature collection.

## Example
```julia-repl
julia> lb, ub = geom_to_bands(california, 50_000)
julia> band(lb, ub; color = :red)
```
"""
function geom_to_bands(geom; height = 100_000.0, base = 0.0, kwargs...)
    geom_lower = GO.applyreduce(vcat, GO.TraitTarget(GI.AbstractCurveTrait), geom; init = (NaN, NaN, NaN), kwargs...) do geom
        points = GO.forcexyz(geom, base).geom
        push!(points, (NaN, NaN, NaN))
        return points
    end
    geom_upper = map(geom_lower) do point
        if isnan(point[3])
            point
        else
            (point[1], point[2], point[3] + height)
        end
    end
    return (Makie.Point3d.(geom_lower), Makie.Point3d.(geom_upper))
end