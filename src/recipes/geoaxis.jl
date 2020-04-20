frameattrs = (
    width = 1,
    color = :black,
    visible = true,
    style = nothing
)

yaxisattrs = (
    tick = (
    # tick marks
        ticks   = WilkinsonTicks(; k_min = 5, k_ideal = 7, k_max = 15),
        autolimitmargin = 0.05f0,
        size    = 10f0,
        visible = true,
        color   = RGBA(Colors.colorant"lightgrey", 0.7),
        align   = 0f0,
        width   = 1f0,
        style   = nothing,

        # tick labels
        label = (
            size      = 20f0,
            formatter = Formatting.format,
            visible   = true,
            font      = "DejaVu Sans",
            color     = RGBf0(0, 0, 0),
            spacing   = 20f0,
            padding   = 5f0,
            rotation  = 0f0,
            align     = (:center, :top),
            position  = Left()::Side

        ),
    ),
)

xaxisattrs = (
    tick = (
    # tick marks
        ticks   = WilkinsonTicks(; k_min = 5, k_ideal = 7, k_max = 12),
        autolimitmargin = 0.05f0,
        size    = 10f0,
        visible = true,
        color   = RGBA(Colors.colorant"lightgrey", 0.7),
        align   = 0f0,
        width   = 1f0,
        style   = nothing,

        # tick labels
        label = (
            size      = 20f0,
            formatter = Formatting.format,
            visible   = true,
            font      = "DejaVu Sans",
            color     = RGBf0(0, 0, 0),
            spacing   = 20f0,
            padding   = 5f0,
            rotation  = 0f0,
            align     = (:center, :top),
            position  = Bottom()

        ),
    ),
)

@recipe(GeoAxis, limits) do scene
    merge(scene.attributes,
    Theme(
        samples = 100,
        show_axis = false,

        frames = (
            top = frameattrs,
            left = frameattrs,
            right = frameattrs,
            bottom = frameattrs
        ),

        grid = (
            visible = true,
            color   = RGBf0(0, 0, 0),
            width   = 1f0,
            style   = nothing
        ),

        x = xaxisattrs,
        y = yaxisattrs,

        crs = (
            source = LonLat(),
            dest   = LonLat()
        )
    )
    )
end

convert_arguments(::Type{<: GeoAxis}, xmin::Real, xmax::Real, ymin::Real, ymax::Real) = (Rect2D{Float32}(xmin, xmax, ymin, ymax),)

function convert_arguments(::Type{<: GeoAxis}, xs::Tuple, ys::Tuple)
    xmin, xmax = xs
    ymin, ymax = ys
    return (Rect2D{Float32}(xmin, xmax, ymin, ymax),)
end

function convert_arguments(::Type{<: GeoAxis}, xs::AbstractVector{<: Number}, ys::AbstractVector{<: Number})
    xmin, xmax = extrema(xs)
    ymin, ymax = extrema(ys)
    return (Rect2D{Float32}(xmin, xmax, ymin, ymax),)
end

# function AbstractPlotting.calculated_attributes!(plot::GeoAxis)
#     @extract plot (x, y, crs, limits)
#
#     lift(limits, crs.source, crs.dest, x.tick.label.size, y.tick.label.size) do limits, source, dest, xticklabelsize, yticklabelsize
#         newrect = transform(source, dest, [limits[LEFT] limits[TOP]; limits[RIGHT] limits[BOTTOM]])
#         textscale = maximum(diff.(eachcol(newrect)))
#
#         x.tick.label.textsize[] = xticklabelsize * textscale/100
#         y.tick.label.textsize[] = yticklabelsize * textscale/100
#
#     end
#
# end

function AbstractPlotting.plot!(plot::GeoAxis{T}) where T

    @extract plot (x, y)

    draw_frames!(plot)

    draw_ticks!(plot)

end

function draw_frames!(plot::GeoAxis{T}) where T

    @extract plot (frames, crs, samples)

    @extract frames (top, bottom, left, right)

    @extract crs (source, dest)

    # initialize frames
    topline = Node(Vector{Point2f0}())
    bottomline = Node(Vector{Point2f0}())
    leftline = Node(Vector{Point2f0}())
    rightline = Node(Vector{Point2f0}())

    # initialize the line vectors
    lift(plot.limits, source, dest, samples) do lims, source, dest, samples

        lonrange = LinRange(left(lims), right(lims), samples)
        latrange = LinRange(bottom(lims), top(lims), samples)

        topline[] = Point2f0.(transform.(source, dest, [Point2f0(lon, top(lims)) for lon in lonrange]))
        leftline[] = Point2f0.(transform.(source, dest, [Point2f0(left(lims), lat) for lat in latrange]))
        rightline[] = Point2f0.(transform.(source, dest, [Point2f0(right(lims), lat) for lat in latrange]))
        bottomline[] = Point2f0.(transform.(source, dest, [Point2f0(lon, bottom(lims)) for lon in lonrange]))

    end

    # plot the frames
    lines!.(plot, (top, bottom, left, right), (topline, bottomline, leftline, rightline))

end

function draw_ticks!(plot::GeoAxis)

    @extract plot (x, y)

    xtickvalues = Node{Vector{<: AbstractFloat}}(Vector{Float64}())
    ytickvalues = Node{Vector{<: AbstractFloat}}(Vector{Float64}())

    xlinevec = Node(Vector{Point2f0}())
    ylinevec = Node(Vector{Point2f0}())

    xtickannotations = Node(Vector{Tuple{String, Point2f0}}())
    ytickannotations = Node(Vector{Tuple{String, Point2f0}}())

    lift(x.tick.ticks, y.tick.ticks, x.tick.label.position, y.tick.label.position, plot.limits, plot.samples, plot.crs.source, plot.crs.dest, x.tick.label.size, y.tick.label.size) do xticks_struct, yticks_struct, xtickp, ytickp, limits, samples, source, dest, xticklabelsize, yticklabelsize

        xtickvalues[] = MakieLayout.compute_tick_values(xticks_struct, left(limits), right(limits), 100f0)
        ytickvalues[] = MakieLayout.compute_tick_values(yticks_struct, bottom(limits), top(limits), 100f0)

        xticklabels = MakieLayout.get_tick_labels(xticks_struct, xtickvalues[])
        yticklabels = MakieLayout.get_tick_labels(yticks_struct, ytickvalues[])

        # silently update the backend value without calling
        # these Observables' listener functions.
        xlinevec.val = Vector{Point2f0}()
        ylinevec.val = Vector{Point2f0}()

        for xtick in xtickvalues[]
            append!(xlinevec.val, transform.(source, dest, Point2f0.(xtick, LinRange(bottom(limits), top(limits), samples))))
            push!(xlinevec.val, Point2f0(NaN))
        end
        for ytick in ytickvalues[]
            append!(ylinevec.val, transform.(source, dest, Point2f0.(LinRange(left(limits), right(limits), samples), ytick)))
            push!(ylinevec.val, Point2f0(NaN))
        end

        # notify the observables that they have changed
        AbstractPlotting.notify!(xlinevec)
        AbstractPlotting.notify!(ylinevec)

        # now for the tick placement

        # first, we do the y ticks (latitude)
        ytickpositions, ytickstrings = (nothing, nothing)

        if typeof(ytickp) <: MakieLayout.Side

            xpos = limits[ytickp]

            ytickpositions = Point2f0.(xpos, ytickvalues[])

            ytickstrings = yticklabels

        elseif ytickp isa NTuple{2, <: MakieLayout.Side}

            xpos1 = limits[ytickp[1]]
            xpos2 = limits[ytickp[2]]

            ytickpositions = Point2f0.([(x, y) for x in (xpos1, xpos2), y in ytickvalues[]])

            ytickstrings = repeat(yticklabels, 2)

        else
            @warn "Unsupported tick position format given!"
        end

        (isnothing(ytickstrings) || isnothing(ytickpositions)) || (ytickannotations[] = to2tuple.(ytickstrings, transform.(source, dest, ytickpositions)))

        xtickpositions, xtickstrings = (nothing, nothing)

        if typeof(xtickp) <: MakieLayout.Side

            ypos = limits[xtickp]

            xtickpositions = Point2f0.(xtickvalues[], ypos)

            xtickstrings = xticklabels

        elseif xtickp isa NTuple{2, <: MakieLayout.Side}

            ypos1 = limits[ytickp[1]]
            ypos2 = limits[ytickp[2]]

            xtickpositions = Point2f0.([(x, y) for y in (ypos1, ypos2), x in xtickvalues[]])

            xtickstrings = repeat(xticklabels, 2)

        else
            @warn "Unsupported tick position format given!" xtickp
        end

        (isnothing(xtickstrings) || isnothing(xtickpositions)) || (xtickannotations[] = to2tuple.(xtickstrings, transform.(source, dest, xtickpositions)))

    end

    # plot the damn thing

    # x ticks
    lines!(
        plot,
        xlinevec;
        visible = x.tick.visible,
        color   = x.tick.color,
        align   = x.tick.align,
        linewidth = x.tick.width,
        linestyle = x.tick.style,
    )
    # y ticks
    lines!(
        plot,
        ylinevec;
        visible = y.tick.visible,
        color   = y.tick.color,
        align   = y.tick.align,
        linewidth = y.tick.width,
        linestyle = y.tick.style,
    )

    # annotations

    annotations!(
        plot,
        x.tick.label,
        xtickannotations;
    )

    annotations!(
        plot,
        y.tick.label,
        ytickannotations;
    )

end
