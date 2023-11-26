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
        xticks = -180:30:180
        "The y (latitude) ticks - can be a vector or a Makie tick finding algorithm."
        yticks = -90:30:90
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
        xgridcolor::RGBAf = @inherit(:linecolor, RGBAf(0, 0, 0, 0.12))
        "The color of the y grid lines."
        ygridcolor::RGBAf = @inherit(:linecolor, RGBAf(0, 0, 0, 0.12))
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


    end
end

const SpinePoint = NamedTuple{(:input, :projected, :dir),Tuple{Point2f,Point2f,Point2f}}

struct Spines
    top::Vector{SpinePoint}
    bottom::Vector{SpinePoint}
    left::Vector{SpinePoint}
    right::Vector{SpinePoint}
end

Spines() = Spines(SpinePoint[], SpinePoint[], SpinePoint[], SpinePoint[])

function interset_rect!(intersections, rect::Rect2, line_start::Point2, line_end::Point2)
    mini, maxi = extrema(rect)
    line = Line(line_start, line_end)
    side1 = Line(Point2{Float64}(mini[1], mini[2]), Point2{Float64}(maxi[1], mini[2]))
    intersected, p = intersects(side1, line)
    intersected && push!(intersections, p)
    side2 = Line(Point2{Float64}(maxi[1], mini[2]), Point2{Float64}(maxi[1], maxi[2]))
    intersected, p = intersects(side2, line)
    intersected && push!(intersections, p)
    side3 = Line(Point2{Float64}(maxi[1], maxi[2]), Point2{Float64}(mini[1], maxi[2]))
    intersected, p = intersects(side3, line)
    intersected && push!(intersections, p)
    side4 = Line(Point2{Float64}(mini[1], maxi[2]), Point2{Float64}(mini[1], mini[2]))
    intersected, p = intersects(side4, line)
    intersected && push!(intersections, p)
    return intersections
end


function intersect_transformed(trans, rect, point_start, point_stop, n=100)
    xrange = LinRange(point_start[1], point_stop[1], n)
    yrange = LinRange(point_start[2], point_stop[2], n)
    intersections = Point2f[]
    for i in 1:n-1
        pointa = Point2f(xrange[i], yrange[i])
        pointb = Point2f(xrange[i+1], yrange[i+1])
        pointa_t = Makie.apply_transform(trans, pointa)
        pointb_t = Makie.apply_transform(trans, pointb)
        interset_rect!(intersections, rect, pointa_t, pointb_t)
    end
    return intersections
end


function find_first_valid(create_point, range)
    for (i, r) in enumerate(range)
        point = create_point(r)
        if all(isfinite, point)
            return point, i
        end
    end
    return nothing, 0
end

function closest(target, points)
    sort!(points, by=p-> norm(p .- target))
    return first(points)
end

function project_tick_points!(result, trans, trans_inverse, range, coordinate, dim, limit_rect, spine_start, spine_end)
    point_fun(tick) = dim === 1 ? Point2(coordinate, tick) : Point2(tick, coordinate)

    valid_start_t, istart = find_first_valid(range) do lat
        return Makie.apply_transform(trans, point_fun(lat))
    end
    rev_range = reverse(range)

    valid_stop_t, istop = find_first_valid(rev_range) do lat
        return Makie.apply_transform(trans, point_fun(lat))
    end

    if valid_start_t == valid_stop_t # either both nothing, or nothing inbetween
        return
    end

    valid_start = point_fun(range[istart])
    valid_stop = point_fun(rev_range[istop])

    intersections = intersect_transformed(trans, limit_rect, valid_start, valid_stop)

    if length(intersections) == 1
        point = closest(intersections[1], [valid_start_t, valid_stop_t])
        if point == valid_start_t
            valid_start_t = intersections[1]
        else
            valid_stop_t = intersections[1]
        end
    elseif length(intersections) == 2
        valid_start_t = closest(valid_start_t, intersections)
        valid_start = Makie.apply_transform(trans_inverse, valid_start_t)
        valid_stop_t = closest(valid_stop_t, intersections)
        valid_stop = Makie.apply_transform(trans_inverse, valid_stop_t)
    end

    xrange = LinRange(valid_start[1], valid_stop[1], 100)
    yrange = LinRange(valid_start[2], valid_stop[2], 100)

    transformed = Makie.apply_transform.((trans,), Point2f.(xrange, yrange))
    append!(result, transformed)
    push!(result, Point2f(NaN))
    # Grow limit rect by 1% to make sure we don't miss the start and end points
    minp, maxp = extrema(limit_rect)
    minp = minp .- (widths(limit_rect) .* 0.01)
    maxp = maxp .+ (widths(limit_rect) .* 0.01)
    bigger_rect = Rect(minp, maxp .- minp)
    if valid_start_t in bigger_rect
        dir = normalize(transformed[1] .- transformed[2])
        if !isempty(spine_start)
            lp = last(spine_start).projected
            dp = lp .- valid_start_t
            sign = dim == 1 ? -1 : 1
            dir2 = sign * normalize(Point2f(dp[2], -dp[1]))
            dir = (dir .+ dir2) ./ 2f0
        end
        push!(spine_start, (input=valid_start, projected=valid_start_t, dir=dir))
    end
    if valid_stop_t in bigger_rect
        dir = normalize(transformed[end] .- transformed[end-1])
        if !isempty(spine_end)
            lp = last(spine_end).projected
            dp = lp .- valid_stop_t
            sign = dim == 1 ? -1 : 1
            dir2 = sign * normalize(Point2f(-dp[2], dp[1]))
            dir = (dir .+ dir2) ./ 2f0
        end
        push!(spine_end, (input=valid_stop, projected=valid_stop_t, dir=dir))
    end
    return
end

function mean_distances(points)
    dists = Float32[]
    last_px = points[1].projected
    for px in @view points[2:end]
        push!(dists, norm(last_px .- px.projected))
        last_px = px.projected
    end
    return mean(dists)
end

function choose_side(a, b)
    isempty(a) && return b
    isempty(b) && return a
    distsa = mean_distances(a)
    distsb = mean_distances(b)
    distsa - distsb < 3 && return a
    return distsb <= distsa ? a : b
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
        last_point = p_px
        # TODO use xticklabelspace
        # TODO use xticklabelpad
        p_offset = p_px .+ (p.dir .* labeloffset)
        push!(points_px, p_offset)
        push!(text, string(round(Int, p.input[d]), "°"))
    end
end

function Makie.initialize_block!(axis::GeoAxis)
    scene = axis_setup!(axis)
    grid_scene = scene
    Obs(x) = Observable(x; ignore_equal_values=true)

    transform_obs = Observable{Any}(nothing; ignore_equal_values = true)

    onany(scene, axis.dest, axis.source; update=true) do tp, sp
        transform_obs[] = create_transform(tp, sp)
    end

    setfield!(axis, :transform_func, transform_obs)

    lonticks_line_obs = Obs(Point2f[])
    latticks_line_obs = Obs(Point2f[])

    spines_obs = Obs(Spines())
    finallimits = Makie.Observables.throttle(0.1, axis.finallimits)
    onany(scene, axis.xticks, axis.yticks, transform_obs, finallimits;
          update=true) do lonticks, latticks, trans, fl

        lon_transformed = Point2f[]
        lat_transformed = Point2f[]
        limit_rect = axis.finallimits[]
        trans_inverse = Makie.inverse_transform(trans)
                spines = spines_obs[]
        foreach(empty!, [spines.left, spines.right, spines.bottom, spines.top])
        for lon in lonticks
            range = LinRange(latticks[1], latticks[end], 100)
            project_tick_points!(lon_transformed, trans, trans_inverse, range, lon, 1, limit_rect, spines.bottom, spines.top)
        end

        for lat in latticks
            range = LinRange(lonticks[1], lonticks[end], 100)
            project_tick_points!(lat_transformed, trans, trans_inverse, range, lat, 2, limit_rect,
                                 spines.left, spines.right)
        end
        lonticks_line_obs[] = lon_transformed
        latticks_line_obs[] = lat_transformed
        notify(spines_obs)
        return
    end

    longridplot = lines!(grid_scene, lonticks_line_obs; color=axis.xgridcolor, linewidth=axis.xgridwidth,
                         visible=axis.xgridvisible, linestyle=axis.xgridstyle, transparency=true)
    translate!(longridplot, 0, 0, 100)
    latgridplot = lines!(grid_scene, latticks_line_obs; color=axis.ygridcolor, linewidth=axis.ygridwidth,
                         visible=axis.ygridvisible, linestyle=axis.ygridstyle, transparency=true)
    translate!(latgridplot, 0, 0, 100)

    # TODO implement spines
    # spine_left = Observable(Point2f[])
    # spine_right = Observable(Point2f[])
    # spine_top = Observable(Point2f[])
    # spine_bottom = Observable(Point2f[])

    # onany(grid_scene, spines_obs, transform_obs, finallimits; update=true) do spines, trans, _
    #     rect = axis.finallimits[]
    #     function project_spine(points)
    #         res = Point2f[]
    #         length(points) < 2 && return res
    #         pstart = points[1].input
    #         for p in points[2:end]
    #             x = LinRange(pstart[1], p.input[1], 20)
    #             y = LinRange(pstart[2], p.input[2], 20)
    #             for px in zip(x, y)
    #                 point = Makie.apply_transform.((trans,), Point2f.(x, y))
    #                 rect
    #             append!(res, )
    #             pstart = p.input
    #         end
    #         return res
    #     end
    #     spine_left[] = project_spine(spines.left)
    #     spine_right[] = project_spine(spines.right)
    #     spine_top[] = project_spine(spines.top)
    #     spine_bottom[] = project_spine(spines.bottom)
    #     return
    # end
    # lines!(grid_scene, spine_left; color=:red, transparency=true)
    # lines!(grid_scene, spine_right; color=:black, transparency=true)
    # lines!(grid_scene, spine_top; color=:green, transparency=true)
    # lines!(grid_scene, spine_bottom; color=:blue, transparency=true)

    cam = grid_scene.camera
    lon_spine = Obs(SpinePoint[])
    lon_text = Obs([""])
    lon_points_px = Obs(Point2f[])

    lat_spine = Obs(SpinePoint[])
    lat_text = Observable([""])
    lat_points_px = Obs(Point2f[])


    onany(grid_scene, spines_obs, cam.projectionview, grid_scene.viewport) do spines, pv, area
        poffset = minimum(area)
        project_px(p) = to_ndim(Point2f, Makie.project(cam, :data, :pixel, p), 0.0f0) .+ poffset
        project_p(p) = (input=p.input, projected=project_px(p.projected), dir=p.dir)

        left = project_p.(spines.left)
        right = project_p.(spines.right)
        bottom = project_p.(spines.bottom)
        top = project_p.(spines.top)

        lon_spine[] = choose_side(bottom, top)
        lat_spine[] = choose_side(left, right)
        return
    end

    onany(lat_spine, axis.xlabelpadding, axis.xticklabelsize) do spine, offset, size
        empty!(lon_points_px[])
        empty!(lon_text[])
        vis_spine!(spine, lon_text[], lon_points_px[], 2, size * 3, offset)
        notify(lon_text)
        return
    end

    onany(lon_spine, axis.ylabelpadding, axis.yticklabelsize) do spine, offset, size
        empty!(lat_points_px[])
        empty!(lat_text[])
        vis_spine!(spine, lat_text[], lat_points_px[], 1, size * 3, offset)
        notify(lat_text)
        return
    end


    lontex = text!(axis.blockscene, lon_points_px;
        text=lon_text, space=:pixel, align=(:right, :center),

        font=axis.xticklabelfont, color=axis.xticklabelcolor,
        fontsize=axis.xticklabelsize, visible=axis.xticklabelsvisible,

    )
    lattex = text!(axis.blockscene, lat_points_px;
        text=lat_text, space=:pixel, align=(:center, :top),
        font=axis.yticklabelfont,
        color=axis.yticklabelcolor,
        fontsize=axis.yticklabelsize, visible=axis.yticklabelsvisible,)

    elements = Dict{Symbol,Any}()
    setfield!(axis, :elements, elements)
    elements[:xgrid] = longridplot
    elements[:ygrid] = latgridplot
    elements[:xticklabels] = lontex
    elements[:yticklabels] = lattex
    return axis
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
    return Polygon(
        geomakie_transform(trans, GeometryBasics.coordinates(polygon.exterior)),
        geomakie_transform.((trans,), GeometryBasics.coordinates.(polygon.interiors)),
    )
end

function geomakie_transform(trans, polygon::MultiPolygon)
    return MultiPolygon(geomakie_transform.((trans,), polygon.polygons))
end

function geomakie_transform(trans::Observable, obs...)
    return map((args...) -> geomakie_transform(args...), trans, obs...)
end
