#=
# GeoAxis
=#

# `Rect2d` comes from GeometryBasics.

Makie.@Block GeoAxis <: Makie.AbstractAxis begin
    scene::Scene
    targetlimits::Observable{Rect2d}
    finallimits::Observable{Rect2d}
    mouseeventhandle::Makie.MouseEventHandle
    scrollevents::Observable{Makie.ScrollEvent}
    keysevents::Observable{Makie.KeysEvent}
    interactions::Dict{Symbol, Tuple{Bool, Any}}
    elements::Dict{Symbol, Any}
    transform_func::Observable{Any}
    inv_transform_func::Observable{Any}
    graph::ComputePipeline.ComputeGraph
    @attributes begin
        # unused - only for compat with Makie AbstractAxis functions
        xscale = identity
        yscale = identity
        # Layout observables for Block
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

        # Projection
        "Projection of the source data. This is the value plots will default to, but can be overwritten via `plot(...; source=...)`"
        source = "+proj=longlat +datum=WGS84"
        "Projection that the axis uses to display the data."
        dest = "+proj=eqearth"
        "A user outline replacing the projection's own domain: a vector of lon/lat points, or `:dest => points` in projected coordinates. `nothing` uses the projection's domain."
        outline = nothing

        "Controls if the y axis goes upwards (false) or downwards (true)"
        yreversed::Bool = false
        "Controls if the x axis goes rightwards (false) or leftwards (true)"
        xreversed::Bool = false
        "The relative margins added to the autolimits in x direction."
        xautolimitmargin::Tuple{Float64,Float64} = (0.05f0, 0.05f0)
        "The relative margins added to the autolimits in y direction."
        yautolimitmargin::Tuple{Float64,Float64} = (0.05f0, 0.05f0)
        "The limits that the user has manually set. They are reinstated when calling `reset_limits!` and are set to nothing by `autolimits!`. Can be either a tuple (xlow, xhigh, ylow, high) or a tuple (nothing_or_xlims, nothing_or_ylims). Are set by `xlims!`, `ylims!` and `limits!`."
        limits = (nothing, nothing)
        "The forced aspect ratio of the axis. `nothing` leaves the axis unconstrained, `DataAspect()` forces the same ratio as the ratio in data limits between x and y axis, `AxisAspect(ratio)` sets a manual ratio."
        aspect = Makie.DataAspect()
        autolimitaspect = nothing

        # appearance controls
        "The set of fonts which text in the axis should use.s"
        fonts = (; regular = "TeX Gyre Heros Makie")
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

        "The x (longitude) ticks: a `GeographicTicks`, `ArcMinuteTicks` or any Makie tick finder, a vector or range of values, or a `(values, labels)` tuple.  The default sizes its interval to the visible extent."
        xticks = GeographicTicks()
        "The y (latitude) ticks: a `GeographicTicks`, `ArcMinuteTicks` or any Makie tick finder, a vector or range of values, or a `(values, labels)` tuple.  The default sizes its interval to the visible extent."
        yticks = GeographicTicks()

        "Format for x (longitude) tick labels: a function of the values, a format string, or `automatic` for hemisphere suffixes (`110°W`, `0°`, `180°`)."
        xtickformat = Makie.automatic
        "Format for y (latitude) tick labels: a function of the values, a format string, or `automatic` for hemisphere suffixes (`45°N`, `0°`)."
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
        "The gap between the end of an x tick mark and its label's glyph box."
        xticklabelpad::Float64 = 5f0
        "The gap between the end of a y tick mark and its label's glyph box."
        yticklabelpad::Float64 = 5f0
        "The counterclockwise rotation of the xticklabels in radians."
        xticklabelrotation::Float64 = 0f0
        "The counterclockwise rotation of the yticklabels in radians."
        yticklabelrotation::Float64 = 0f0
        "The alignment of the xticklabels; `automatic` centres each label on the outward normal of the frame at its tick."
        xticklabelalign::Union{Makie.Automatic, Tuple{Symbol, Symbol}} = Makie.automatic
        "The alignment of the yticklabels; `automatic` centres each label on the outward normal of the frame at its tick."
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
        "The width of the axis spine (the frame of the map)."
        spinewidth::Float64 = 1f0
        "Controls if the axis spine is visible."
        spinevisible::Bool = true
        "The color of the axis spine."
        spinecolor::RGBAf = :black
        "Controls if the x grid lines are visible."
        xgridvisible::Bool = true
        "Controls if the y grid lines are visible."
        ygridvisible::Bool = true
        "The width of the x grid lines."
        xgridwidth::Float64 = 1f0
        "The width of the y grid lines."
        ygridwidth::Float64 = 1f0
        "The color of the x grid lines."
        xgridcolor::RGBAf = RGBAf(0, 0, 0, 0.5)
        "The color of the y grid lines."
        ygridcolor::RGBAf = RGBAf(0.0, 0, 0, 0.5)
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

        "Which straight (viewport) edges carry longitude labels: `:bottom`, `:top` or `:both`.  Curved frame edges label both families regardless."
        xaxisposition::Symbol = :bottom
        "Which straight (viewport) edges carry latitude labels: `:left`, `:right` or `:both`.  Curved frame edges label both families regardless."
        yaxisposition::Symbol = :left

        "A graticule line leaving the frame at less than this angle (degrees) gets no label there."
        ticklabelminangle::Float64 = 20.0
        "The clearance (pixels) two tick labels must keep; of two closer labels the rounder value, then the one nearer the middle of its edge, is drawn."
        ticklabelmingap::Float64 = 2.0
        "Drop tick labels that collide with an already placed one.  `false` draws every label, overlaps included."
        ticklabelcollisions::Bool = true
        "Where the crowding report goes when labels are skipped: `:debug`, `:info` or `:none`."
        ticklabelreport::Symbol = :debug

    end
end

# Makie generic object API
Makie.transform_func(ax::GeoAxis) = ax.transform_func[]

function Makie.initialize_block!(axis::GeoAxis)

    # Set up transformations first, so that the scene can be set up
    # and linked to those.
    transform_obs = Observable{Any}(identity; ignore_equal_values=true)
    transform_inv_obs = Observable{Any}(identity; ignore_equal_values=true)
    setfield!(axis, :transform_func, transform_obs)
    setfield!(axis, :inv_transform_func, transform_inv_obs)

    # Set up the axis for the Scene, mostly using Makie's existing functionality
    scene = axis_setup!(axis)

    # The decoration graph: boundary, view, frame, graticule, labels and their
    # pixel positions, computed once per change of their inputs, with
    # `targetlimits` bridged from the view's bbox.
    build_graph!(axis)
    graph = axis.graph

    # Keep the data transformation up to date.
    onany(scene, axis.dest, axis.source; update=true) do tp, sp
        trans = create_transform(tp, sp)
        transform_obs[] = trans
        transform_inv_obs[] = Makie.inverse_transform(trans)
    end

    # The graticule, in dest space from the graph.
    longridplot = lines!(scene, graph[:xgrid_points]; color=axis.xgridcolor, linewidth=axis.xgridwidth,
        visible=axis.xgridvisible, linestyle=axis.xgridstyle, transparency=true, inspectable=false,
        xautolimits=false, yautolimits=false)
    translate!(longridplot, 0, 0, 100)
    latgridplot = lines!(scene, graph[:ygrid_points]; color=axis.ygridcolor, linewidth=axis.ygridwidth,
        visible=axis.ygridvisible, linestyle=axis.ygridstyle, transparency=true, inspectable=false,
        xautolimits=false, yautolimits=false)
    translate!(latgridplot, 0, 0, 100)

    # The spine: the frame of the map, drawn in dest space from the decoration graph.
    spineplot = lines!(scene, graph[:spine]; color=axis.spinecolor, linewidth=axis.spinewidth,
        visible=axis.spinevisible, inspectable=false, xautolimits=false, yautolimits=false)
    translate!(spineplot, 0, 0, 101)

    # Tick stubs and labels live in the block scene, in pixels, so they can sit
    # outside the map's viewport.
    xstubs = linesegments!(axis.blockscene, graph[:xstubs]; space=:pixel, color=axis.xtickcolor,
        linewidth=axis.xtickwidth, visible=axis.xticksvisible, inspectable=false)
    ystubs = linesegments!(axis.blockscene, graph[:ystubs]; space=:pixel, color=axis.ytickcolor,
        linewidth=axis.ytickwidth, visible=axis.yticksvisible, inspectable=false)

    # A user alignment applies as given; the automatic one centres the glyph
    # box on the outward normal, so the position the graph hands out is the centre.
    xalign = map(a -> a isa Makie.Automatic ? (:center, :center) : a, axis.blockscene, axis.xticklabelalign)
    yalign = map(a -> a isa Makie.Automatic ? (:center, :center) : a, axis.blockscene, axis.yticklabelalign)

    lontex = text!(axis.blockscene, graph[:xlabel_positions];
        text=graph[:xlabel_strings],
        space=:pixel,
        align=xalign,
        rotation=axis.xticklabelrotation,
        font=axis.xticklabelfont,
        color=axis.xticklabelcolor,
        fontsize=axis.xticklabelsize,
        visible=axis.xticklabelsvisible,
        inspectable=false,
    )

    lattex = text!(axis.blockscene, graph[:ylabel_positions];
        text=graph[:ylabel_strings],
        space=:pixel,
        align=yalign,
        rotation=axis.yticklabelrotation,
        font=axis.yticklabelfont,
        color=axis.yticklabelcolor,
        fontsize=axis.yticklabelsize,
        visible=axis.yticklabelsvisible,
        inspectable=false,
    )

    elements = Dict{Symbol,Any}()
    setfield!(axis, :elements, elements)
    elements[:xgrid] = longridplot
    elements[:ygrid] = latgridplot
    elements[:spine] = spineplot
    elements[:xticks] = xstubs
    elements[:yticks] = ystubs
    elements[:xticklabels] = lontex
    elements[:yticklabels] = lattex

    # The title sits above whatever the decorations push out at the top, so
    # the bound is handed to Makie's title placement as an always-on top protrusion.
    bound_obs = ComputePipeline.get_observable!(graph, :protrusion_bound; use_deepcopy = false)
    top_bound = map(b -> Float32(b.top), axis.blockscene, bound_obs; ignore_equal_values=true)

    subtitlepos = lift(axis.blockscene, scene.viewport, axis.titlegap, axis.titlealign, top_bound;
        ignore_equal_values=true) do a, titlegap, align, xaxisprotrusion
        align_factor = Makie.halign2num(align, "Horizontal title align $align not supported.")
        x = a.origin[1] + align_factor * a.widths[1]
        yoffset = Makie.top(a) + titlegap + xaxisprotrusion
        return Point2d(x, yoffset)
    end

    titlealignnode = lift(axis.blockscene, axis.titlealign; ignore_equal_values=true) do align
        (align, :bottom)
    end

    subtitlet = text!(
        axis.blockscene, subtitlepos,
        text=axis.subtitle,
        visible=axis.subtitlevisible,
        fontsize=axis.subtitlesize,
        align=titlealignnode,
        font=axis.subtitlefont,
        color=axis.subtitlecolor,
        lineheight=axis.subtitlelineheight,
        markerspace=:data,
        inspectable=false)

    titlepos = lift(Makie.calculate_title_position, axis.blockscene, scene.viewport, axis.titlegap, axis.subtitlegap,
        axis.titlealign, Observable(:top), top_bound, axis.subtitlelineheight, axis, subtitlet; ignore_equal_values=true)

    titlet = text!(
        axis.blockscene, titlepos,
        text=axis.title,
        visible=axis.titlevisible,
        fontsize=axis.titlesize,
        align=titlealignnode,
        font=axis.titlefont,
        color=axis.titlecolor,
        lineheight=axis.titlelineheight,
        markerspace=:data,
        inspectable=false)

    # The protrusion bound leaves the graph as the second bridge.  The layout
    # it feeds resizes the viewport, which the graph reads to size the tick
    # interval; the ladder is discrete and the bound only sees which labels
    # exist, so the loop settles at once in practice, and the depth guard
    # bounds it regardless.
    depth = Ref(0)
    onany(axis.blockscene, bound_obs, axis.title, axis.titlesize, axis.titlegap, axis.titlevisible,
        axis.subtitle, axis.subtitlevisible, axis.subtitlesize, axis.subtitlegap,
        axis.titlelineheight, axis.subtitlelineheight; update=true) do bound, args...
        depth[] >= PROTRUSION_DEPTH_CAP && return
        depth[] += 1
        try
            prots = compute_protrusions(bound, args..., subtitlet, titlet)
            prots == axis.layoutobservables.protrusions[] || (axis.layoutobservables.protrusions[] = prots)
        finally
            depth[] -= 1
        end
        return
    end

    fl = axis.finallimits[]
    notify(axis.limits)
    if fl == axis.finallimits[]
        notify(axis.finallimits)
    end

    return axis
end

"How deep the protrusion → layout → viewport → protrusion chain may re-enter before it is cut."
const PROTRUSION_DEPTH_CAP = 8

function compute_protrusions(bound, title, titlesize, titlegap, titlevisible,
    subtitle, subtitlevisible, subtitlesize, subtitlegap, titlelineheight, subtitlelineheight,
    subtitlet, titlet)

    titleheight = Makie.boundingbox(titlet, :data).widths[2] + titlegap
    subtitleheight = Makie.boundingbox(subtitlet, :data).widths[2] + subtitlegap

    titlespace = if !titlevisible || Makie.iswhitespace(title)
        0.0f0
    else
        titleheight
    end
    subtitlespace = if !subtitlevisible || Makie.iswhitespace(subtitle)
        0.0f0
    else
        subtitleheight
    end

    return GridLayoutBase.RectSides{Float32}(bound.left, bound.right, bound.bottom, bound.top + titlespace + subtitlespace)
end

# This is where we override the stuff to make it our stuff.
function Makie.plot!(axis::GeoAxis, plot::Makie.AbstractPlot)
    # deal with setting the transform_func correctly
    source = pop!(plot.kw, :source, axis.source)
    transformfunc = lift(create_transform, axis.dest, source)

    if !Makie.not_in_data_space(plot)
        trans = Makie.Transformation(transformfunc; get(plot.kw, :transformation, Attributes())...)
        plot.kw[:transformation] = trans
    end

    # remove the reset_limits kwarg if there is one, this determines whether to automatically reset limits
    # on plot insertion
    reset_limits = to_value(pop!(plot.kw, :reset_limits, true))
    
    # actually plot
    Makie.plot!(axis.scene, plot)

    # reset limits ONLY IF the user has not said otherwise
    if reset_limits
        # some area-like plots basically always look better if they cover the whole plot area.
        # adjust the limit margins in those cases automatically.
        Makie.needs_tight_limits(plot) && Makie.tightlimits!(axis)

        if Makie.is_open_or_any_parent(axis.scene)
            Makie.reset_limits!(axis)
        end
    end

    return plot
end


# This function only exists to get around the attribute name check,
# since source and dest are not listed as common attributes.
# All crs handling is done in `plot!(ax::GeoAxis, plot)`.
function _create_plot!(F, attributes::Dict, ax::GeoAxis, args...)
    source = pop!(attributes, :source, nothing)
    dest = pop!(attributes, :dest, nothing)
    plot = Plot{Makie.default_plot_func(F, args)}(args, attributes)
    isnothing(source) || (plot.kw[:source] = source)
    isnothing(dest) || (plot.kw[:dest] = dest)
    Makie.plot!(ax, plot)
    return plot
end


# ## Makie generic axis/block API

# this is generally false, but I want to deviate from that here.
Makie.needs_tight_limits(axis::GeoAxis, ::Surface) = true

Makie.get_scene(ga::GeoAxis) = ga.scene
