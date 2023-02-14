############################################################
#                                                          #
#         Proj.Transform as a Makie transformation         #
#                                                          #
############################################################


const PROJ_RESCALE_FACTOR = 100_000

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
function Makie.apply_transform(t::Proj.Transformation, pt::V) where V <: VecTypes{N,T} where {N,T}
    if all(isnan.(pt))
        return V(NaN)
    end
    # this is to catch errors - show the point which was invalid
    # and then catch it.
    try
        return V(t(Vec(pt)) ./ PROJ_RESCALE_FACTOR)
    catch e
        # catch this annoying edge case
        # if pt[2] ≈ 90.0f0 || pt[2] ≈ -90.0f0
        #     println("Caught a 90° latitude")
        #     return Point(t(Vec(pt[1], 90.0f0)) ./ PROJ_RESCALE_FACTOR)
        # end
        println("Invalid point for transformation: $(pt)")
        rethrow(e)
    end
end

function Makie.apply_transform(f::Proj.Transformation, r::Rect2{T}) where {T}
    xmin, ymin = minimum(r)
    xmax, ymax = maximum(r)

    if isapprox(xmin, -180, rtol = 1e-4)
        xmin - -180e0
    end
    if isapprox(xmax, 180; rtol = 1e-4)
        xmax = 180e0
    end
    if isapprox(ymin, -90; rtol = 1e-4)
        ymin = -90e0
    end
    if isapprox(ymax, 90; rtol = 1e-4)
        ymax = 90e0
    end

    try
    
    (umin, umax), (vmin, vmax) = Proj.bounds(f, (xmin,xmax), (ymin,ymax))

    return Rect(Vec2(T(umin), T(vmin)) ./ PROJ_RESCALE_FACTOR,
                Vec2(T(umax-umin), T(vmax-vmin)) ./ PROJ_RESCALE_FACTOR)
    catch e
        @show r
        rethrow(e)
    end
end

function Makie.apply_transform(f::Proj.Transformation, r::Rect3{T}) where {T}
    r2 = Rect2{T}(r)
    tr2 = Makie.apply_transform(f, r2)
    return Rect3{T}((tr2.origin..., r.origin[3]), (tr2.widths..., r.widths[3]))
end

_apply_inverse(itrans, p) = Makie.apply_transform(itrans, p .* PROJ_RESCALE_FACTOR) .* PROJ_RESCALE_FACTOR

function Makie.inverse_transform(trans::Proj.Transformation)
    itrans = Base.inv(trans)
    return Makie.PointTrans{2}(Base.Fix1(_apply_inverse, itrans))
end

function Makie.apply_transform(t::Makie.PointTrans{2, Base.Fix1{typeof(GeoMakie._apply_inverse), Proj.Transformation}}, r::Rect2{T}) where T
    f = t.f.x
    xmin, ymin = minimum(r) .* PROJ_RESCALE_FACTOR
    xmax, ymax = maximum(r) .* PROJ_RESCALE_FACTOR
    try
    
        (umin, umax), (vmin, vmax) = Proj.bounds(f, (xmin,xmax), (ymin,ymax))

    if isinf(umin) || abs(umin) > 1e8
        umin = -180.0
    end
    if isinf(umax) || abs(umax) > 1e8
        umax = 180.0
    end

    if isinf(vmin) || abs(vmin) > 1e8
        vmin = -90.0
    end
    if isinf(vmax) || abs(vmax) > 1e8
        vmax = 90.0
    end

    if isapprox(umin, -180, rtol = 1e-4)
        umin - -180e0
    end
    if isapprox(umax, 180; rtol = 1e-4)
        umax = 180e0
    end
    if isapprox(vmin, -90; rtol = 1e-4)
        vmin = -90e0
    end
    if isapprox(vmax, 90; rtol = 1e-4)
        vmax = 90e0
    end

    return Rect(Vec2(T(umin), T(vmin)),
                Vec2(T(umax-umin), T(vmax-vmin)))
    catch e
        @show r
        rethrow(e)
    end
end

function Makie.apply_transform(t::Makie.PointTrans{2, Base.Fix1{typeof(GeoMakie._apply_inverse), Proj.Transformation}}, r::Rect3{T}) where {T}
    r2 = Rect2{T}(r)
    tr2 = Makie.apply_transform(t, r2)
    return Rect3{T}((tr2.origin..., r.origin[3]), (tr2.widths..., r.widths[3]))
end

Base.isfinite(x::Union{GeometryBasics.AbstractPoint, GeometryBasics.Vec}) = all(isfinite, x)
# Some minor type piracy

function (transformation::Proj.Transformation)(coord::Point{N, T}) where {N, T <: Real}
    @assert 2 ≤ N ≤ 4
    return Point{N, T}(transformation(coord.data))
end

function (transformation::Proj.Transformation)(coord::Vec{N, T}) where {N, T <: Real}
    @assert 2 ≤ N ≤ 4
    return Vec{N, T}(transformation(coord.data))
end


function find_transform_limits(ptrans; lonrange = (-180, 180), latrange = (-90, 90))
    # Search for a good bound with decent accuracy
    lons = Float64.(LinRange(lonrange..., 360 * 4))
    lats = Float64.(LinRange(latrange..., 180 * 4))
    # avoid PROJ wrapping 180 to -180
    # lons[1]   = nextfloat(lons[1])   |> nextfloat |> nextfloat# |> nextfloat |> nextfloat
    # lons[end] = prevfloat(lons[end]) |> prevfloat |> prevfloat# |> prevfloat |> prevfloat
    # lats[1]   = nextfloat(lats[1])   |> nextfloat |> nextfloat#
    # lats[end] = prevfloat(lats[end]) |> prevfloat |> prevfloat#

    points = Point2{Float64}.(lons, lats')
    tpoints = ptrans.(points)
    itpoints = Point2{Float64}.(inv(ptrans).(tpoints))

    inf_cont_mask = isfinite.(itpoints)

    finite_inds = findall(isfinite, itpoints)

    f = Figure(resolution = (1200, 1000))
    Label(f[1, 1]; text = "$ptrans", word_wrap = true, justification = :left, tellheight = true, tellwidth = false)
    a, p = Makie.contour(f[2, 1], ..(lonrange...), ..(latrange...), inf_cont_mask; colorrange = (0,1), colormap = [:gray90, :green], axis = (title = "Valid region", aspect = DataAspect()))
    display(f)
    # Main.@infiltrate

    min, max = getindex.(Ref(itpoints), finite_inds[[begin, end]])


    return (min[1], max[1], min[2], max[2])
end

"""
    geospine_obs(ga::GeoAxis; padding = 10, density = 2)::Observable{Vector{Point2f}}

This function returns an Observable which represents the true border of the geoaxis in question.  
The observable is lifted on the geoaxis's transform, scene, and final (transformed) limits.

## Approach

Basically, we create a grid of density `density` of the Scene's pixel area, 
in transformed space (with some `padding` added to each side).  Then, we 
apply the inverse of `ga.transform_func` to the grid positions, which 
projects them from transformed to input (lon/lat) space.  This yields
finite values where the transformed values correspond to some lon/lat,
and infinite values where they do not.

These values form a Boolean mask.  We find the contour of this mask at level 0.5, 
then return that as a vector of Point2f in the pixelspace of `ga.blockscene`, to which
this can be plotted.

## Keyword arguments
- `padding`: Pads each side by that amount of space in transformed space.  Helps with transforms.
- `density`: The pixel density of the grid - each real pixel will have `density^2` grid cells.

"""
function geospine_obs(ga::GeoAxis; padding = 10, density = 2)
    # how to find the border of a projected area in nonlinearly transformed space:
    # operate in transformed space, in the Scene's limits
    # project to input space
    # whatever is infinite/invalid is then outside lat long space
    # from this, border/spine line is just the contour at 0.5, if valid → true and invalid → false.
    spineline = Observable(Point2f[])
    lift(ga.transform_func, ga.scene.px_area, ga.finallimits) do ptrans, pxarea, finallims
        # empty the spineline
        empty!(spineline.val)
        # TODO: if you zoom in sufficiently, this should somehow correct itself or otherwise not display
        # but how do you do that?
        # maybe have some criterion - either geospine or normal spines, but not both
        # create a grid of the Scene's pixel area, in transformed space
        xmin, ymin = minimum(finallims)
        xmax, ymax = maximum(finallims)
        xs = Float64.(LinRange(xmin - padding, xmax + padding, round(Int, (pxarea.widths[1] + 2 * padding) * 2))) # resolution is 2x pixel resolution, no particular reason.
        ys = Float64.(LinRange(ymin - padding, ymax + padding, round(Int, (pxarea.widths[2] + 2 * padding) * 2)))
        # points in transformed space
        tpoints = Point2{Float64}.(xs, ys')
        # points in lon/lat space
        itpoints = Makie.apply_transform(Makie.inverse_transform(ptrans), tpoints)
        
        finite_mask = isfinite.(itpoints)

        # there are only two possible values in the finite mask.
        # so, we can compute the correct spine contour.
        spine_contour = Makie.Contours.contours(xs, ys, Float32.(finite_mask), [0.5f0])
        for element in Makie.Contours.lines(first(Makie.Contours.levels(spine_contour)))
            append!(
                spineline.val, 
                Point2f.(Makie.project.((camera(ga.scene),), :data, :pixel, element.vertices)) .+ (pxarea.origin,)
            )
        end

        notify(spineline)

    end

    return spineline
end


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

function longitude_format(nums)
    labels = fill("", length(nums))
    for i in 1:length(nums)
        east_or_west = if nums[i] < 0
            'W'
        elseif nums[i] > 0
            'E'
        else
            ' '
        end
        labels[i] = if round(nums[i]) == nums[i]
            string(Int(abs(nums[i])), "ᵒ $east_or_west")
        else
            string(abs(nums[i]), "ᵒ $east_or_west")
        end
    end
    return labels
end

function latitude_format(nums)
    labels = fill("", length(nums))
    for i in 1:length(nums)
        north_or_south = if nums[i] < 0
            'S'
        elseif nums[i] > 0
            'N'
        else
            ' '
        end
        labels[i] = if round(nums[i]) == nums[i]
            string(Int(abs(nums[i])), "ᵒ $north_or_south")
        else
            string(abs(nums[i]), "ᵒ $north_or_south")
        end
    end
    return labels
end

function _replace_if_automatic(typ::Type{T}, attribute::Symbol, auto) where T
    default_attr_vals = Makie.default_attribute_values(T, nothing)

    if to_value(get(default_attr_vals, attribute, automatic)) == automatic
        return auto
    else
        return to_value(default_attr_vals[attribute])
    end
end

# Project any point to coordinates in pixel space
function project_to_pixelspace(scene, transform_func, point::Point{N, T}) where {N, T}
    @assert N ≤ 3
    return Point{N, T}(
        Makie.project(
            # obtain the camera of the Scene which will project to its screenspace
            camera(scene),
            # go from dataspace (transformation applied to inputspace) to pixelspace
            :data, :pixel,
            # apply the transform to go from inputspace to dataspace
            Makie.apply_transform(
                transform_func,
                point
            )
        )
    )
end

function project_to_pixelspace(scene, transform_func, points::AbstractVector{Point{N, T}}) where {N, T}
    Point{N, T}.(
        Makie.project.(
            # obtain the camera of the Scene which will project to its screenspace
            Ref(Makie.camera(scene)),
            # go from dataspace (transformation applied to inputspace) to pixelspace
            Ref(:data), Ref(:pixel),
            # apply the transform to go from inputspace to dataspace
            Makie.apply_transform(
                transform_func,
                points
            )
        )
    )
end

function text_bbox(textstring::AbstractString, fontsize::Union{AbstractVector, Number}, font, fonts, align, rotation, justification, lineheight)
    glyph_collection = Makie.layout_text(
            textstring, fontsize,
            string(font), fonts, align, rotation, justification, lineheight,
            RGBAf(0,0,0,0), RGBAf(0,0,0,0), 0f0, 0f0
        )

    return Rect2f(Makie.boundingbox(glyph_collection, Point3f(0), Makie.to_rotation(rotation)))
end

function find_outvec(scene, tickcoord_in_inputspace, tickcoord_in_dataspace, Δs)
end

function rotmat(θ)
    return Mat{2, 2}(cos(θ), sin(θ), -sin(θ), cos(θ))
end
# Direction finder - find how to displace the tick so that it is out of the axis
function directional_pad(scene, transform_func, limits, tickcoord_in_inputspace, ticklabel::AbstractString, tickpad, ticksize, tickfont, tickrotation; ds = 0.01)
    # Define shorthand functions for dev purposes - these can be removed before release
    tfunc = Base.Fix1(Makie.apply_transform, transform_func)
    inv_tfunc = Base.Fix1(Makie.apply_transform, Makie.inverse_transform(transform_func))
    # convert tick coordinate to dataspace
    tickcoord_in_dataspace = tfunc(tickcoord_in_inputspace)
    # determine direction to go in order to stay inbounds.
    xdir = tickcoord_in_inputspace[1] < 0 ? +1 : -1
    ydir = tickcoord_in_inputspace[2] < 0 ? +1 : -1
    Δs = iszero(sum(tickpad)) ? Vec2f(0) : Vec2f(xdir, ydir) .* tickpad ./ (sum(tickpad)) * ds
    
    # find the x and y directions
    # multiply by the sign in order to have them going outwards at any point
    Σp = sign(sum(Δs)) * inv_tfunc(tickcoord_in_dataspace + Δs)
    # project back to pixel space
    pixel_Δx, pixel_Δy = project_to_pixelspace(scene, transform_func, Σp) - project_to_pixelspace(scene, transform_func, tickcoord_in_inputspace)
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
    fonts = theme(scene, :fonts)
    extents = text_bbox(
        ticklabel, ticksize,
        tickfont, fonts, Vec2f(0), tickrotation,
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

    !xvisible && !yvisible && return

    combined_positions = vcat(xpositions, ypositions)

    if !xvisible
        nx = 0
        combined_positions = ypositions
    elseif !yvisible
        ny = 0
        combined_positions = xpositions
    end

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

#=
    @hijack_observable name::Symbol

Assuming the presence of a `hijacked_observables::Dict{Symbol, Any}` and `ax::Axis`,
hijacks the Observable `ax[name]` and redirects all its updates to `hijacked_observables[name]`,
while keeping `ax[name]` as `false`.

More technically, this macro injects a function at the beginning of `ax[name].listeners`, which
forwards whatever update was made to `hijacked_observables[name]`, and sets `ax[name].val = false`.
Thus, even though the rest of the listeners will continue to receive updates from this observable
(in case there is a need for it to remain), its value will remain `false`.
=#
macro hijack_observable(name)
    return esc(quote
        getproperty(ax, $name)[] = $(false)
        hijacked_observables[$name] = Observable($(true))
        __listener = on(getproperty(ax, $name); update = true, priority = typemax(Int)) do hijacked_obs_value
            hijacked_observables[$name][] = hijacked_obs_value
            getproperty(ax, $name).val = $(false)
        end
        getproperty(ax, $name)[] = $(false)
        hijacked_observables[$name][] = $(true)

    end)

end
