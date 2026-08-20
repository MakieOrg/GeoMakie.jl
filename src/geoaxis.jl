#=
# GeoAxis
=#

const Rect2d = Rect2{Float64}

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
        "Placement direction for longitude tick labels. `:axis` moves labels vertically; `:normal` follows the projected boundary normal."
        xticklabelplacement::Symbol = :axis
        "Placement direction for latitude tick labels. `:axis` moves labels horizontally; `:normal` follows the projected boundary normal."
        yticklabelplacement::Symbol = :axis
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
        # "The width of the axis spines."
        # spinewidth::Float64 = 1f0
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
        # "Controls if the axis spine is visible."
        # spinevisible::Bool = true
        # "The color of the axis spine."
        # spinecolor::RGBAf = :black
        # spinetype::Symbol = :geospine
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

        xaxisposition::Symbol = :bottom
        yaxisposition::Symbol = :left

    end
end

# Makie generic object API
Makie.transform_func(ax::GeoAxis) = ax.transform_func[]

# Spines

const SpinePoint = NamedTuple{(:input, :projected, :dir, :intersect_dir),Tuple{Point2d,Point2d,Point2d,Point2d}}

struct Spines
    top::Vector{SpinePoint}
    bottom::Vector{SpinePoint}
    left::Vector{SpinePoint}
    right::Vector{SpinePoint}
end

Spines() = Spines(SpinePoint[], SpinePoint[], SpinePoint[], SpinePoint[])

"""
    clip_segment_to_rect(rect, line_start, line_end)

Clip a projected line segment to `rect` with the Liang--Barsky algorithm.  The
return value is `(start, stop, start_side, stop_side, t_start, t_stop)`, where
either side is `nothing` when the corresponding endpoint was already inside
the rectangle and the `t` values locate the endpoints on the original
segment.  Unlike testing endpoint membership, this also finds segments whose
two endpoints are outside but which pass through the rectangle.
"""
function clip_segment_to_rect(rect::Rect2, line_start::Point2, line_end::Point2)
    mini, maxi = extrema(rect)
    delta = line_end - line_start

    bottom = Line(Point2d(mini[1], mini[2]), Point2d(maxi[1], mini[2]))
    right = Line(Point2d(maxi[1], mini[2]), Point2d(maxi[1], maxi[2]))
    top = Line(Point2d(maxi[1], maxi[2]), Point2d(mini[1], maxi[2]))
    left = Line(Point2d(mini[1], maxi[2]), Point2d(mini[1], mini[2]))

    # Each `p * t <= q` constraint carries the rectangle side at equality.
    constraints = (
        (-delta[1], line_start[1] - mini[1], left),
        ( delta[1], maxi[1] - line_start[1], right),
        (-delta[2], line_start[2] - mini[2], bottom),
        ( delta[2], maxi[2] - line_start[2], top),
    )

    t_start, t_stop = 0.0, 1.0
    start_side = nothing
    stop_side = nothing
    for (p, q, side) in constraints
        if iszero(p)
            q < 0 && return nothing
            continue
        end

        t = q / p
        if p < 0 # entering the rectangle
            t > t_stop && return nothing
            if t > t_start
                t_start = t
                start_side = side
            end
        else # leaving the rectangle
            t < t_start && return nothing
            if t < t_stop
                t_stop = t
                stop_side = side
            end
        end
    end

    t_stop < t_start && return nothing
    # Preserve original in-bounds endpoints exactly.  Recomputing `a + 0d` or
    # `a + 1d` can differ by a few ulps, which would incorrectly split two
    # consecutive sampled segments into separate components.
    clipped_start = iszero(t_start) ? Point2d(line_start) : Point2d(line_start + t_start * delta)
    clipped_stop = isone(t_stop) ? Point2d(line_end) : Point2d(line_start + t_stop * delta)
    return clipped_start, clipped_stop, start_side, stop_side, t_start, t_stop
end

"""
    valid_line_in_limits(trans, trans_rev, rect, point_start, point_stop, n=100)

Sample a source-space line, project it, and return every connected component
inside `rect`.  Components are kept in traversal order and their first/last
rectangle intersection sides are returned alongside them.

Non-finite projected samples split the input into separate finite runs.  Each
finite segment is clipped independently, which is important both for
interrupted projections and for outside-to-outside segments that cross the
visible rectangle.
"""
function valid_line_in_limits(trans, trans_rev, rect, point_start, point_stop, n=100)
    xrange = LinRange(point_start[1], point_stop[1], n)
    yrange = LinRange(point_start[2], point_stop[2], n)
    lines = Vector{Point2d}[]
    lines_t = Vector{Point2d}[]

    # With non linear transforms, we need to check points inbetween for intersections
    # So we transform all points first and filter out non finite results
    was_finite = false
    for i in 1:n
        point = Point2d(xrange[i], yrange[i])
        point_t = Makie.apply_transform(trans, point)
        if isfinite(point_t)
            if !was_finite
                push!(lines, Point2d[])
                push!(lines_t, Point2d[])
            end
            push!(lines[end], point)
            push!(lines_t[end], point_t)
            was_finite = true
        else
            was_finite = false
        end
    end

    lines_inside = Vector{Point2d}[]
    lines_inside_t = Vector{Point2d}[]
    intersections = Vector{Union{Line{2,Float64},Nothing}}[]
    for (points, points_t) in zip(lines, lines_t)
        current_component = 0
        for (a, b, a_t, b_t) in zip(points[1:end-1], points[2:end], points_t[1:end-1], points_t[2:end])
            # PROJ's interrupted projections can jump between two finite
            # coordinates.  A midpoint transformed far away from the chord's
            # midpoint identifies that discontinuity without using a
            # projection-specific distance threshold.
            source_midpoint = Point2d((a + b) / 2)
            projected_midpoint = Makie.apply_transform(trans, source_midpoint)
            chord_midpoint = Point2d((a_t + b_t) / 2)
            chord_length = norm(b_t - a_t)
            midpoint_error = norm(projected_midpoint - chord_midpoint)
            continuity_scale = max(chord_length, sqrt(eps(Float64)) * norm(widths(rect)))
            if !isfinite(projected_midpoint) ||
                    midpoint_error > 0.25 * continuity_scale
                current_component = 0
                continue
            end

            clipped = clip_segment_to_rect(rect, a_t, b_t)
            if isnothing(clipped)
                current_component = 0
                continue
            end

            clipped_start_t, clipped_stop_t, start_side, stop_side, t_start, t_stop = clipped
            # A tangent contact is a point, not a drawable connected component.
            clipped_start_t == clipped_stop_t && continue

            clipped_start = if iszero(t_start)
                a
            else
                Makie.apply_transform(trans_rev, clipped_start_t)
            end
            clipped_stop = if isone(t_stop)
                b
            else
                Makie.apply_transform(trans_rev, clipped_stop_t)
            end

            # Consecutive clipped segments share an exact transformed sample.
            # Otherwise an out-of-bounds gap separates two components.
            continues_component = current_component > 0 &&
                lines_inside_t[current_component][end] == clipped_start_t
            if !continues_component
                push!(lines_inside, Point2d[])
                push!(lines_inside_t, Point2d[])
                push!(intersections, Union{Line{2,Float64},Nothing}[start_side, stop_side])
                current_component = length(lines_inside)
                push!(lines_inside[current_component], clipped_start, clipped_stop)
                push!(lines_inside_t[current_component], clipped_start_t, clipped_stop_t)
            else
                push!(lines_inside[current_component], clipped_stop)
                push!(lines_inside_t[current_component], clipped_stop_t)
                intersections[current_component][2] = stop_side
            end
        end
    end
    return lines_inside, lines_inside_t, intersections
end

function add_to_lines!(result, valid_line, line_transformed, intersections, spine_start, spine_end, dim)
    varying_dim = dim == 1 ? 2 : 1
    # Sampling is monotonic in source space.  Reverse whole components when
    # necessary instead of independently sorting their vertices, which would
    # destroy path order for interrupted or folded projections.
    if valid_line[1][varying_dim] > valid_line[end][varying_dim]
        valid_line = reverse(valid_line)
        line_transformed = reverse(line_transformed)
        intersections = reverse(intersections)
    end

    append!(result, line_transformed)
    push!(result, Point2d(NaN))

    # Add normal vector for ticks
    i_start, i_end = intersections

    if !isnothing(spine_start)
        v1_t, v2_t = line_transformed[1], line_transformed[2]
        dir = normalize(v1_t .- v2_t)
        if !isnothing(i_start)
            intersect_dir = i_start[1] .- i_start[2]
        else
            intersect_dir = Point2d(NaN)
        end
        push!(spine_start, (input=valid_line[1], projected=v1_t, dir=dir, intersect_dir=intersect_dir))
    end

    if !isnothing(spine_end)
        s_1_t, s_2_t = line_transformed[end], line_transformed[end-1]
        dir = normalize(s_1_t .- s_2_t)
        if !isnothing(i_end)
            intersect_dir = i_end[1] .- i_end[2]
        else
            intersect_dir = Point2d(NaN)
        end
        push!(spine_end, (input=valid_line[end], projected=s_1_t, dir=dir, intersect_dir=intersect_dir))
    end
end

function project_tick_points!(result, trans, trans_inverse, range, coordinate, dim, limit_rect, spine_start, spine_end)
    # dim == 1, is for longitude ticks

    point_fun(tick) = dim === 1 ? Point2(coordinate, tick) : Point2(tick, coordinate)

    start = point_fun(range[1])
    stop = point_fun(range[end])

    lines, lines_transformed, intersections = valid_line_in_limits(trans, trans_inverse, limit_rect, start, stop)
    valid_components = findall(i -> length(lines[i]) >= 2, eachindex(lines))
    isempty(valid_components) && return

    # A graticule may have several visible components.  The source-space
    # extrema, which can belong to different components, are its genuine two
    # endpoints.  Selecting them explicitly prevents a short first component
    # from donating both tick anchors.
    varying_dim = dim == 1 ? 2 : 1
    start_component = argmin(i -> minimum(p[varying_dim] for p in lines[i]), valid_components)
    end_component = argmax(i -> maximum(p[varying_dim] for p in lines[i]), valid_components)

    for i in valid_components
        add_to_lines!(
            result, lines[i], lines_transformed[i], intersections[i],
            i == start_component ? spine_start : nothing,
            i == end_component ? spine_end : nothing,
            dim,
        )
    end
    return
end

function _geo_ticklabel_strings(formatter, values)
    if formatter isa Makie.Automatic
        return geoformat_ticklabels(values)
    end
    return Makie.get_ticklabels(formatter, values)
end

function _geo_ticklabel_candidates(
        samples, coordinate_dim, side, formatter, font, fontsize, pad, rotation, mode;
        corner_anchors = SpinePoint[], occupied = Rect2d[], collision_gap = 2.0)
    mode = _geo_ticklabel_mode(mode)
    side = _geo_ticklabel_side(side)
    isempty(samples) && return (Point2d[], Any[], NamedTuple[])

    values = [round(p.input[coordinate_dim]; sigdigits = 3) for p in samples]
    labels = _geo_ticklabel_strings(formatter, values)
    length(labels) == length(samples) || error(
        "tick formatter returned $(length(labels)) labels for $(length(samples)) ticks")

    # Prefer labels near the middle of a side.  This makes overlap filtering
    # stable and keeps the most informative central label when anchors collapse
    # at a projection pole.
    tangential_dim = side in (:bottom, :top) ? 1 : 2
    side_middle = median([p.projected[tangential_dim] for p in samples])
    priority = sortperm(eachindex(samples); by = i ->
        abs(samples[i].projected[tangential_dim] - side_middle))

    accepted = NamedTuple[]
    accepted_indices = Int[]
    accepted_boxes = Rect2d[occupied...]
    for i in priority
        sample = samples[i]
        isfinite(sample.input) || continue
        _geo_ticklabel_corner_anchor(sample, corner_anchors) && continue

        bb = Makie.text_bb(string(labels[i]), font, fontsize)
        half_extents = Point2d(widths(bb) ./ 2)
        placement = _geo_ticklabel_placement(
            samples, i, side, half_extents, pad; mode, rotation)
        isnothing(placement) && continue
        collides = any(accepted_boxes) do other
            _geo_ticklabel_bboxes_overlap(placement.bbox, other) ||
                _geo_ticklabel_bbox_gap(placement.bbox, other) < collision_gap
        end
        collides && continue

        push!(accepted, placement)
        push!(accepted_indices, i)
        push!(accepted_boxes, placement.bbox)
    end

    order = sortperm(accepted_indices)
    indices = accepted_indices[order]
    placements = accepted[order]
    return (
        Point2d[p.center for p in placements],
        Any[labels[i] for i in indices],
        placements,
    )
end

function Makie.initialize_block!(axis::GeoAxis)

    _geo_ticklabel_mode(axis.xticklabelplacement[])
    _geo_ticklabel_mode(axis.yticklabelplacement[])

    # Set up transformations first, so that the scene can be set up
    # and linked to those.
    transform_obs = Observable{Any}(identity; ignore_equal_values=true)
    transform_inv_obs = Observable{Any}(identity; ignore_equal_values=true)
    transform_ticks_obs = Observable{Any}(identity; ignore_equal_values=true)
    transform_ticks_inv_obs = Observable{Any}(identity; ignore_equal_values=true)
    setfield!(axis, :transform_func, transform_obs)
    setfield!(axis, :inv_transform_func, transform_inv_obs)

    # Set up the axis for the Scene, mostly using Makie's existing functionality
    scene = axis_setup!(axis)

    # Shorthand for what you see below - ONLY ACCESSIBLE WITHIN THIS FUNCTION!!
    Obs(x) = Observable(x; ignore_equal_values=true)

    # Keep the transformations up to date.
    onany(scene, axis.dest, axis.source; update=true) do tp, sp
        # First we perform the transformation for the axis,
        trans = create_transform(tp, sp)
        transform_obs[] = trans
        transform_inv_obs[] = Makie.inverse_transform(trans)
        # and next for the ticks - this assumes an input CRS in
        # PROJ-string format, which is not necessarily the case, but suffices for now.
        # What this should do, is check using Proj whether the input CRS is equivalent
        # to EPSG 4326, which is actually quite doable - especially using a cache of some kind.
        # What this is actually doing, is creating a transformation that takes the input CRS
        # and transforms it to the WGS84 CRS, which is how we display the ticks.
        # If you wanted ticks in the input CRS, you'd have to wait until a generic `NonlinearAxis`
        # is implemented, which would then not have any special treatment for geographic stuff.
        if sp == "+proj=longlat +datum=WGS84" || sp == "+proj=latlong +datum=WGS84 +type=crs" || sp == GeoFormatTypes.EPSG(4326)
            transform_ticks_obs[] = trans
            transform_ticks_inv_obs[] = transform_inv_obs[]
        else
            transform_ticks_obs[] = create_transform(tp, "+proj=longlat +datum=WGS84")
            transform_ticks_inv_obs[] = create_transform("+proj=longlat +datum=WGS84", tp)
        end
    end


    lonticks_line_obs = Obs(Point2d[])
    latticks_line_obs = Obs(Point2d[])

    spines_obs = Obs(Spines())
    finallimits = map(identity, scene, axis.finallimits; ignore_equal_values=true)
    vp_unchanged = map(identity, scene, scene.viewport; ignore_equal_values=true)
    # This is kind of the main redrawing loop for the axis.  This should really be
    # factored out into a sync and async function, so that zooming is fluid, but
    # we can figure that out later.
    # What this does is first calculate limits and ticks, then create spines and
    # project them.  Those are stored in Observables which are used to produce
    # lineplots later on that form the grid.
    # TODO: implement a minor grid.
    onany(scene, axis.xticks, axis.yticks, axis.limits,
        transform_ticks_obs, finallimits, vp_unchanged;
        update=true) do user_xticks, user_yticks, user_limits, trans, fl, vp

        lon_transformed = Point2d[]
        lat_transformed = Point2d[]
        limit_rect = Makie.to_value(axis.finallimits)
        trans_inverse = Makie.to_value(transform_ticks_inv_obs)

        limits_t = Makie.apply_transform(trans_inverse, limit_rect)
        xlims = Makie.xlimits(limits_t)
        ylims = Makie.ylimits(limits_t)

        # Inverse projection is ambiguous across a shifted antimeridian.  When
        # the user supplied source-space limits, retain those as the tracing
        # range instead of accepting PROJ's normalized longitude branch.
        requested_xlims, requested_ylims = Makie.convert_limit_attribute(user_limits)
        trace_xlims = if requested_xlims isa Tuple && all(!isnothing, requested_xlims)
            extrema(Float64.(requested_xlims))
        else
            xlims
        end
        trace_ylims = if requested_ylims isa Tuple && all(!isnothing, requested_ylims)
            extrema(Float64.(requested_ylims))
        else
            ylims
        end

        xticks = user_xticks isa Makie.Automatic ? geoticks(-180, 180, xlims...) : Makie.get_tickvalues(user_xticks, xlims...)
        yticks = user_yticks isa Makie.Automatic ? geoticks(-90, 90, ylims...) : Makie.get_tickvalues(user_yticks, ylims...)

        spines = spines_obs[]
        foreach(empty!, [spines.left, spines.right, spines.bottom, spines.top])
        for lon in xticks
            # Tick values select graticules; they must not also truncate them.
            # Trace each one across the complete inverse-transformed view and
            # let `valid_line_in_limits` clip it in projected space.
            range = LinRange(trace_ylims..., 100)
            project_tick_points!(lon_transformed, trans, trans_inverse, range, lon, 1, limit_rect, spines.bottom, spines.top)
        end

        for lat in yticks
            range = LinRange(trace_xlims..., 100)
            project_tick_points!(lat_transformed, trans, trans_inverse, range, lat, 2, limit_rect,
                                 spines.left, spines.right)
        end
        lonticks_line_obs[] = lon_transformed
        latticks_line_obs[] = lat_transformed
        notify(spines_obs)
        return
    end
    # These are the grid plots from earlier.
    longridplot = lines!(scene, lonticks_line_obs; color=axis.xgridcolor, linewidth=axis.xgridwidth,
        visible=axis.xgridvisible, linestyle=axis.xgridstyle, transparency=true, inspectable=false)
    translate!(longridplot, 0, 0, 100)
    latgridplot = lines!(scene, latticks_line_obs; color=axis.ygridcolor, linewidth=axis.ygridwidth,
        visible=axis.ygridvisible, linestyle=axis.ygridstyle, transparency=true, inspectable=false)
    translate!(latgridplot, 0, 0, 100)

    # Project boundary anchors and their directions into pixel space, where
    # glyph dimensions and padding have a stable meaning.
    cam = scene.camera
    pixel_spines = Obs(Spines())
    onany(scene, spines_obs, cam.projectionview, vp_unchanged) do spines, pv, area
        poffset = minimum(area)
        project_px(p) = to_ndim(Point2d, Makie.project(cam, :data, :pixel, p), 0.0f0) .+ poffset
        function project_vector(anchor, vector)
            isfinite(vector) || return Point2d(NaN)
            return project_px(anchor + vector) - project_px(anchor)
        end
        function project_p(p)
            return (
                input = p.input,
                projected = project_px(p.projected),
                dir = project_vector(p.projected, p.dir),
                intersect_dir = project_vector(p.projected, p.intersect_dir),
            )
        end

        # Longitude wrapping can make the source-low endpoint land on the
        # visual right and the source-high endpoint land on the visual left.
        # Classify latitude anchors by their projected outward direction rather
        # than trusting source-space low/high naming.
        latitude_anchors = vcat(project_p.(spines.left), project_p.(spines.right))
        left = sort(filter(p -> isfinite(p.dir) && p.dir[1] < 0, latitude_anchors);
            by = p -> p.input[2])
        right = sort(filter(p -> isfinite(p.dir) && p.dir[1] > 0, latitude_anchors);
            by = p -> p.input[2])
        bottom = sort(project_p.(spines.bottom); by = p -> p.input[1])
        top = sort(project_p.(spines.top); by = p -> p.input[1])
        pixel_spines[] = Spines(top, bottom, left, right)
        return
    end

    xticklabelplot = text!(axis.blockscene, Point2d[];
        text=Any[], space=:pixel, align=(:center, :center),
        rotation=axis.xticklabelrotation,
        font=axis.xticklabelfont, color=axis.xticklabelcolor,
        fontsize=axis.xticklabelsize, visible=axis.xticklabelsvisible,
    )

    yticklabelplot = text!(axis.blockscene, Point2d[];
        text=Any[], space=:pixel, align=(:center, :center),
        rotation=axis.yticklabelrotation,
        font=axis.yticklabelfont, color=axis.yticklabelcolor,
        fontsize=axis.yticklabelsize, visible=axis.yticklabelsvisible,
    )

    fonts = theme(axis.blockscene, :fonts)
    onany(
        scene, pixel_spines, axis.xaxisposition, axis.yaxisposition,
        axis.xtickformat, axis.ytickformat,
        axis.xticklabelfont, axis.yticklabelfont,
        axis.xticklabelsize, axis.yticklabelsize,
        axis.xticklabelpad, axis.yticklabelpad,
        axis.xticklabelrotation, axis.yticklabelrotation,
        axis.xticklabelplacement, axis.yticklabelplacement,
    ) do spines, xside, yside, xformat, yformat, xfont, yfont,
            xsize, ysize, xpad, ypad, xrotation, yrotation, xmode, ymode
        xside in (:bottom, :top) || throw(ArgumentError(
            "xaxisposition must be :bottom or :top, got $xside"))
        yside in (:left, :right) || throw(ArgumentError(
            "yaxisposition must be :left or :right, got $yside"))
        _geo_ticklabel_mode(xmode)
        _geo_ticklabel_mode(ymode)

        xsamples = getproperty(spines, xside)
        ysamples = getproperty(spines, yside)
        xpositions, xlabels, xplacements = _geo_ticklabel_candidates(
            xsamples, 1, xside, xformat, Makie.to_font(fonts, xfont),
            xsize, xpad, xrotation, xmode,
        )
        ypositions, ylabels, _ = _geo_ticklabel_candidates(
            ysamples, 2, yside, yformat, Makie.to_font(fonts, yfont),
            ysize, ypad, yrotation, ymode;
            corner_anchors = vcat(spines.bottom, spines.top),
            occupied = Rect2d[p.bbox for p in xplacements],
        )

        # Keep positions and text lengths synchronized through Makie's compute
        # graph when ticks or limits change interactively.
        Makie.update!(xticklabelplot; arg1=xpositions, text=xlabels)
        Makie.update!(yticklabelplot; arg1=ypositions, text=ylabels)
        return
    end

    # Finally calculate protrusions and report all bounding boxes
    # to the layout system.
    approx_x_protrusion = map(
        axis.blockscene, 
        axis.xticklabelfont, axis.xticklabelsize, axis.xticklabelpad,
        xticklabelplot.text, axis.xticklabelsvisible,
        ) do ticklabel_font, ticklabel_size, ticklabel_pad, text, ticklabelsvisible
        ret = 0.0f0

        if ticklabelsvisible
            max_height = 0.0
            for str in text
                bb = Makie.text_bb(str, Makie.to_font(fonts, ticklabel_font), ticklabel_size)
                max_height = max(max_height, widths(bb)[2])
            end
            ret += max_height + ticklabel_pad
        end

        return ret
    end

    approx_y_protrusion = map(
        axis.blockscene, 
        axis.yticklabelfont, axis.yticklabelsize, axis.yticklabelpad,
        yticklabelplot.text, axis.yticklabelsvisible,
        ) do ticklabel_font, ticklabel_size, ticklabel_pad, text, ticklabelsvisible

        ret = 0.0f0

        if ticklabelsvisible
            max_width = 0.0
            for str in text
                bb = Makie.text_bb(str, Makie.to_font(fonts, ticklabel_font), ticklabel_size)
                max_width = max(max_width, widths(bb)[1])
            end
            ret += max_width + ticklabel_pad
        end

        return ret

    end

    elements = Dict{Symbol,Any}()
    setfield!(axis, :elements, elements)
    elements[:xgrid] = longridplot
    elements[:ygrid] = latgridplot
    elements[:xticklabels] = xticklabelplot
    elements[:yticklabels] = yticklabelplot

    subtitlepos = lift(axis.blockscene, scene.viewport, axis.titlegap, axis.titlealign, axis.xaxisposition;
        ignore_equal_values=true) do a,
    titlegap, align, xaxisposition
        xaxisprotrusion = 0f0
        align_factor = Makie.halign2num(align, "Horizontal title align $align not supported.")
        x = a.origin[1] + align_factor * a.widths[1]

        yoffset = Makie.top(a) + titlegap + (xaxisposition === (:top) ? xaxisprotrusion : 0.0f0)

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
        axis.titlealign, axis.xaxisposition, Observable(0f0), axis.subtitlelineheight, axis, subtitlet; ignore_equal_values=true)

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

    xaxis = (; protrusion=approx_x_protrusion)
    yaxis = (; protrusion=approx_y_protrusion)
    map!(compute_protrusions, axis.blockscene, axis.layoutobservables.protrusions, axis.title, axis.titlesize,
        axis.titlegap, axis.titlevisible,
        xaxis.protrusion, 
        yaxis.protrusion,
        axis.subtitle, axis.subtitlevisible, axis.subtitlesize, axis.subtitlegap,
        axis.titlelineheight, axis.subtitlelineheight, subtitlet, titlet)

    fl = axis.finallimits[]
    notify(axis.limits)
    if fl == axis.finallimits[]
        notify(axis.finallimits)
    end

    return axis
end

# TODO, this just pads all protrusions
# We'll need to figure out which protrusion actually contains any labels
# To correctly calculate the protrusions
function compute_protrusions(title, titlesize, titlegap, titlevisible,
    xaxisprotrusion, yaxisprotrusion,
    subtitle, subtitlevisible, subtitlesize, subtitlegap, titlelineheight, subtitlelineheight,
    subtitlet, titlet)

    local left::Float32, right::Float32, bottom::Float32, top::Float32 = 0.0f0, 0.0f0, 0.0f0, 0.0f0

    bottom = xaxisprotrusion
    top = xaxisprotrusion

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

    top += titlespace + subtitlespace

    left = yaxisprotrusion
    right = yaxisprotrusion

    return GridLayoutBase.RectSides{Float32}(left, right, bottom, top)
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
