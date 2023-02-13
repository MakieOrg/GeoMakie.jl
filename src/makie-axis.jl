# Anything in this file was directly taken from Makie/makielayout/blocks/axis.jl
# TODO, refactor axis.jl to make it easier to extend

import Makie: xautolimits, yautolimits, autolimits, getxlimits, getylimits, getlimits

# Lol, really GeometryBasics?
Base.convert(::Type{Rect2d}, x::Rect2) = Rect2d(x)

# Makie.xautolimits(ga::GeoAxis) = (-180, 180)
# Makie.yautolimits(ga::GeoAxis) = (-90, 90)


geodefaultlimits(axis::GeoAxis, limits) = geodefaultlimits(limits, axis.source_projection[], axis.target_projection[])

# override for the automatic case
function geodefaultlimits(axis::GeoAxis, ::Tuple{Nothing, Nothing})
    # if isassigned(axis.scene)
    #     transformed_data_limits = data_limits(axis.scene)
    #     need_auto_limits = any(isinf.(origin(transformed_data_limits))) || any(isinf.(widths(transformed_data_limits)))
    # else
        need_auto_limits = true
    # end

    if need_auto_limits
         # if the transformed data limits are infinite, nothing has been plotted
        return Makie.apply_transform(axis.transform_func[], Rect2d(-180, -90, 360, 180)) # TODO: make this figure out what the appropriate limits are automagically
    else
        return transformed_data_limits
    end
end

function geodefaultlimits(axis::GeoAxis, limits::Tuple{NTuple{2, <: Real}, Nothing})
    return Makie.apply_transform(axis.transform_func[], Rect2d(limits[1][1], -90, limits[1][2] - limits[1][1], 180))
end

function geodefaultlimits(axis::GeoAxis, limits::Tuple{ Nothing, NTuple{2, <: Real}})
    return Makie.apply_transform(axis.transform_func[], Rect2d(-180, limits[2][1], 360, limits[2][2] - limits[2][1]))
end

function geodefaultlimits(axis::GeoAxis, limits::Tuple)
    (xmin, xmax), (ymin, ymax) = limits
    return Makie.apply_transform(axis.transform_func[], Rect2d(xmin, ymin, xmax - xmin, ymax - ymin))
end

function geodefaultlimits(axis::GeoAxis, limits::Rect{2, <: Real})
    return Makie.apply_transform(axis.transform_func[], Rect2d(limits))
end

inputdefaultlimits(axis::GeoAxis, limits) = limits
inputdefaultlimits(axis::GeoAxis, limits::NTuple{2, Nothing}) = Rect2d(-180, -90, 360, 180)
inputdefaultlimits(axis::GeoAxis, limits::NTuple{2, <: NTuple{2, Nothing}}) = Rect2d(-180, -90, 360, 180)

function inputdefaultlimits(axis::GeoAxis, limits::Tuple{NTuple{2, <: Real}, Nothing})
    return Rect2d(limits[1][1], -90, limits[1][2] - limits[1][1], 180)
end

function inputdefaultlimits(axis::GeoAxis, limits::Tuple{ Nothing, NTuple{2, <: Real}})
    return Rect2d(-180, limits[2][1], 360, limits[2][2] - limits[2][1])
end

function inputdefaultlimits(axis::GeoAxis, limits::Tuple)
    (xmin, xmax), (ymin, ymax) = limits
    return Rect2d(xmin, ymin, xmax - xmin, ymax - ymin)
end

function inputdefaultlimits(axis::GeoAxis, limits::Rect{2, <: Real})
    return Rect2d(limits)
end


function axis_setup!(axis::GeoAxis)
    # initialize either with user limits, or pick defaults based on scales
    # so that we don't immediately error
    targetlimits = Observable{Rect2d}(geodefaultlimits(axis, axis.limits[]))
    finallimits = Observable{Rect2d}(targetlimits[]; ignore_equal_values=true)
    inputfinallimits = Observable{Union{Nothing, Rect2d}}(inputdefaultlimits(axis, axis.inputlimits[]); ignore_equal_values=true)
    setfield!(axis, :targetlimits, targetlimits)
    setfield!(axis, :finallimits, finallimits)
    setfield!(axis, :inputfinallimits, inputfinallimits)

    on(axis.inputlimits) do inputlims
        targetlimits[] = geodefaultlimits(axis, inputlims)
    end

    onany(finallimits, axis.transform_func, axis.inputlimits) do finallims, tfunc, inputlims
        @show finallims
        result = try
             Makie.apply_transform(Makie.inverse_transform(tfunc), finallims)
        catch e
            @warn "Error in inverse transforming finallims"
            inputdefaultlimits(axis, inputlims)
        end
        @show result
        inputfinallimits[] = result
    end
    notify(finallimits)

    # set up transformed limits
    # TODO get correct values rather than defaulting to all-Earth

    topscene = axis.blockscene
    scenearea = Makie.sceneareanode!(axis.layoutobservables.computedbbox, finallimits, DataAspect())
    scene = Scene(topscene, px_area=scenearea)
    axis.scene = scene
    onany(Makie.update_axis_camera, camera(scene), scene.transformation.transform_func, finallimits, axis.xreversed, axis.yreversed)
    notify(axis.layoutobservables.suggestedbbox)
    Makie.register_events!(axis, scene)
    on(axis.limits) do mlims
        reset_limits!(axis)
    end
    onany(scene.px_area, targetlimits) do pxa, lims
        Makie.adjustlimits!(axis)
    end
    fl = finallimits[]
    notify(axis.limits)
    if fl == finallimits[]
        notify(finallimits)
    end
    return scene
end

function Makie.autolimits!(ax::GeoAxis)
    ax.limits[] = (nothing, nothing)
    return
end

"""
    reset_limits!(axis; xauto = true, yauto = true)

Resets the axis limits depending on the value of `axis.limits`.
If one of the two components of limits is nothing,
that value is either copied from the targetlimits if `xauto` or `yauto` is false,
respectively, or it is determined automatically from the plots in the axis.
If one of the components is a tuple of two numbers, those are used directly.
"""
function Makie.reset_limits!(axis::GeoAxis; xauto = true, yauto = true, zauto = true)
    mlims = Makie.convert_limit_attribute(axis.limits[])

    mxlims, mylims = mlims::Tuple{Any, Any}

    xlims = if isnothing(mxlims) || mxlims[1] === nothing || mxlims[2] === nothing
        l = if xauto
            xautolimits(axis)
        else
            minimum(axis.targetlimits[])[1], maximum(axis.targetlimits[])[1]
        end
        if mxlims === nothing
            l
        else
            lo = mxlims[1] === nothing ? l[1] : mxlims[1]
            hi = mxlims[2] === nothing ? l[2] : mxlims[2]
            (lo, hi)
        end
    else
        convert(Tuple{Float64, Float64}, tuple(mxlims...))
    end
    ylims = if isnothing(mylims) || mylims[1] === nothing || mylims[2] === nothing
        l = if yauto
            yautolimits(axis)
        else
            minimum(axis.targetlimits[])[2], maximum(axis.targetlimits[])[2]
        end
        if mylims === nothing
            l
        else
            lo = mylims[1] === nothing ? l[1] : mylims[1]
            hi = mylims[2] === nothing ? l[2] : mylims[2]
            (lo, hi)
        end
    else
        convert(Tuple{Float64, Float64}, tuple(mylims...))
    end

    if !(xlims[1] <= xlims[2])
        error("Invalid x-limits as xlims[1] <= xlims[2] is not met for $xlims.")
    end
    if !(ylims[1] <= ylims[2])
        error("Invalid y-limits as ylims[1] <= ylims[2] is not met for $ylims.")
    end

    if round(xlims[1]) == -180
        xlims = (-180, xlims[2])
    end
    if round(xlims[2]) == 180
        xlims = (xlims[1], 180)
    end
    if round(ylims[1]) == -90
        ylims = (-90, ylims[2])
    end
    if round(ylims[2]) == 90
        ylims = (ylims[1], 90)
    end
    axis.targetlimits[] = Makie.BBox(xlims..., ylims...)

    nothing
end

function Makie.autolimits(axis::GeoAxis, dim::Integer)
    # try getting x limits for the axis and then union them with linked axes
    lims = Makie.getlimits(axis, dim)
    dimsym = dim == 1 ? :x : :y
    margin = getproperty(axis, Symbol(dimsym, :autolimitmargin))[]
    if !isnothing(lims)
        return lims
    end

    # if no limits have been found, use the targetlimits directly
    if isnothing(lims)
        _lims = geodefaultlimits(axis, (lims, lims))
        lims = (_lims.origin[dim], _lims.origin[dim] + _lims.widths[dim]) 
    end

    return lims
end

xautolimits(axis::GeoAxis) = autolimits(axis, 1)
yautolimits(axis::GeoAxis) = autolimits(axis, 2)


function getlimits(la::GeoAxis, dim)
    # find all plots that don't have exclusion attributes set
    # for this dimension
    if !(dim in (1, 2))
        error("Dimension $dim not allowed. Only 1 or 2.")
    end

    function exclude(plot)
        # only use plots with autolimits = true
        to_value(get(plot, dim == 1 ? :xautolimits : :yautolimits, true)) || return true
        # only if they use data coordinates
        Makie.is_data_space(to_value(get(plot, :space, :data))) || return true
        # only use visible plots for limits
        return !to_value(get(plot, :visible, true))
    end
    # get all data limits, minus the excluded plots
    boundingbox = Makie.data_limits(la.scene, exclude)
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
    mesh = mesh!(ax.blockscene, selection_vertices, faces, color=(:black, 0.2), shading=false,
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
    reset_limits!(ax)
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

        xscale = ax.xscale[]
        yscale = ax.yscale[]

        transf = (xscale, yscale)
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
