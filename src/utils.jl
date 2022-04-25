using Statistics, LinearAlgebra
############################################################
#                                                          #
#         Proj.Transform as a Makie transformation         #
#                                                          #
############################################################

# This function is a little gnarly.
# In Makie, we use NaN as a blank point, i.e. any line
# ends at NaN and restarts at the next point.
# However, if NaN goes somewhere in ℝ² in the projection,
# this utility is lost and the plot will have a bunch of lines
# going to transformation(Point2f(NaN)).
# In order to avoid this, we check first if the point is NaN,
# if so we return NaN.  Then, and only then, do we transform it.
# This does not seem to effect times too much but can be removed
# if necessary.
function Makie.apply_transform(t::Proj.Transformation, pt::Point{N,T}) where {N,T}
    if all(isnan.(pt))
        return Point{N, T}(NaN)
    end
    # this is to catch errors - show the point which was invalid
    # and then catch it.
    try
        f = Point(t(Vec(pt)) ./ 100_000)
        return f
    catch e
        # catch this annoying edge case
        # if pt[2] ≈ 90.0f0 || pt[2] ≈ -90.0f0
        #     println("Caught a 90-lat")
        #     return Point(t(Vec(pt[1], 90.0f0)) ./ 100_000)
        # end
        println("Invalid point for transformation!")
        @show pt
        rethrow(e)
    end
end

function Makie.apply_transform(f::Proj.Transformation, r::Rect2{T}) where {T}
    # TODO: once Proj4.jl is updated to PROJ 8.2, we can use
    # proj_trans_bounds (https://proj.org/development/reference/functions.html#c.proj_trans_bounds)
    N = 21
    umin = vmin = T(Inf)
    umax = vmax = T(-Inf)
    xmin, ymin = minimum(r)
    xmax, ymax = maximum(r)
    for x in range(xmin, xmax; length = N)
        for y in range(ymin, ymax; length = N)
            u, v = Makie.apply_transform(f, Point(x, y))
            umin = min(umin, u)
            umax = max(umax, u)
            vmin = min(vmin, v)
            vmax = max(vmax, v)
        end
    end

    return Rect(Vec2(umin, vmin), Vec2(umax-umin, vmax-vmin))
end

Makie.inverse_transform(p::Proj.Transformation) = Base.inv(p)

Base.isfinite(p::Point2f) = isfinite(p[1]) && isfinite(p[2])

function find_transform_limits(ptrans; lonrange = (-180, 180), latrange = (-90, 90))
    # Search for a good bound with decent accuracy
    lons = Float32.(LinRange(lonrange..., 360 * 2))
    lats = Float32.(LinRange(latrange..., 180 * 2))
    # avoid PROJ wrapping 180 to -180
    lons[1]   = nextfloat(lons[1])
    lons[end] = prevfloat(lons[end])
    lats[1]   = nextfloat(lats[1])
    lats[end] = prevfloat(lats[end])

    points = Point2f.(lons, lats')
    tpoints = ptrans.(points)
    itpoints = inv(ptrans).(tpoints)

    finite_inds = findall(isfinite, itpoints)

    min, max = getindex.(Ref(itpoints), finite_inds[[1, end]])

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

# Direction finder - find how to displace the tick so that it is out of the axis

function tick_direction(scene, tick_max_extent, tickcoord; ds = 0.01)
    tfunc = scene.transform.transform_func[]
    px, py = tfunc(tickcoord)
    Δx = tfunc(tickcoord + Point2f(ds, 0))
    Δy = tfunc(tickcoord + Point2f(0, ds))

    pixel_Δx, pixel_Δy = project_to_pixelspace(scene, [Δx, Δy])

    dx = tickcoord - pixel_Δx
    dy = tickcoord - pixel_Δy

    # The vector which is normal to the plot in pixel-space.
    normal_vec = Vec2(-(dx + dy)/2)
    normal_vec = normal_vec / sqrt(sum(normal_vec .^2))

    padding_vec = normal_vec * tick_max_extent # tick_max_extent should be in px

    return padding_vec
end

function are_ticks_colocated(scene, positions, labels, fontsize)
    pixel_positions = positions
    if all(isapprox(positions[1]; atol = 10.0), positions)
        return true
    elseif false
        return true
    else
        return false
    end
end

function overlapping_ticks(scene, positions, labels, fontsize)
end

############################################################
#                                                          #
#                      Useful macros                       #
#                                                          #
############################################################

"""
    @hijack_observable name::Symbol

Assuming the presence of a `hijacked_observables::Dict{Symbol, Any}` and `ax::Axis`,
hijacks the Observable `ax[name]` and redirects all its updates to `hijacked_observables[name]`,
while keeping `ax[name]` as `false`.

More technically, this macro injects a function at the beginning of `ax[name].listeners`, which
forwards whatever update was made to `hijacked_observables[name]`, and sets `ax[name].val = false`.
Thus, even though the rest of the listeners will continue to receive updates from this observable
(in case there is a need for it to remain), its value will remain `false`.
"""
macro hijack_observable(name)
    return esc(quote
        getproperty(ax, $name)[] = $(false)
        hijacked_observables[$name] = Observable($(true))
        __listener = on(getproperty(ax, $name)) do hijacked_obs_value
            hijacked_observables[$name][] = hijacked_obs_value
            getproperty(ax, $name).val = $(false)
        end
        # give our listener absolute priority; that means that
        # our function will be executed first.  Even though the
        # axis will _receive_ the signal, when it _reads_ the
        # Observable's value, it will see only `false`.
        pop!(getproperty(ax, $name).listeners)
        pushfirst!(getproperty(ax, $name).listeners, __listener.f)

    end)

end
