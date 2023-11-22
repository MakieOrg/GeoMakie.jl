
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
    # from this, the border/spine line is just the contour at 0.5,
    # if valid → true and invalid → false.
    spineline = Observable(Point2f[])
    lift(ga.source_projection, ga.target_projection, ga.scene.viewport, ga.finallimits) do src, tgt, pxarea, finallims
        println("hii!?")
        @time begin
            ptrans = create_transform(tgt, src)
            # empty the spineline
            empty!(spineline.val)
            xs, ys, finite_mask = get_finite_mask_of_projection(ga.scene, ptrans, pxarea, finallims; padding, density)
            # if padding != 0
            #     # bottom
            #     finite_mask[1:padding, :] .= false
            #     # top
            #     finite_mask[(end-padding):end, :] .= false
            #     # left
            #     finite_mask[:, 1:padding] .= false
            #     # right
            #     finite_mask[:, (end-padding):end] .= false
            # end

            # there are only two possible values in the finite mask.
            # so, we can compute the correct spine contour.
            spine_contour = Makie.Contours.contours(xs, ys, Float32.(finite_mask), [0.5f0]#=replace(finite_mask, Inf => 1e38), [1e37]=#)
            # since we know there's only one level, instead of iterating through all levels,
            # we can skip that and iterate only through the first.
            for element in Makie.Contours.lines(first(Makie.Contours.levels(spine_contour)))
                append!(
                    spineline.val,
                    Point2f.(element.vertices)
                )
                push!(spineline.val, Point2f(NaN))
            end
            # we've constructed the spine line, now start the update.
            notify(spineline)

        end

        return spineline
    end
end

function valid_longlat(point::Point2)
    isfinite(point) &&
    -180 ≤ point[1] ≤ 180 &&
    -90 ≤ point[2] ≤ 90
end

"""
    get_finite_mask_of_projection(scene, transform_func, pxarea, finallims; padding = 10, density = 2)
    get_finite_mask_of_projection(ga::GeoAxis)

Returns `(xs::LinRange, ys::LinRange, zs::Matrix{Bool})`, where xs and ys are in pixel space.
"""
function get_finite_mask_of_projection(scene, transform_func, pxarea; padding = 10, density = 2, display = false)
    # TODO: if you zoom in sufficiently, this should somehow correct itself or otherwise not display
    # but how do you do that?
    # maybe have some criterion - either geospine or normal spines, but not both
    # create a grid of the Scene's pixel area, in transformed space
    # TODO: apply padding in pixelspace, then project down to transformed space.
    minimum_in_pixelspace = Point2f(0) .- padding
    maximum_in_pixelspace = widths(pxarea) .+ padding
    xmin, ymin = Makie.project(camera(scene), :pixel, :data, minimum_in_pixelspace)
    xmax, ymax = Makie.project(camera(scene), :pixel, :data, maximum_in_pixelspace)
    xs = Float64.(LinRange(xmin, xmax, round(Int, abs(xmax - xmin) * density))) # resolution is 2x pixel resolution, no particular reason.
    ys = Float64.(LinRange(ymin, ymax, round(Int, abs(ymax - ymin) * density)))

    # points in transformed space
    tpoints = Point2{Float64}.(xs, ys')
    # points in lon/lat space
    itpoints = Makie.apply_transform(Makie.inverse_transform(transform_func), tpoints)

    # possibly, to correct for the padding issue, set every pixel outside the scene
    # to false, i.e., infinite.  This would make a square each time...
    finite_mask = valid_longlat.(itpoints)
    return (
        xs,
        ys,
        finite_mask # sum.(map(x -> x .^ 2, itpoints))
    )
end

get_finite_mask_of_projection(ga::GeoAxis; padding = 10, density = 2, display = false) = get_finite_mask_of_projection(ga.scene, create_transform(ga.target_projection[], ga.source_projection[]), ga.scene.viewport[], ga.finallimits[]; padding, density, display)


# # How to get frame spines
# - Intersect the transformed bbox with the frame spines in latlong space
# Use a state machine - on first intersection, switch, then switch again, so on and so forth.
# iterate along the latlong spine
# if latlong spine is all within the transformed space bbox then use latlong spine
# if transformed space bbox is within the latlong spine, then use transformed space bbox
# so on and so forth, handle intersections as necessary
# no matter the spine, ticks are located at the intersections of the gridlines and the spine
#
