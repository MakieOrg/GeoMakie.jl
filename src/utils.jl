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

function Makie.inverse_transform(trans::Proj.Transformation)
    return Base.inv(trans)
end

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
    itpoints = Makie.apply_transform((Makie.inverse_transform(ptrans)), tpoints)

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

function text_bbox(textstring::AbstractString, textsize::Union{AbstractVector, Number}, font, align, rotation, justification, lineheight)
    glyph_collection = Makie.layout_text(
            textstring, textsize,
            font, align, rotation, justification, lineheight,
            RGBAf(0,0,0,0), RGBAf(0,0,0,0), 0f0
        )

    return Rect2f(Makie.boundingbox(glyph_collection, Point3f(0), Makie.to_rotation(rotation)))
end

# Direction finder - find how to displace the tick so that it is out of the axis
function directional_pad(scene, limits, tickcoord_in_inputspace, ticklabel::AbstractString, tickpad, ticksize, tickfont, tickrotation; ds = 0.01)
    # Define shorthand functions for dev purposes - these can be removed before release
    tfunc = x -> Makie.apply_transform(scene.transformation.transform_func[], x)
    inv_tfunc = x -> Makie.apply_transform(Makie.inverse_transform(scene.transformation.transform_func[]), x)
    # convert tick coordinate to dataspace
    tickcoord_in_dataspace = tfunc(tickcoord_in_inputspace)
    # determine direction to go in order to stay inbounds.
    xdir = tickcoord_in_inputspace[1] < 0 ? +1 : -1
    ydir = tickcoord_in_inputspace[2] > 0 ? +1 : -1
    Δs = Vec2f(xdir, ydir) .* tickpad ./ sum(tickpad) * ds
    # find the x and y directions
    # multiply by the sign in order to have them going outwards at any point
    Σp = sign(sum(Δs)) * inv_tfunc(tickcoord_in_dataspace + Δs)
    # project back to pixel space
    pixel_Δx, pixel_Δy = project_to_pixelspace(scene, Σp) - project_to_pixelspace(scene, tickcoord_in_inputspace)
    # invert direction - the vectors were previously facing the inside,
    # now they will face outside .
    dx = -pixel_Δx
    dy = -pixel_Δy

    # Correct the angle of displacement
    θ = atan(dy/dx)
    # if θ ∈ 0..π && tickpad[1] < tickpad[2]
    #     dy = -dy
    #     dx = -dx
    # elseif θ ∈ -0.5π..0.5π && tickpad[1] > tickpad[2]
    #     dy = -dy
    #     dx = -dx
    # end

    # The vector which is normal to the plot in pixel-space.
    normal_vec = Vec2f((dx, dy)./sqrt(dx^2 + dy^2))

    # We have computed the normal vector - now we have to get tick extents
    extents = text_bbox(
        ticklabel, ticksize,
        tickfont, Vec2f(0), tickrotation,
        0.0, # Makie.to_value(Makie.theme(scene, :justification)),
        0.0, # Makie.to_value(Makie.theme(scene, :lineheight))
    )

    padding_vec = normal_vec .* (extents.widths/2) - tickpad

    # println("$ticklabel ($(tickpad)) $(rad2deg(θ)) ⟹ $(_sprinti(normal_vec)) ⟹ $(_sprinti(padding_vec)); $(_sprinti(extents.widths)), $(Σp)")


    return padding_vec
end


function _sprinti(obj)
    return "[" * join(Makie.Formatters.plain(obj), ",") * "]"
end

# Positions in pixelspace

function are_ticks_colocated(scene, positions, labels, fontsize)
    isempty(positions) && return false
    @assert length(positions) == length(labels)
    pixel_positions = positions
    if all(isapprox(positions[1]; atol = 10.0), positions)
        return true
    elseif false
        return true
    else
        return false
    end
end

function euclidean_distance(p1::Point{N, T}, p2::Point{N, T})::T where {T <: Real, N}
    return sqrt(sum((p1 .- p2) .^2))
end

# Positions in pixelspace
# This function assumes that all ticks are not colocated
function remove_overlapping_ticks!(scene, xpositions, xlabels, xvisible, ypositions, ylabels, yvisible, fontsize)

    nx = length(xpositions); ny = length(ypositions)
    combined_positions = vcat(xpositions, ypositions)

    # compute distances between all positions
    # we cannot optimize this, because of literal edge cases
    distmat = fill(Inf32, (nx+ny), (nx+ny))
    @inbounds for i in 1:(nx+ny)
        @inbounds for j in 1:(i-1)
            distmat[i, j] = euclidean_distance(combined_positions[i], combined_positions[j])
        end
    end


    bad_combos = findall(distmat .< (fontsize))
    remove = fill(0, length(bad_combos))

    for (i, bad_pair) in enumerate(bad_combos)
        remove[i] = bad_pair[1]
    end

    unique!(remove); sort!(remove)
    length(remove)==0 && return
    length(remove)==1 && remove[1] == 0 && return
    remove[1] == 0 && popfirst!(remove)

    splitind = findfirst(>(nx), remove)
    if splitind == nothing
        splitind = length(remove)+1
    end

    deleteat!(xpositions, remove[1:(splitind-1)])
    deleteat!(xlabels,    remove[1:(splitind-1)])
    splitind == length(remove)+1 && return
    deleteat!(ypositions, remove[splitind:end] .- nx)
    deleteat!(ylabels,    remove[splitind:end] .- nx)

    return
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
