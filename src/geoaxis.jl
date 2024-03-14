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

const SpinePoint = NamedTuple{(:input, :projected, :dir, :intersect_dir),Tuple{Point2d,Point2d,Point2d,Point2d}}

struct Spines
    top::Vector{SpinePoint}
    bottom::Vector{SpinePoint}
    left::Vector{SpinePoint}
    right::Vector{SpinePoint}
end

Spines() = Spines(SpinePoint[], SpinePoint[], SpinePoint[], SpinePoint[])

function interset_rect(rect::Rect2, line_start::Point2, line_end::Point2)
    mini, maxi = extrema(rect)
    line = Line(line_start, line_end)

    # Bottom Side
    side = Line(Point2{Float64}(mini[1], mini[2]), Point2{Float64}(maxi[1], mini[2]))
    intersected, p = intersects(side, line)
    intersected && return p, side

    # Right side
    side = Line(Point2{Float64}(maxi[1], mini[2]), Point2{Float64}(maxi[1], maxi[2]))
    intersected, p = intersects(side, line)
    intersected && return p, side

    # Top side
    side = Line(Point2{Float64}(maxi[1], maxi[2]), Point2{Float64}(mini[1], maxi[2]))
    intersected, p = intersects(side, line)
    intersected && return p, side

    # Left side
    side = Line(Point2{Float64}(mini[1], maxi[2]), Point2{Float64}(mini[1], mini[2]))
    intersected, p = intersects(side, line)
    intersected && return p, side
    return nothing, nothing
end

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
    lines_inside_t = Vector{Point2d}[]
    intersections = Vector{Union{Line{2,Float64},Nothing}}[]
    for (points, points_t) in zip(lines, lines_t)
        was_inside = false

        for (a, b, a_t, b_t) in zip(points[1:end-1], points[2:end], points_t[1:end-1], points_t[2:end])
            a_in = a_t in rect
            b_in = b_t in rect
            if !was_inside && (a_in || b_in)
                push!(lines_inside, Point2d[])
                push!(lines_inside_t, Point2d[])
                push!(intersections, Union{Line{2,Float64},Nothing}[nothing, nothing])
            end
            if a_in && b_in
                was_inside = true
                push!(lines_inside[end], a)
                push!(lines_inside[end], b)

                push!(lines_inside_t[end], a_t)
                push!(lines_inside_t[end], b_t)
            elseif a_in
                had_points = isempty(lines_inside[end])
                push!(lines_inside[end], a)
                push!(lines_inside_t[end], a_t)
                p, iline = interset_rect(rect, a_t, b_t)
                if !isnothing(p)
                    if had_points
                        intersections[end][1] = iline
                    else
                        intersections[end][2] = iline
                    end
                    push!(lines_inside[end], Makie.apply_transform(trans_rev, p))
                    push!(lines_inside_t[end], p)
                end
                was_inside = false
            elseif b_in
                had_points = isempty(lines_inside[end])
                push!(lines_inside[end], b)
                push!(lines_inside_t[end], b_t)
                p, iline = interset_rect(rect, a_t, b_t)
                if !isnothing(p)
                    if had_points
                        intersections[end][1] = iline
                    else
                        intersections[end][2] = iline
                    end
                    push!(lines_inside[end], Makie.apply_transform(trans_rev, p))
                    push!(lines_inside_t[end], p)
                end
                was_inside = false
            else
                was_inside = false
            end
        end
    end
    return lines_inside, lines_inside_t, intersections
end

function add_to_lines!(result, valid_line, line_transformed, intersections, spine_start, spine_end, dim)
    idx = sortperm(valid_line, by=x -> x[dim == 1 ? 2 : 1])
    line_transformed = line_transformed[idx]
    valid_line = valid_line[idx]

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
    spine_start_length = length(spine_start)
    spine_end_length = length(spine_end)
    for (line, line_t, intersect) in zip(lines, lines_transformed, intersections)
        length(line) < 2 && continue
        # Only add one start/end to spine
        _spine_start = spine_start_length == length(spine_start) ? spine_start : nothing
        _spine_end = spine_end_length == length(spine_end) ? spine_end : nothing
        add_to_lines!(result, line, line_t, intersect, _spine_start, _spine_end, dim)
    end
    return
end

function mean_distances(points)
    dists = Float64[]
    last_px = points[1].projected
    for px in @view points[2:end]
        push!(dists, norm(last_px .- px.projected))
        last_px = px.projected
    end
    return mean(dists)
end

# Choses the spine with the biggest mean distance between points
function choose_side(a, b)
    isempty(a) && return b
    isempty(b) && return a
    distsa = mean_distances(a)
    distsb = mean_distances(b)
    distsa - distsb < 3 && return a
    return distsb <= distsa ? a : b
end

function angle_between(v1::Point, v2::Point)
    dot_product = dot(v1, v2)
    norms = norm(v1) * norm(v2)
    angle = acos(dot_product / norms)
    return angle
end

function vis_spine!(points, text, points_px, d, mindist, labeloffset)
    last_point = nothing
    for p in points
        p_px = p.projected
        if !isnothing(last_point)
            dist = norm(last_point .- p_px)
            dist < mindist && continue
        else
            last_point = p_px
        end
        if norm(p.dir) < 0.1
            continue
        end
        !isfinite(p.input) && continue
        if isfinite(p.intersect_dir)
            line_dir = p.intersect_dir
            dir = normalize(Point2d(-line_dir[2], line_dir[1]))
        else
            dir = p.dir
        end
        last_point = p_px
        # TODO use xticklabelspace
        # TODO use xticklabelpad
        p_offset = p_px .+ (p.dir .* (3 * labeloffset))
        push!(points_px, p_offset)
        push!(text, string(round(Int, p.input[d]), "°"))
    end
end

function closest_multiple(M, N)
    # Step 1: Find the quotient
    quotient = N ÷ M

    # Step 2: Get the multiple of M just less than or equal to N
    lower_multiple = N ÷ quotient

    # Step 3: Check if the next multiple is closer
    upper_multiple = N ÷ (quotient + 1)

    # Determine which multiple is closer to N
    if abs(N - lower_multiple) <= abs(N - upper_multiple)
        return lower_multiple
    else
        return upper_multiple
    end
end

function default_ticks(dmini, dmaxi, mini, maxi)
    if isfinite(mini) && isfinite(maxi)
        mini, maxi = min(maxi, mini), max(maxi, mini)
        step = max(1, closest_multiple((maxi - mini) / 12, dmaxi))
        return dmini:step:dmaxi
    else
        return dmini:30:dmaxi
    end
end

function filter_too_close(point, all_points)
    a = point.projected
    for p in all_points
        b = p.projected
        if norm(a .- b) < 30
            return false
        end
    end
    return true
end

function Makie.initialize_block!(axis::GeoAxis)
    scene = axis_setup!(axis)
    Obs(x) = Observable(x; ignore_equal_values=true)

    transform_obs = Observable{Any}(nothing; ignore_equal_values=true)
    transform_inv_obs = Observable{Any}(nothing; ignore_equal_values=true)
    transform_ticks_obs = Observable{Any}(nothing; ignore_equal_values=true)
    transform_ticks_inv_obs = Observable{Any}(nothing; ignore_equal_values=true)

    onany(scene, axis.dest, axis.source; update=true) do tp, sp
        trans = create_transform(tp, sp)
        transform_obs[] = trans
        transform_inv_obs[] = Makie.inverse_transform(trans)
        if sp == "+proj=longlat +datum=WGS84"
            transform_ticks_obs[] = trans
            transform_ticks_inv_obs = transform_inv_obs[]
        else
            transform_ticks_obs[] = create_transform(tp, "+proj=longlat +datum=WGS84")
            transform_ticks_inv_obs[] = create_transform("+proj=longlat +datum=WGS84", tp)
        end
    end

    setfield!(axis, :transform_func, transform_obs)

    lonticks_line_obs = Obs(Point2d[])
    latticks_line_obs = Obs(Point2d[])

    spines_obs = Obs(Spines())
    finallimits = map(identity, scene, axis.finallimits; ignore_equal_values=true)
    vp_unchanged = map(identity, scene, scene.viewport; ignore_equal_values=true)

    onany(scene, axis.xticks, axis.yticks, transform_ticks_obs, finallimits, vp_unchanged;
        update=true) do user_xticks, user_yticks, trans, fl, vp

        lon_transformed = Point2d[]
        lat_transformed = Point2d[]
        limit_rect = axis.finallimits[]
        trans_inverse = transform_ticks_inv_obs[]

        limits_t = Makie.apply_transform(trans_inverse, limit_rect)
        xlims = Makie.xlimits(limits_t)
        ylims = Makie.ylimits(limits_t)

        xticks = user_xticks isa Makie.Automatic ? default_ticks(-180, 180, xlims...) : Makie.get_tickvalues(user_xticks, xlims...)
        yticks = user_yticks isa Makie.Automatic ? default_ticks(-90, 90, ylims...) : Makie.get_tickvalues(user_yticks, ylims...)

        spines = spines_obs[]
        foreach(empty!, [spines.left, spines.right, spines.bottom, spines.top])
        for lon in xticks
            range = LinRange(yticks[1], yticks[end], 100)
            project_tick_points!(lon_transformed, trans, trans_inverse, range, lon, 1, limit_rect, spines.bottom, spines.top)
        end

        for lat in yticks
            range = LinRange(xticks[1], xticks[end], 100)
            project_tick_points!(lat_transformed, trans, trans_inverse, range, lat, 2, limit_rect,
                                 spines.left, spines.right)
        end
        lonticks_line_obs[] = lon_transformed
        latticks_line_obs[] = lat_transformed
        notify(spines_obs)
        return
    end

    longridplot = lines!(scene, lonticks_line_obs; color=axis.xgridcolor, linewidth=axis.xgridwidth,
        visible=axis.xgridvisible, linestyle=axis.xgridstyle, transparency=true)
    translate!(longridplot, 0, 0, 100)
    latgridplot = lines!(scene, latticks_line_obs; color=axis.ygridcolor, linewidth=axis.ygridwidth,
        visible=axis.ygridvisible, linestyle=axis.ygridstyle, transparency=true)
    translate!(latgridplot, 0, 0, 100)


    cam = scene.camera
    lon_spine = Obs(SpinePoint[])
    lon_text = Obs([""])
    lon_points_px = Obs(Point2d[])

    lat_spine = Obs(SpinePoint[])
    lat_text = Obs([""])
    lat_points_px = Obs(Point2d[])

    onany(scene, spines_obs, cam.projectionview, vp_unchanged) do spines, pv, area
        poffset = minimum(area)
        project_px(p) = to_ndim(Point2d, Makie.project(cam, :data, :pixel, p), 0.0f0) .+ poffset
        project_p(p) = (input=p.input, projected=project_px(p.projected), dir=p.dir, intersect_dir=p.intersect_dir)

        left = project_p.(spines.left)
        right = project_p.(spines.right)
        bottom = project_p.(spines.bottom)
        top = project_p.(spines.top)

        lonspine = choose_side(left, right)
        latspine = choose_side(bottom, top)

        # Filter out ticks that go almost parallel to boundingbox
        function too_narrow(p)
            if isfinite(p.intersect_dir)
                line_dir = p.intersect_dir
                a = abs(angle_between(p.dir, line_dir))
                (a < 0.2 || abs(pi - a) < 0.2) && return false
            end
            return true
        end

        filter!(too_narrow, lonspine)
        filter!(too_narrow, latspine)

        filter!(p -> filter_too_close(p, latspine), lonspine)
        filter!(p -> filter_too_close(p, lonspine), latspine)
        lon_spine[] = lonspine
        lat_spine[] = latspine
        return
    end

    onany(lat_spine, axis.xlabelpadding, axis.xticklabelsize) do spine, offset, size
        empty!(lat_points_px[])
        empty!(lat_text[])
        vis_spine!(spine, lat_text[], lat_points_px[], 1, size * 2, offset)
        notify(lat_text)
        notify(lat_points_px)
        return
    end

    onany(lon_spine, axis.ylabelpadding, axis.yticklabelsize) do spine, offset, size
        empty!(lon_points_px[])
        empty!(lon_text[])
        vis_spine!(spine, lon_text[], lon_points_px[], 2, size * 2, offset)
        notify(lon_text)
        notify(lon_points_px)
        return
    end

    # lonpoints = map(x-> map(x-> x.projected, x), lon_spine)
    # scatter!(axis.blockscene, lonpoints, markersize=5, color=:red)

    # latpoints = map(x -> map(x -> x.projected, x), lat_spine)
    # scatter!(axis.blockscene, latpoints, markersize=7, color=(:blue, 0.5))

    lattex = text!(axis.blockscene, lat_points_px;
        text=lat_text, space=:pixel, align=(:center, :center),
        font=axis.xticklabelfont, color=axis.xticklabelcolor,
        fontsize=axis.xticklabelsize, visible=axis.xticklabelsvisible,
    )

    lontex = text!(axis.blockscene, lon_points_px;
        text=lon_text, space=:pixel, align=(:center, :center),
        font=axis.yticklabelfont,
        color=axis.yticklabelcolor,
        fontsize=axis.yticklabelsize, visible=axis.yticklabelsvisible,)

    fonts = theme(axis.blockscene, :fonts)

    approx_x_protrusion = map(axis.blockscene, axis.yticklabelfont, axis.yticklabelsize, lat_text) do font, size, lat_text
        max_height = 0.0f0
        for str in lat_text
            bb = Makie.text_bb(str, to_font(fonts, font), size)
            max_height = max(max_height, widths(bb)[2])
        end
        return max_height
    end

    approx_y_protrusion = map(axis.blockscene, axis.yticklabelfont, axis.yticklabelsize, lon_text) do font, size, lon_text
        max_width = 0.0f0
        for str in lon_text
            bb = Makie.text_bb(str, to_font(fonts, font), size)
            max_width = max(max_width, widths(bb)[1])
        end
        return max_width
    end

    elements = Dict{Symbol,Any}()
    setfield!(axis, :elements, elements)
    elements[:xgrid] = longridplot
    elements[:ygrid] = latgridplot
    elements[:xticklabels] = lontex
    elements[:yticklabels] = lattex

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

    yaxis = (; protrusion=approx_x_protrusion)
    xaxis = (; protrusion=approx_y_protrusion)
    map!(compute_protrusions, axis.blockscene, axis.layoutobservables.protrusions, axis.title, axis.titlesize,
        axis.titlegap, axis.titlevisible,
        xaxis.protrusion, yaxis.protrusion,
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

    titleheight = Makie.text_boundingbox(titlet).widths[2] + titlegap
    subtitleheight = Makie.text_boundingbox(subtitlet).widths[2] + subtitlegap

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

function create_transform(dest::String, source::String)
    return Proj.Transformation(source, dest; always_xy=true)
end

function create_transform(dest::Observable, source::Observable)
    result = Observable{Any}()
    return map!(create_transform, result, dest, source)
end

# This is where we override the stuff to make it our stuff.
function Makie.plot!(axis::GeoAxis, plot::Makie.AbstractPlot)
    source = pop!(plot.kw, :source, axis.source)
    transformfunc = lift(create_transform, axis.dest, source)
    trans = Transformation(transformfunc; get(plot.kw, :transformation, Attributes())...)
    plot.kw[:transformation] = trans
    Makie.plot!(axis.scene, plot)
    # some area-like plots basically always look better if they cover the whole plot area.
    # adjust the limit margins in those cases automatically.
    Makie.needs_tight_limits(plot) && Makie.tightlimits!(axis)
    if Makie.is_open_or_any_parent(axis.scene)
        Makie.reset_limits!(axis)
    end
    return plot
end

# TODO implement
Makie.tightlimits!(axis::GeoAxis) = nothing

Makie.get_scene(ga::GeoAxis) = ga.scene
