const Rect2d = Rect2{Float64}

Makie.@Block GeoAxis begin
    # "The Scene of the GeoAxis, which holds all plots."
    scene::Scene
    # "Targeted limits in input space"
    targetlimits::Observable{Rect2d}
    # "Final limits in input space"
    finallimits::Observable{Rect2d}
    inputfinallimits::Observable{Union{Nothing, Rect2d}}
    # The default transformation, to cache and save on calls to Proj!
    transform_func::Observable{Any}
    # interaction stuff
    mouseeventhandle::Makie.MouseEventHandle
    scrollevents::Observable{Makie.ScrollEvent}
    keysevents::Observable{Makie.KeysEvent}
    interactions::Dict{Symbol, Tuple{Bool, Any}}
    # "The plot elements of the axis - spines, ticks, labels, etc."
    elements::Dict{Symbol, Any}
    @attributes begin
        # Geoaxis/crs stuff
        "The default source CRS of input data"
        source_projection = "+proj=longlat +datum=WGS84"
        "The destination CRS for the axis"
        target_projection = "+proj=eqearth"
        "The number of points in all axis-decorating lines (effectively setting sampling density)"
        npoints = 1_000

        # appearance controls
        "The set of fonts which text in the axis should use.s"
        fonts = @inherit(:fonts, Makie.minimal_default.fonts)
        "The axis title string."
        title = ""
        "The font family of the title."
        titlefont = :bold
        "The title's font size."
        titlesize::Float64 = @inherit(:fontsize, 16f0)
        "The gap between axis and title."
        titlegap::Float64 = 4f0
        "Controls if the title is visible."
        titlevisible::Bool = true
        "The horizontal alignment of the title."
        titlealign::Symbol = :center
        "The color of the title"
        titlecolor::RGBAf = @inherit(:textcolor, :black)
        "The axis title line height multiplier."
        titlelineheight::Float64 = 1
        "The axis subtitle string."
        subtitle = ""
        "The font family of the subtitle."
        subtitlefont = :regular
        "The subtitle's font size."
        subtitlesize::Float64 = @inherit(:fontsize, 16f0)
        "The gap between subtitle and title."
        subtitlegap::Float64 = 0
        "Controls if the subtitle is visible."
        subtitlevisible::Bool = true
        "The color of the subtitle"
        subtitlecolor::RGBAf = @inherit(:textcolor, :black)
        "The axis subtitle line height multiplier."
        subtitlelineheight::Float64 = 1


        "The xlabel string."
        xlabel = ""
        "The ylabel string."
        ylabel = ""
        "The font family of the xlabel."
        xlabelfont = :regular
        "The font family of the ylabel."
        ylabelfont = :regular
        "The color of the xlabel."
        xlabelcolor::RGBAf = @inherit(:textcolor, :black)
        "The color of the ylabel."
        ylabelcolor::RGBAf = @inherit(:textcolor, :black)
        "The font size of the xlabel."
        xlabelsize::Float64 = @inherit(:fontsize, 16f0)
        "The font size of the ylabel."
        ylabelsize::Float64 = @inherit(:fontsize, 16f0)
        "Controls if the xlabel is visible."
        xlabelvisible::Bool = true
        "Controls if the ylabel is visible."
        ylabelvisible::Bool = true
        "The padding between the xlabel and the ticks or axis."
        xlabelpadding::Float64 = 3f0
        "The padding between the ylabel and the ticks or axis."
        ylabelpadding::Float64 = 5f0 # xlabels usually have some more visual padding because of ascenders, which are larger than the hadvance gaps of ylabels
        "The xlabel rotation in radians."
        xlabelrotation = Makie.automatic
        "The ylabel rotation in radians."
        ylabelrotation = Makie.automatic

        "The x (longitude) ticks - can be a vector or a Makie tick finding algorithm."
        xticks = Makie.automatic
        "The y (latitude) ticks - can be a vector or a Makie tick finding algorithm."
        yticks = Makie.automatic
        "Format for x (longitude) ticks."
        xtickformat = Makie.automatic
        "Format for y (latitude) ticks."
        ytickformat = Makie.automatic
        "The font family of the xticklabels."
        xticklabelfont = :regular
        "The font family of the yticklabels."
        yticklabelfont = :regular
        "The color of xticklabels."
        xticklabelcolor::RGBAf = @inherit(:textcolor, :black)
        "The color of yticklabels."
        yticklabelcolor::RGBAf = @inherit(:textcolor, :black)
        "The font size of the xticklabels."
        xticklabelsize::Float64 = @inherit(:fontsize, 16f0)
        "The font size of the yticklabels."
        yticklabelsize::Float64 = @inherit(:fontsize, 16f0)
        "Controls if the xticklabels are visible."
        xticklabelsvisible::Bool = true
        "Controls if the yticklabels are visible."
        yticklabelsvisible::Bool = true
        "The space reserved for the xticklabels."
        xticklabelspace::Union{Makie.Automatic, Float64} = Makie.automatic
        "The space reserved for the yticklabels."
        yticklabelspace::Union{Makie.Automatic, Float64} = Makie.automatic
        "The space between xticks and xticklabels."
        xticklabelpad::Float64 = 5f0
        "The space between yticks and yticklabels."
        yticklabelpad::Float64 = 5f0
        "The counterclockwise rotation of the xticklabels in radians."
        xticklabelrotation::Float64 = 0f0
        "The counterclockwise rotation of the yticklabels in radians."
        yticklabelrotation::Float64 = 0f0
        "The horizontal and vertical alignment of the xticklabels."
        xticklabelalign::Union{Makie.Automatic, Tuple{Symbol, Symbol}} = Makie.automatic
        "The horizontal and vertical alignment of the yticklabels."
        yticklabelalign::Union{Makie.Automatic, Tuple{Symbol, Symbol}} = Makie.automatic
        "The size of the xtick marks."
        xticksize::Float64 = 6f0
        "The size of the ytick marks."
        yticksize::Float64 = 6f0
        "Controls if the xtick marks are visible."
        xticksvisible::Bool = true
        "Controls if the ytick marks are visible."
        yticksvisible::Bool = true
        "The alignment of the xtick marks relative to the axis spine (0 = out, 1 = in)."
        xtickalign::Float64 = 0f0
        "The alignment of the ytick marks relative to the axis spine (0 = out, 1 = in)."
        ytickalign::Float64 = 0f0
        "The width of the xtick marks."
        xtickwidth::Float64 = 1f0
        "The width of the ytick marks."
        ytickwidth::Float64 = 1f0
        "The color of the xtick marks."
        xtickcolor::RGBAf = RGBf(0, 0, 0)
        "The color of the ytick marks."
        ytickcolor::RGBAf = RGBf(0, 0, 0)
        "The width of the axis spines."
        spinewidth::Float64 = 1f0
        "Controls if the x grid lines are visible."
        xgridvisible::Bool = true
        "Controls if the y grid lines are visible."
        ygridvisible::Bool = true
        "The width of the x grid lines."
        xgridwidth::Float64 = 1f0
        "The width of the y grid lines."
        ygridwidth::Float64 = 1f0
        "The color of the x grid lines."
        xgridcolor::RGBAf = RGBAf(0, 0, 0, 0.12)
        "The color of the y grid lines."
        ygridcolor::RGBAf = RGBAf(0, 0, 0, 0.12)
        "The linestyle of the x grid lines."
        xgridstyle = nothing
        "The linestyle of the y grid lines."
        ygridstyle = nothing
        "Controls if minor ticks on the x axis are visible"
        xminorticksvisible::Bool = false
        "The alignment of x minor ticks on the axis spine"
        xminortickalign::Float64 = 0f0
        "The tick size of x minor ticks"
        xminorticksize::Float64 = 4f0
        "The tick width of x minor ticks"
        xminortickwidth::Float64 = 1f0
        "The tick color of x minor ticks"
        xminortickcolor::RGBAf = :black
        "The tick locator for the x minor ticks"
        xminorticks = IntervalsBetween(2)
        "Controls if minor ticks on the y axis are visible"
        yminorticksvisible::Bool = false
        "The alignment of y minor ticks on the axis spine"
        yminortickalign::Float64 = 0f0
        "The tick size of y minor ticks"
        yminorticksize::Float64 = 4f0
        "The tick width of y minor ticks"
        yminortickwidth::Float64 = 1f0
        "The tick color of y minor ticks"
        yminortickcolor::RGBAf = :black
        "The tick locator for the y minor ticks"
        yminorticks = IntervalsBetween(2)
        "Controls if the x minor grid lines are visible."
        xminorgridvisible::Bool = false
        "Controls if the y minor grid lines are visible."
        yminorgridvisible::Bool = false
        "The width of the x minor grid lines."
        xminorgridwidth::Float64 = 1f0
        "The width of the y minor grid lines."
        yminorgridwidth::Float64 = 1f0
        "The color of the x minor grid lines."
        xminorgridcolor::RGBAf = RGBAf(0, 0, 0, 0.05)
        "The color of the y minor grid lines."
        yminorgridcolor::RGBAf = RGBAf(0, 0, 0, 0.05)
        "The linestyle of the x minor grid lines."
        xminorgridstyle = nothing
        "The linestyle of the y minor grid lines."
        yminorgridstyle = nothing
        "Controls if the bottom axis spine is visible."
        bottomspinevisible::Bool = true
        "Controls if the left axis spine is visible."
        leftspinevisible::Bool = true
        "Controls if the top axis spine is visible."
        topspinevisible::Bool = true
        "Controls if the right axis spine is visible."
        rightspinevisible::Bool = true
        "The color of the bottom axis spine."
        bottomspinecolor::RGBAf = :black
        "The color of the left axis spine."
        leftspinecolor::RGBAf = :black
        "The color of the top axis spine."
        topspinecolor::RGBAf = :black
        "The color of the right axis spine."
        rightspinecolor::RGBAf = :black

        # Layout observables
        "The horizontal alignment of the block in its suggested bounding box."
        halign = :center
        "The vertical alignment of the block in its suggested bounding box."
        valign = :center
        "The width setting of the block."
        width = Makie.Auto()
        "The height setting of the block."
        height = Makie.Auto()
        "Controls if the parent layout can adjust to this block's width"
        tellwidth::Bool = true
        "Controls if the parent layout can adjust to this block's height"
        tellheight::Bool = true
        "The align mode of the block in its parent GridLayout."
        alignmode = Makie.Inside()

        "The forced aspect ratio of the axis. `nothing` leaves the axis unconstrained, `DataAspect()` forces the same ratio as the ratio in data limits between x and y axis, `AxisAspect(ratio)` sets a manual ratio."
        aspect = Makie.DataAspect()
        autolimitaspect = nothing

        # old Axis stuff
        "Controls if the y axis goes upwards (false) or downwards (true)"
        yreversed::Bool = false
        "Controls if the x axis goes rightwards (false) or leftwards (true)"
        xreversed::Bool = false
        "The relative margins added to the autolimits in x direction."
        xautolimitmargin::Tuple{Float64,Float64} = (0f0, 0f0)
        "The relative margins added to the autolimits in y direction."
        yautolimitmargin::Tuple{Float64,Float64} = (0f0, 0f0)
        "The limits that the user has manually set. They are reinstated when calling `reset_limits!` and are set to nothing by `autolimits!`. Can be either a tuple (xlow, xhigh, ylow, high) or a tuple (nothing_or_xlims, nothing_or_ylims). Are set by `transformedlimits!` and zoom operations."
        limits = (nothing, nothing)
        "These are the input space limits (usually long/lat) which the user specifies, esp. for ticks etc.  They feed in to `limits` and thereby transformed limits."
        inputlimits = (nothing, nothing)


        "The button for panning."
        panbutton::Makie.Mouse.Button = Makie.Mouse.right
        "The key for limiting panning to the x direction."
        xpankey::Makie.Keyboard.Button = Makie.Keyboard.x
        "The key for limiting panning to the y direction."
        ypankey::Makie.Keyboard.Button = Makie.Keyboard.y
        "The key for limiting zooming to the x direction."
        xzoomkey::Makie.Keyboard.Button = Makie.Keyboard.x
        "The key for limiting zooming to the y direction."
        yzoomkey::Makie.Keyboard.Button = Makie.Keyboard.y

        "Locks interactive panning in the x direction."
        xpanlock::Bool = false
        "Locks interactive panning in the y direction."
        ypanlock::Bool = false
        "Locks interactive zooming in the x direction."
        xzoomlock::Bool = false
        "Locks interactive zooming in the y direction."
        yzoomlock::Bool = false
        "Controls if rectangle zooming affects the x dimension."
        xrectzoom::Bool = true
        "Controls if rectangle zooming affects the y dimension."
        yrectzoom::Bool = true
        "Do not set this - it's required for interop with Makie.  Has no effect."
        xscale = identity
        "Do not set this - it's required for interop with Makie.  Has no effect."
        yscale = identity
    end
end
Makie.can_be_current_axis(::GeoAxis) = true

function Makie.initialize_block!(axis::GeoAxis)

    ptrans = create_transform(axis.source_projection, axis.target_projection)
    setfield!(axis, :transform_func, ptrans)

    scene = axis_setup!(axis)
    setfield!(axis, :elements, Dict{Symbol,Any}())

    draw_geoaxis!(axis, axis.transform_func, axis.elements, false)


    subtitlepos = lift(scene.px_area, axis.titlegap, axis.titlealign, #=ax.xaxisposition, xaxis.protrusion=#; ignore_equal_values=true) do px_area,
        titlegap, align#=, xaxisposition, xaxisprotrusion=#

        align_val = if align === :center
            0.5
        elseif align === :left
            0.0
        elseif align === :right
            1.0
        elseif align isa Real
            @assert 0 ≤ align ≤ 1
            Float64(align)
        else
            error("Title align $align not supported.")
        end

        yoffset = Makie.top(px_area) + titlegap

        return Point2f(px_area.origin[1] + px_area.widths[1] * align_val, yoffset)
    end

    titlealignnode = lift(axis.titlealign; ignore_equal_values=true) do align
        (align, :bottom)
    end

    subtitleplot = text!(
        axis.blockscene, subtitlepos,
        text = axis.subtitle,
        visible = axis.subtitlevisible,
        fontsize = axis.subtitlesize,
        align = titlealignnode,
        font = axis.subtitlefont,
        fonts = axis.fonts,
        color = axis.subtitlecolor,
        lineheight = axis.subtitlelineheight,
        markerspace = :data,
        inspectable = false)

    axis.elements[:subtitle] = subtitleplot

    titlepos = lift(
        Makie.calculate_title_position,
        scene.px_area, axis.titlegap, axis.subtitlegap, axis.titlealign, :bottom, nothing, axis.subtitlelineheight, axis, subtitleplot;
        ignore_equal_values=true
    )

    titleplot = text!(
        axis.blockscene, titlepos,
        text = axis.title,
        visible = axis.titlevisible,
        fontsize = axis.titlesize,
        align = titlealignnode,
        font = axis.titlefont,
        fonts = axis.fonts,
        color = axis.titlecolor,
        lineheight = axis.titlelineheight,
        markerspace = :data,
        inspectable = false)

    axis.elements[:title] = titleplot

    update_protrusions_observable = Observable{Bool}(true)

    # on any update to any of the args which is not only a position change, update the protrusions!
    onany(titleplot.text, titleplot.visible, titleplot.fontsize, titlealignnode, titleplot.font, titleplot.lineheight) do args...
        update_protrusions_observable[] = true
    end

    onany(subtitleplot.text, subtitleplot.visible, subtitleplot.fontsize, subtitleplot.font, subtitleplot.lineheight) do args...
        update_protrusions_observable[] = true
    end

    # onany()
#
    lift(update_protrusions_observable; ignore_equal_values = false) do _notification_argument
        px_area = scene.px_area[]
        total_protrusion_bbox = reduce(union, Makie.boundingbox.(filter(p -> to_value(get(p, :visible, true)), collect(values(axis.elements)))))
        left_prot, bottom_prot = minimum(total_protrusion_bbox)
        right_prot, top_prot   = maximum(total_protrusion_bbox)
        left_scene, bottom_scene = minimum(px_area)
        right_scene, top_scene   = maximum(px_area)

        axis.layoutobservables.protrusions[] = Makie.GridLayoutBase.RectSides(max.(0, (left_scene - left_prot, right_prot - right_scene, bottom_scene - bottom_prot, top_prot - top_scene))...)
    end

    return axis
end

# do the axis drawing

function draw_geoaxis!(ax::GeoAxis, transformation, elements, remove_overlapping_ticks)
    topscene = ax.blockscene
    scene = ax.scene

    xgridpoints = Observable(Point2f[])
    ygridpoints = Observable(Point2f[])

    xminorgridpoints = Observable(Point2f[])
    yminorgridpoints = Observable(Point2f[])

    xtickpoints = Observable(Point2f[])
    ytickpoints = Observable(Point2f[])

    xticklabels = Observable(String[])
    yticklabels = Observable(String[])

    topspinepoints = Observable(Point2f[])
    btmspinepoints = Observable(Point2f[])
    lftspinepoints = Observable(Point2f[])
    rgtspinepoints = Observable(Point2f[])

    clippoints = Observable(Point2f[])

    xlimits = Observable((0.0f0, 0.0f0))
    ylimits = Observable((0.0f0, 0.0f0))


    # First we establish the spine points

    lift(ax.inputfinallimits, ax.finallimits, ax.xticks, ax.xtickformat, ax.yticks, ax.ytickformat, ax.xminorticks, ax.yminorticks, scene.px_area, transformation, ax.npoints) do limits, _transformedlimits, xticks, xtickformat, yticks, ytickformat, xminor, yminor, pxarea, transform_func, npoints

        lmin = minimum(limits)
        lmax = maximum(limits)
        xlimits[] = (lmin[1], lmax[1])
        ylimits[] = (lmin[2], lmax[2])

        _xtickvalues, _xticklabels = Makie.get_ticks(xticks, identity, xtickformat, xlimits[]...)
        _ytickvalues, _yticklabels = Makie.get_ticks(yticks, identity, ytickformat, ylimits[]...)

        _xminortickvalues = Makie.get_minor_tickvalues(xminor, identity, _xtickvalues, xlimits[]...)
        _yminortickvalues = Makie.get_minor_tickvalues(yminor, identity, _ytickvalues, ylimits[]...)

        _xtickpos_in_inputspace = Point2f.(_xtickvalues, ylimits[][1])
        _ytickpos_in_inputspace = Point2f.(xlimits[][1], _ytickvalues)

        # update but do not notify
        xtickpoints.val = project_to_pixelspace(scene, transform_func, _xtickpos_in_inputspace) .+
                            Ref(Point2f(pxarea.origin))

        ytickpoints.val = project_to_pixelspace(scene, transform_func, _ytickpos_in_inputspace) .+
                            Ref(Point2f(pxarea.origin))


        if are_ticks_colocated(scene, xtickpoints.val, _xticklabels, ax.xticklabelsize[])
            ax.xticklabelsvisible[] = false
        else
            xtickpoints.val = xtickpoints.val .+ directional_pad.(
                Ref(scene), Ref(transform_func), Ref(limits), _xtickpos_in_inputspace,
                _xticklabels, Ref(Point2f(0, ax.xticklabelpad[])), ax.xticklabelsize[], ax.xticklabelfont[],
                ax.xticklabelrotation[]
            )
        end


        if are_ticks_colocated(scene, ytickpoints.val, _yticklabels, ax.yticklabelsize[])
            ax.yticklabelsvisible[] = false
        else
            ytickpoints.val = ytickpoints.val .+ directional_pad.(
                Ref(scene), Ref(transform_func), Ref(limits), _ytickpos_in_inputspace,
                _yticklabels, Ref(Point2f(ax.yticklabelpad[], 0)), ax.yticklabelsize[], ax.yticklabelfont[],
                ax.yticklabelrotation[]
            )
        end

        # check for overlapping ticks and remove them (literally deleteat!(...))
        remove_overlapping_ticks && remove_overlapping_ticks!(
            scene,
            xtickpoints.val, _xticklabels, ax.xticklabelsvisible[],
            ytickpoints.val, _yticklabels, ax.yticklabelsvisible[],
            max(ax.xticklabelsize[], ax.yticklabelsize[])
        )

        # notify this
        xticklabels.val = _xticklabels
        yticklabels.val = _yticklabels

        Makie.Observables.notify(xticklabels); Makie.Observables.notify(yticklabels)
        Makie.Observables.notify(xtickpoints); Makie.Observables.notify(ytickpoints)

        xrange = LinRange(xlimits[]..., npoints)
        yrange = LinRange(ylimits[]..., npoints)

        # first update the spine
        topspinepoints[] = project_to_pixelspace(scene, transform_func, Point2f.(xrange, ylimits[][2])) .+ (Point2f(pxarea.origin),)
        btmspinepoints[] = project_to_pixelspace(scene, transform_func, Point2f.(xrange, ylimits[][1])) .+ (Point2f(pxarea.origin),)
        lftspinepoints[] = project_to_pixelspace(scene, transform_func, Point2f.(xlimits[][1], yrange)) .+ (Point2f(pxarea.origin),)
        rgtspinepoints[] = project_to_pixelspace(scene, transform_func, Point2f.(xlimits[][2], yrange)) .+ (Point2f(pxarea.origin),)

        # TODO: uncomment when clip begins.
        # clippoints[] = vcat(
        #     btmspinepoints[],
        #     rgtspinepoints[],
        #     reverse(topspinepoints[]),
        #     reverse(lftspinepoints[])
        # )

        # now, the grid.  Each visible "gridline" is separated from the next
        # by a `Point2f(NaN)`.  The approach here allows us to avoid appending.
        # x first
        _xgridpoints = fill(Point2f(NaN), (npoints+1) * length(_xtickvalues))

        current_ind = 1
        for x in _xtickvalues
            _xgridpoints[current_ind:(current_ind+npoints-1)] = Point2f.(x, yrange)
            current_ind += npoints + 1
        end
        # now y
        _ygridpoints = fill(Point2f(NaN), (npoints+1) * length(_ytickvalues))

        current_ind = 1
        for y in _ytickvalues
            _ygridpoints[current_ind:(current_ind+npoints-1)] = Point2f.(xrange, y)
            current_ind += npoints + 1
        end

        xgridpoints[] = project_to_pixelspace(scene, transform_func, _xgridpoints) .+ (Point2f(pxarea.origin),)
        ygridpoints[] = project_to_pixelspace(scene, transform_func, _ygridpoints) .+ (Point2f(pxarea.origin),)

        # Do the same for minor ticks
        _xminorgridpoints = fill(Point2f(NaN), (npoints+1) * length(_xminortickvalues))

        current_ind = 1
        for x in _xminortickvalues
            _xminorgridpoints[current_ind:(current_ind+npoints-1)] = Point2f.(x, yrange)
            current_ind += npoints + 1
        end
        # now y
        _yminorgridpoints = fill(Point2f(NaN), (npoints+1) * length(_yminortickvalues))

        current_ind = 1
        for y in _yminortickvalues
            _yminorgridpoints[current_ind:(current_ind+npoints-1)] = Point2f.(xrange, y)
            current_ind += npoints + 1
        end

        xminorgridpoints[] = project_to_pixelspace(scene, transform_func, _xminorgridpoints) .+ (Point2f(pxarea.origin),)
        yminorgridpoints[] = project_to_pixelspace(scene, transform_func, _yminorgridpoints) .+ (Point2f(pxarea.origin),)

        return 1
        # Now, we've updated the entire axis.
    end

    Makie.Observables.notify(ax.xticks)

    # Time to plot!


    # First, we clip our scene:
    # elements[:clip] = clip!(scene, clippoints)
    # translate!(elements[:clip], 0, 0, -9999)
    # This makes the clip plot the first in the list of plots
    # insert!(scene.plots, 1, pop!(scene.plots))

    # Now we plot the spines.
    # Make sure that the spines are plotted to the blockscene and not the scene,
    # so that they are not cropped!
    elements[:topspineplot] = lines!(
        topscene, topspinepoints;
        visible = ax.topspinevisible,
        color = ax.topspinecolor,
        # linestyle = ax.spinestyle,
        linewidth = ax.spinewidth,
        )
    elements[:bottomspineplot] = lines!(
        topscene, btmspinepoints;
        visible = ax.bottomspinevisible,
        color = ax.bottomspinecolor,
        # linestyle = ax.spinestyle,
        linewidth = ax.spinewidth,
        )
    elements[:leftspineplot] = lines!(
        topscene, lftspinepoints;
        visible = ax.leftspinevisible,
        color = ax.leftspinecolor,
        # linestyle = ax.spinestyle,
        linewidth = ax.spinewidth,
        )
    elements[:rightspineplot] = lines!(
        topscene, rgtspinepoints;
        visible = ax.rightspinevisible,
        color = ax.rightspinecolor,
        # linestyle = ax.spinestyle,
        linewidth = ax.spinewidth,
        )


    # Now for the grids:

    elements[:xgridplot] = lines!(
        topscene, xgridpoints;
        visible = ax.xgridvisible,
        color = ax.xgridcolor,
        linestyle = ax.xgridstyle,
        width = ax.xgridwidth,
        transparency=true,
    )
    elements[:ygridplot] = lines!(
        topscene, ygridpoints;
        visible = ax.ygridvisible,
        color = ax.ygridcolor,
        linestyle = ax.ygridstyle,
        width = ax.ygridwidth,
        transparency=true,
    )

    elements[:xminorgridplot] = lines!(
        topscene, xminorgridpoints;
        visible = ax.xminorgridvisible,
        color = ax.xminorgridcolor,
        linestyle = ax.xminorgridstyle,
        width = ax.xminorgridwidth,
        transparency=true,
    )

    elements[:yminorgridplot] = lines!(
        topscene, yminorgridpoints;
        visible = ax.yminorgridvisible,
        color = ax.yminorgridcolor,
        linestyle = ax.yminorgridstyle,
        width = ax.yminorgridwidth,
        transparency=true,
    )


    # And finally, the TikZ!

    textscene = ax.blockscene

    elements[:xticklabelplot] = text!(
        textscene,
        xticklabels;
        markerspace = :pixel,
        visible = ax.xticklabelsvisible,
        position = xtickpoints,
        rotation = ax.xticklabelrotation,
        font = ax.xticklabelfont,
        fontsize = ax.xticklabelsize,
        color = ax.xticklabelcolor,
        align = (:center, :center),
    )

    elements[:yticklabelplot] = text!(
        textscene,
        yticklabels;
        markerspace = :pixel,
        visible = ax.yticklabelsvisible,
        position = ytickpoints,
        rotation = ax.yticklabelrotation,
        font = ax.yticklabelfont,
        fontsize = ax.yticklabelsize,
        color = ax.yticklabelcolor,
        align = (:center, :center),
    )

    # For diagnostics only!
    # scatter!(textscene, xtickpoints; visible = ax[:xticklabelsvisible], color = :red, bordercolor=:black)
    # scatter!(textscene, ytickpoints; visible = ax[:yticklabelsvisible], color = :red, bordercolor=:black)

    # Finally, we translate these plots such that they are above the content.
    translate!.(values(elements), 0, 0, 1000)

    # Set common attributes for all plots
    setproperty!.(values(elements), (:inspectable,), (false,))
    setproperty!.(values(elements), (:xautolimits,), (false,))
    setproperty!.(values(elements), (:yautolimits,), (false,))

    # finally, make sure that lift runs again - for some reason, it doesn't work directly
    notify(ax.inputfinallimits)
    notify(ax.finallimits)

    return nothing
end

function Makie.xlims!(ax::GeoAxis, xlims)
    if length(xlims) != 2
        error("Invalid xlims length of $(length(xlims)), must be 2.")
    elseif xlims[1] == xlims[2]
        error("Can't set x limits to the same value $(xlims[1]).")
    end

    ax.limits.val = (xlims, ax.limits[][2])
    reset_limits!(ax, yauto = false)
    nothing
end

function Makie.ylims!(ax::GeoAxis, ylims)
    if length(ylims) != 2
        error("Invalid ylims length of $(length(ylims)), must be 2.")
    elseif ylims[1] == ylims[2]
        error("Can't set x limits to the same value $(ylims[1]).")
    end

    ax.limits.val = (ax.limits[][1], ylims)
    reset_limits!(ax, xauto = false)
    nothing
end



"""
    create_transform(dest::String, source::String)

Creates a `Proj.Transformation` from the provided strings, with the parameter `always_xy` set to `true`.
"""
function create_transform(source::String, dest::String)
    return Proj.Transformation(source, dest; always_xy=true)
end

function create_transform(source::Observable, dest::Observable)
    result = Observable{Any}()
    return map!(create_transform, result, source, dest)
end

function Makie.plot!(
    axis::GeoAxis, P::Makie.PlotFunc,
    attributes::Makie.Attributes, args...; kw_attributes...)
    allattrs = merge(attributes, Attributes(kw_attributes))
    source = pop!(allattrs, :source, axis.source_projection)
    transformfunc = create_transform(source, axis.target_projection)
    trans = Transformation(transformfunc)
    allattrs[:transformation] = trans
    plt = Makie.plot!(axis.scene, P, allattrs, args...)
    if Makie.is_open_or_any_parent(axis.scene)
        reset_limits!(axis)
    end
    return plt
end

function Makie.plot!(P::Type{<:Poly}, axis::GeoAxis, args...; kw_attributes...)
    attributes = Makie.Attributes(kw_attributes)
    source = pop!(attributes, :source, axis.source_projection)
    transformfunc = create_transform(source, axis.target_projection)
    arg = geomakie_transform(transformfunc, convert.(Observable, args)...)
    plt = Makie.plot!(axis.scene, P, attributes, arg)
    if Makie.is_open_or_any_parent(axis.scene)
        reset_limits!(axis)
    end
    return plt
end

function Makie.plot!(P::Makie.PlotFunc, axis::GeoAxis, args...; kw_attributes...)
    attributes = Makie.Attributes(kw_attributes)
    p = Makie.plot!(axis, P, attributes, args...)
    lift(axis.transform_func) do tf
        p.transformation.transform_func[] = tf
    end
end

function geomakie_transform(trans, points::AbstractVector{<: Point2})
    return Makie.apply_transform(trans, points)
end

function geomakie_transform(trans, vec::AbstractVector)
    return map(x-> geomakie_transform(trans, x), vec)
end

function geomakie_transform(trans, geom::GeoJSON.FeatureCollection)
    return geomakie_transform(trans, convert_arguments(Poly, geom)[1])
end

function geomakie_transform(trans, geom)
    return geomakie_transform(trans, convert_arguments(Poly, geom)[1])
end

function geomakie_transform(trans, polygon::Polygon)
    # TODO: cut poly edges at transformed points
    return Polygon(
        geomakie_transform(trans, GeometryBasics.coordinates(polygon.exterior)),
        geomakie_transform.((trans,), GeometryBasics.coordinates.(polygon.interiors)),
    )
end

function geomakie_transform(trans, polygon::MultiPolygon)
    return MultiPolygon(geomakie_transform.((trans,), polygon.polygons))
end

geomakie_transform(trans, polygons::AbstractArray{<: Polygon}) = geomakie_transform.((trans,), polygons)
geomakie_transform(trans, multipolygons::AbstractArray{<: MultiPolygon}) = geomakie_transform.((trans,), multipolygons)


function geomakie_transform(trans::Observable, obs...)
    return map((args...) -> geomakie_transform(args...), trans, obs...)
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
    # from this, the border/spine line is just the contour at 0.5, 
    # if valid → true and invalid → false.
    spineline = Observable(Point2f[])
    lift(ga.transform_func, ga.scene.px_area, ga.finallimits) do ptrans, pxarea, finallims
        # empty the spineline
        empty!(spineline.val)
        # TODO: if you zoom in sufficiently, this should somehow correct itself or otherwise not display
        # but how do you do that?
        # maybe have some criterion - either geospine or normal spines, but not both
        # create a grid of the Scene's pixel area, in transformed space
        # TODO: apply padding in pixelspace, then project down to transformed space.
        xmin, ymin = minimum(finallims)
        xmax, ymax = maximum(finallims)
        xs = Float64.(LinRange(xmin - padding, xmax + padding, round(Int, (pxarea.widths[1] + 2 * padding) * density))) # resolution is 2x pixel resolution, no particular reason.
        ys = Float64.(LinRange(ymin - padding, ymax + padding, round(Int, (pxarea.widths[2] + 2 * padding) * density)))
        # points in transformed space
        tpoints = Point2{Float64}.(xs, ys')
        # points in lon/lat space
        itpoints = Makie.apply_transform(Makie.inverse_transform(ptrans), tpoints)

        # possibly, to correct for the padding issue, set every pixel outside the scene
        # to false, i.e., infinite.  This would make a square each time...
        finite_mask = isfinite.(itpoints)
        if padding != 0
            # bottom
            finite_mask[1:padding, :] = false
            # top
            finite_mask[(end-padding):end, :] = false
            # left
            finite_mask[:, 1:padding] = false
            # right
            finite_mask[:, (end-padding):end] = false
        end

        # there are only two possible values in the finite mask.
        # so, we can compute the correct spine contour.
        spine_contour = Makie.Contours.contours(xs, ys, Float32.(finite_mask), [0.5f0])
        # since we know there's only one level, instead of iterating through all levels,
        # we can skip that and iterate only through the first.
        for element in Makie.Contours.lines(first(Makie.Contours.levels(spine_contour)))
            append!(
                spineline.val, 
                Point2f.(Makie.project.((camera(ga.scene),), :data, :pixel, element.vertices)) .+ (pxarea.origin,)
            )
        end
        # we've constructed the spine line, now start the update.
        notify(spineline)

    end

    return spineline
end

# add docs for GeoAxis

# Base.@doc GeoAxis """
# """
