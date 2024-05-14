#=
# GeoAxis Makie integration
=#

# Anything in this file was directly taken from Makie/makielayout/blocks/axis.jl
# TODO, refactor axis.jl to make it easier to extend

import Makie: xautolimits, yautolimits, autolimits, getxlimits, getylimits, getlimits

function axis_setup!(axis::GeoAxis)
    # initialize either with user limits, or pick defaults based on scales
    # so that we don't immediately error
    targetlimits = Observable{Rect2d}(Makie.defaultlimits(axis.limits[], identity, identity))

    finallimits = Observable{Rect2d}(targetlimits[]; ignore_equal_values=true)
    setfield!(axis, :targetlimits, targetlimits)
    setfield!(axis, :finallimits, finallimits)
    topscene = axis.blockscene
    scenearea = Makie.sceneareanode!(axis.layoutobservables.computedbbox, finallimits, axis.aspect)
    scene = Scene(topscene, viewport=scenearea)
    axis.scene = scene
    setfield!(scene, :float32convert, Makie.Float32Convert())
    onany(scene, scene.transformation.transform_func, finallimits, axis.xreversed, axis.yreversed) do transform_func, finallimits, xreversed, yreversed
        Makie.update_axis_camera(scene, transform_func, finallimits, xreversed, yreversed)
    end
    notify(axis.layoutobservables.suggestedbbox)
    Makie.register_events!(axis, scene)
    on(scene, axis.limits) do _
        Makie.reset_limits!(axis)
    end
    onany(scene, scene.viewport, targetlimits) do _, _
        Makie.adjustlimits!(axis)
    end

    return scene
end


"""
    reset_limits!(axis; xauto = true, yauto = true)

Resets the axis limits depending on the value of `axis.limits`.
If one of the two components of limits is nothing,
that value is either copied from the targetlimits if `xauto` or `yauto` is false,
respectively, or it is determined automatically from the plots in the axis.
If one of the components is a tuple of two numbers, those are used directly.
"""
function Makie.reset_limits!(axis::GeoAxis; xauto = true, yauto = true)
    mlims = Makie.convert_limit_attribute(axis.limits[])

    mxlims, mylims = mlims::Tuple{Any, Any}

    targetlims = axis.targetlimits[]
    needs_transform = [false, false, false, false] # xmin, xmax, ymin, ymax
    xlims = if isnothing(mxlims) || mxlims[1] === nothing || mxlims[2] === nothing
        l = if xauto
            xautolimits(axis)
        else
            minimum(targetlims)[1], maximum(targetlims)[1]
        end
        if mxlims === nothing
            l
        else
            lo = if mxlims[1] === nothing
                l[1]
            else
                needs_transform[1] = true
                mxlims[1]
            end
            hi = if mxlims[2] === nothing
                l[2]
            else
                needs_transform[2] = true
                mxlims[2]
            end
            (lo, hi)
        end
    else
        needs_transform[1:2] .= true
        convert(Tuple{Float64, Float64}, tuple(mxlims...))
    end
    ylims = if isnothing(mylims) || mylims[1] === nothing || mylims[2] === nothing
        l = if yauto
            yautolimits(axis)
        else
            minimum(targetlims)[2], maximum(targetlims)[2]
        end
        if mylims === nothing
            l
        else
            lo = if mylims[1] === nothing
                l[1]
            else
                needs_transform[3] = true
                mylims[1]
            end
            hi = if mylims[2] === nothing
                l[2]
            else
                needs_transform[4] = true
                mylims[2]
            end
            (lo, hi)
        end
    else
        needs_transform[3:4] .= true
        convert(Tuple{Float64, Float64}, tuple(mylims...))
    end

    if !(xlims[1] <= xlims[2])
        error("Invalid x-limits as xlims[1] <= xlims[2] is not met for $xlims.")
    end
    if !(ylims[1] <= ylims[2])
        error("Invalid y-limits as ylims[1] <= ylims[2] is not met for $ylims.")
    end
    # Limits set by the user are always in the source input space, so we need to transform them
    # This is a bit complicated, since the transform function needs x + y, but you may e.g.
    # do `xlimits!(axis, 1, 10)`, so that we don't have y values
    if any(needs_transform)
        trans = axis.transform_func[]
        # Fallback to untransformed data limits
        # TODO, is this always correct?
        transformed_rect = boundingbox(axis.scene)
        untransformed_rect = Makie.apply_transform(axis.inv_transform_func[], transformed_rect)
        fxlim, fylim = Makie.limits(untransformed_rect)
        fallback_lims = [fxlim..., fylim...]
        new_lims = [xlims..., ylims...]
        # Replace values that are already transformed with untransformed values
        untrans = map(needs_transform, fallback_lims, new_lims) do needs, fallback, new
            needs ? new : fallback
        end
        # Now that all values are in source input space, we can transform them again.
        # We use a rectangle to transform, since that allows us to use Proj's densification.
        mini, maxi = Makie.apply_transform(trans, Rect2d(Vec2d(untrans[1], untrans[3]), Vec2d(untrans[2] - untrans[1], untrans[4] - untrans[3]))) |> extrema
        trans_lims = [mini[1], maxi[1], mini[2], maxi[2]]
        untrans = map(needs_transform, trans_lims, new_lims) do needs, tlim, new
            needs ? tlim : new
        end
        xlims = (untrans[1], untrans[2])
        ylims = (untrans[3], untrans[4])
    end

    axis.targetlimits[] = Makie.BBox(xlims..., ylims...) # this is in TRANSFORMED space
    nothing
end

function Makie.autolimits(axis::GeoAxis, dim::Integer)
    # try getting x limits for the axis and then union them with linked axes
    lims = Makie.getlimits(axis, dim)
    dimsym = dim == 1 ? :x : :y
    margin = getproperty(axis, Symbol(dimsym, :autolimitmargin))[]
    if !isnothing(lims)
        lims = Makie.expandlimits(lims, margin[1], margin[2], identity)
    end
    # if no limits have been found, use the targetlimits directly
    if isnothing(lims)
        lims = Makie.limits(axis.targetlimits[], dim)
    end
    return lims
end

xautolimits(axis::GeoAxis) = autolimits(axis, 1)
yautolimits(axis::GeoAxis) = autolimits(axis, 2)

function br_getindex(vector::AbstractVector, idx::CartesianIndex, dim::Int)
    return vector[Tuple(idx)[dim]]
end

function br_getindex(matrix::AbstractMatrix, idx::CartesianIndex, dim::Int)
    return matrix[idx]
end

function get_point_xyz(linear_indx::Int, indices, X, Y, Z)
    idx = indices[linear_indx]
    x = br_getindex(X, idx, 1)
    y = br_getindex(Y, idx, 2)
    z = Z[linear_indx]
    if z isa Number
        return Point3d(x, y, z)
    else
        return Point3d(x, y, 0)
    end
end

function get_point_xyz(linear_indx::Int, indices, X, Y)
    idx = indices[linear_indx]
    x = br_getindex(X, idx, 1)
    y = br_getindex(Y, idx, 2)
    return Point3d(x, y, 0.0)
end

function _point_iterator(plot::Union{Image,Heatmap,Surface})
    Z = plot[3][]
    X = to_vector(plot[1][], size(Z, 1), Float64)
    Y = to_vector(plot[2][], size(Z, 2), Float64)
    indices = CartesianIndices(Z)
    return Point3d[get_point_xyz(idx, indices, X, Y, Z) for idx in 1:length(Z)]
end

function _point_iterator(list::AbstractVector)
    if length(list) == 1
        # save a copy!
        return _point_iterator(list[1])
    else
        points = Point3d[]
        for elem in list
            for point in _point_iterator(elem)
                push!(points, to_ndim(Point33d, point, 0))
            end
        end
        return points
    end
end

function _point_iterator(plot::Plot)
    if isempty(plot.plots)
        return Makie.point_iterator(plot)
    end
    return _point_iterator(plot.plots)
end

# function iterate_transformed(plot::Plot)
#     points = _point_iterator(plot)
#     t = Makie.transformation(plot)
#     model = Makie.model_transform(t)
#     trans_func = Makie.transform_func(t)
#     return Makie.iterate_transformed(points, model, to_value(get(plot, :space, :data)), trans_func)
# end


function limits_from_transformed_points(points_iterator)
    isempty(points_iterator) && return Rect3d()
    first, rest = Iterators.peel(points_iterator)
    bb = foldl(Makie._update_rect, rest, init = Rect3{Float64}(first, zero(first)))
    return bb
end

# include bbox from scaled markers
function limits_from_transformed_points(positions, scales, rotations, element_bbox)
    isempty(positions) && return Rect3d()

    first_scale = attr_broadcast_getindex(scales, 1)
    first_rot = attr_broadcast_getindex(rotations, 1)
    full_bbox = Ref(first_rot * (element_bbox * first_scale) + first(positions))
    for (i, pos) in enumerate(positions)
        scale, rot = attr_broadcast_getindex(scales, i), attr_broadcast_getindex(rotations, i)
        transformed_bbox = rot * (element_bbox * scale) + pos
        update_boundingbox!(full_bbox, transformed_bbox)
    end

    return full_bbox[]
end

function transformed_limits(scenelike, exclude=(p) -> false)
    bb_ref = Base.RefValue(Rect3d())
    Makie.foreach_plot(scenelike) do plot
        if !exclude(plot)
            box = limits_from_transformed_points(Makie.iterate_transformed(plot))
            Makie.update_boundingbox!(bb_ref, box)
        end
    end
    return bb_ref[]
end

function Makie.getlimits(la::GeoAxis, dim)
    # find all plots that don't have exclusion attributes set
    # for this dimension
    if !(dim in (1, 2))
        error("Dimension $dim not allowed. Only 1 or 2.")
    end
    axis_plots = Set(values(la.elements))
    function exclude(plot)
        # dont use axis decorations!
        plot in axis_plots && return true
        # only use plots with autolimits = true
        to_value(get(plot, dim == 1 ? :xautolimits : :yautolimits, true)) || return true
        # only if they use data coordinates
        Makie.is_data_space(to_value(get(plot, :space, :data))) || return true
        # only use visible plots for limits
        return !to_value(get(plot, :visible, true))
    end
    # get all data limits, minus the excluded plots
    boundingbox = Makie.boundingbox(la.scene, exclude)
    # if there are no bboxes remaining, `nothing` signals that no limits could be determined
    Makie.isfinite_rect(boundingbox) || return nothing

    # otherwise start with the first box
    mini, maxi = minimum(boundingbox), maximum(boundingbox)
    return (mini[dim], maxi[dim])
end

getxlimits(la::GeoAxis) = getlimits(la, 1)
getylimits(la::GeoAxis) = getlimits(la, 2)


function Makie.RectangleZoom(f::Function, ax::GeoAxis; kw...)
    r = Makie.RectangleZoom(f; kw...)
    selection_vertices = lift(Makie._selection_vertices, Observable(ax.scene), ax.finallimits, r.rectnode)
    # manually specify correct faces for a rectangle with a rectangle hole inside
    faces = [1 2 5; 5 2 6; 2 3 6; 6 3 7; 3 4 7; 7 4 8; 4 1 8; 8 1 5]
    # plot to blockscene, so ax.scene stays exclusive for user plots
    # That's also why we need to pass `ax.scene` to _selection_vertices, so it can project to that space
    mesh = mesh!(ax.blockscene, selection_vertices, faces, color=(:black, 0.2), shading = NoShading,
        inspectable=false, visible=r.active, transparency=true)
    # translate forward so selection mesh and frame are never behind data
    translate!(mesh, 0, 0, 100)
    return r
end

function Makie.RectangleZoom(ax::GeoAxis; kw...)
    return Makie.RectangleZoom(ax; kw...) do newlims
        if !(0 in widths(newlims))
            ax.targetlimits[] = newlims
        end
        return
    end
end

Makie.interactions(ax::GeoAxis) = ax.interactions

Makie.timed_ticklabelspace_reset(ax::GeoAxis, reset_timer::Ref,
    prev_xticklabelspace::Ref, prev_yticklabelspace::Ref, threshold_sec::Real) = nothing

function Makie.update_state_before_display!(ax::GeoAxis)
    Makie.reset_limits!(ax)
    return
end



# EVENTS

function Makie.process_interaction(r::Makie.RectangleZoom, event::MouseEvent, ax::GeoAxis)

    # TODO: actually, the data from the mouse event should be transformed already
    # but the problem is that these mouse events are generated all the time
    # and outside of log axes, you would quickly run into domain errors
    transf = Makie.transform_func(ax)
    inv_transf = Makie.inverse_transform(transf)

    if isnothing(inv_transf)
        @warn "Can't rectangle zoom without inverse transform" maxlog = 1
        # TODO, what can we do without inverse?
        return Consume(false)
    end

    if event.type === MouseEventTypes.leftdragstart
        data = Makie.apply_transform(inv_transf, event.data)
        prev_data = Makie.apply_transform(inv_transf, event.prev_data)

        r.from = prev_data
        r.to = data
        r.rectnode[] = Makie._chosen_limits(r, ax)
        r.active[] = true
        return Consume(true)

    elseif event.type === MouseEventTypes.leftdrag
        # clamp mouse data to shown limits
        rect = Makie.apply_transform(transf, ax.finallimits[])
        data = Makie.apply_transform(inv_transf, Makie.rectclamp(event.data, rect))

        r.to = data
        r.rectnode[] = Makie._chosen_limits(r, ax)
        return Consume(true)

    elseif event.type === MouseEventTypes.leftdragstop
        try
            r.callback(r.rectnode[])
        catch e
            @warn "error in rectangle zoom" exception = e
        end
        r.active[] = false
        return Consume(true)
    end

    return Consume(false)
end

function Makie.process_interaction(r::Makie.RectangleZoom, event::KeysEvent, ax::GeoAxis)
    r.restrict_y = Keyboard.x in event.keys
    r.restrict_x = Keyboard.y in event.keys
    r.active[] || return Consume(false)

    r.rectnode[] = Makie._chosen_limits(r, ax)
    return Consume(true)
end

function Makie.process_interaction(l::Makie.LimitReset, event::MouseEvent, ax::GeoAxis)

    if event.type === MouseEventTypes.leftclick
        if ispressed(ax.scene, Keyboard.left_control)
            if ispressed(ax.scene, Keyboard.left_shift)
                autolimits!(ax)
            else
                reset_limits!(ax)
            end
            return Consume(true)
        end
    end

    return Consume(false)
end

function Makie.process_interaction(s::Makie.ScrollZoom, event::Makie.ScrollEvent, ax::GeoAxis)
    # use vertical zoom
    zoom = event.y

    tlimits = ax.targetlimits
    xzoomlock = ax.xzoomlock
    yzoomlock = ax.yzoomlock
    xzoomkey = ax.xzoomkey
    yzoomkey = ax.yzoomkey

    scene = ax.scene
    e = Makie.events(scene)
    cam = Makie.camera(scene)

    if zoom != 0
        pa = Makie.pixelarea(scene)[]

        z = (1.0f0 - s.speed)^zoom

        mp_axscene = Vec4f((e.mouseposition[] .- pa.origin)..., 0, 1)

        # first to normal -1..1 space
        mp_axfraction = (cam.pixel_space[]*mp_axscene)[Vec(1, 2)] .*
                        # now to 1..-1 if an axis is reversed to correct zoom point
                        (-2 .* ((ax.xreversed[], ax.yreversed[])) .+ 1) .*
                        # now to 0..1
                        0.5 .+ 0.5

        transf = identity
        tlimits_trans = Makie.apply_transform(transf, tlimits[])

        xorigin = tlimits_trans.origin[1]
        yorigin = tlimits_trans.origin[2]

        xwidth = tlimits_trans.widths[1]
        ywidth = tlimits_trans.widths[2]

        newxwidth = xzoomlock[] ? xwidth : xwidth * z
        newywidth = yzoomlock[] ? ywidth : ywidth * z

        newxorigin = xzoomlock[] ? xorigin : xorigin + mp_axfraction[1] * (xwidth - newxwidth)
        newyorigin = yzoomlock[] ? yorigin : yorigin + mp_axfraction[2] * (ywidth - newywidth)

        newrect_trans = if ispressed(scene, xzoomkey[])
            Rect2d(newxorigin, yorigin, newxwidth, ywidth)
        elseif ispressed(scene, yzoomkey[])
            Rect2d(xorigin, newyorigin, xwidth, newywidth)
        else
            Rect2d(newxorigin, newyorigin, newxwidth, newywidth)
        end

        inv_transf = Makie.inverse_transform(transf)
        tlimits[] = Makie.apply_transform(inv_transf, newrect_trans)
    end

    # NOTE this might be problematic if if we add scrolling to something like Menu
    return Consume(true)
end

Makie.transformation(ax::GeoAxis) = Makie.transformation(ax.scene)

function Makie.xlims!(ax::GeoAxis, xlims)
    if length(xlims) != 2
        error("Invalid xlims length of $(length(xlims)), must be 2.")
    elseif xlims[1] == xlims[2] && xlims[1] !== nothing
        error("Can't set x limits to the same value $(xlims[1]).")
    elseif all(x -> x isa Real, xlims) && xlims[1] > xlims[2]
        xlims = reverse(xlims)
        ax.xreversed[] = true
    else
        ax.xreversed[] = false
    end
    mlims = Makie.convert_limit_attribute(ax.limits[])

    ax.limits.val = (xlims, mlims[2])
    Makie.reset_limits!(ax; yauto=false)
    return nothing
end

function Makie.ylims!(ax::GeoAxis, ylims)
    if length(ylims) != 2
        error("Invalid ylims length of $(length(ylims)), must be 2.")
    elseif ylims[1] == ylims[2] && ylims[1] !== nothing
        error("Can't set y limits to the same value $(ylims[1]).")
    elseif all(x -> x isa Real, ylims) && ylims[1] > ylims[2]
        ylims = reverse(ylims)
        ax.yreversed[] = true
    else
        ax.yreversed[] = false
    end
    mlims = Makie.convert_limit_attribute(ax.limits[])
    ax.limits.val = (mlims[1], ylims)
    Makie.reset_limits!(ax; xauto=false)
    return nothing
end

function Makie.limits!(ax::GeoAxis, xlims, ylims)
    Makie.xlims!(ax, xlims)
    Makie.ylims!(ax, ylims)
    return
end

function Makie.hidexdecorations!(ax::GeoAxis; label = true, ticklabels = true, ticks = true,
    grid = true,#= minorgrid = true, minorticks = true=#)
    if label
        ax.xticklabelsvisible[] = false
    end
    if ticklabels
        ax.xticklabelsvisible[] = false
    end
    if ticks
        ax.xticksvisible[] = false
    end
    if grid
        ax.xgridvisible[] = false
    end
    #=if minorgrid
        ax.xminorgridvisible[] = false
    end
    if minorticks
        ax.xminorticksvisible[] = false
    end=#
    return
end

function Makie.hideydecorations!(ax::GeoAxis; label = true, ticklabels = true, ticks = true,
    grid = true,#= minorgrid = true, minorticks = true=#)
    if label
        ax.yticklabelsvisible[] = false
    end
    if ticklabels
        ax.yticklabelsvisible[] = false
    end
    if ticks
        ax.yticksvisible[] = false
    end
    if grid
        ax.ygridvisible[] = false
    end
    #=if minorgrid
        ax.yminorgridvisible[] = false
    end
    if minorticks
        ax.yminorticksvisible[] = false
    end=#
    return
end

Makie.hidedecorations!(ax::GeoAxis; kw...) = begin
    hidexdecorations!(ax; kw...)
    hideydecorations!(ax; kw...)
end
