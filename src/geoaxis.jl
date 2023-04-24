const Rect2d = Rect2{Float64}

Makie.@Block GeoAxis begin
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
        "The xlabel string."
        source_projection = "+proj=longlat +datum=WGS84"
        target_projection = "+proj=eqearth"

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
        "Controls if the axis spine is visible."
        spinevisible::Bool = true
        "The color of the axis spine."
        spinecolor::RGBAf = :black
        spinetype::Symbol = :geospine
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

Makie.can_be_current_axis(::GeoAxis) = true


function Makie.initialize_block!(axis::GeoAxis)
    scene = #=plot_scene, grid_scene = =# axis_setup!(axis)
    grid_scene = scene
    # grid_scene = Scene(scene)

    transform_obs = Observable{Any}()
    lift(axis.target_projection, axis.source_projection) do tp, sp
        transform_obs[] = create_transform(tp, sp)
    end

    setfield!(axis, :transform_func, transform_obs)

    lonticks_line_obs = Observable{Vector{Point2f}}(Point2f[])
    latticks_line_obs = Observable{Vector{Point2f}}(Point2f[])
    lift(axis.xticks, axis.yticks) do lonticks, latticks
        final_lon_vec = Point2f[]
        for lon in lonticks
            coords = Makie.to_ndim.(Point2f, Makie.apply_transform(transform_obs[], [Point2f(lon, l) for l in range(latticks[begin], latticks[end]; length=100)]), 0f0)
            # append transformed coords to a nan vec
            append!(final_lon_vec, coords)
            push!(final_lon_vec, Point2f(NaN))
        end
        lonticks_line_obs[] = final_lon_vec

        final_lat_vec = Point2f[]
        for lat in latticks
            coords = Makie.to_ndim.(Point2f, Makie.apply_transform(transform_obs[], [Point2f(l, lat) for l in range(lonticks[begin], lonticks[end]; length=100)]), 0f0)
            # append transformed coords to a nan vec
            append!(final_lat_vec, coords)
            push!(final_lat_vec, Point2f(NaN))
        end
        latticks_line_obs[] = final_lat_vec
    end

    longridplot = lines!(grid_scene, lonticks_line_obs; color = :gray20, linewidth = 0.5)
    translate!(longridplot, 0, 0, 100)
    latgridplot = lines!(grid_scene, latticks_line_obs; color = :gray20, linewidth = 0.5)
    translate!(latgridplot, 0, 0, 100)

    # now, find the spine!
    spine_line_obs = get_geospine(axis.transform_func, axis.scene.px_area, axis.finallimits, axis.spinetype, axis)
    spine_plot = lines!(grid_scene, spine_line_obs; color = axis.spinecolor, linewidth = axis.spinewidth, visible = axis.spinevisible)
    translate!(spine_plot, 0, 0, 100)

    setfield!(axis, :elements, Dict{Symbol,Any}())
    # getfield(axis, :elements)[:xgrid] = longridplot
    # getfield(axis, :elements)[:ygrid] = latgridplot
    return axis
end

function get_geospine(transform_func, pxarea, finallimits, spinetype::Observable{Symbol}, ga::GeoAxis,)

    # TODO: kludge
    if spinetype[] == :frame
        return lift(geospine_frame, transform_func, finallimits, ga)
    elseif spinetype[] == :geospine
        return lift(geospine_geo, transform_func, pxarea, finallimits, ga)
    else
        error()
    end
end

function geospine_frame(transform_func, finallimits, ga)
    xmin, ymin = minimum(finallimits)
    xmax, ymax = maximum(finallimits)
    return Point2f[(xmin, ymin), (xmax, ymin), (xmax, ymax), (xmin, ymax), (xmin, ymin)]
end

function geospine_geo(transform_func, pxarea, finallimits, ga)
    xs, ys, finite_mask = get_finite_mask_of_projection(ga.scene, transform_func, pxarea, finallimits; padding = 10, density = 2)
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

    spineline = Point2f[]

    # there are only two possible values in the finite mask.
    # so, we can compute the correct spine contour.
    spine_contour = Makie.Contours.contours(xs, ys, Float32.(finite_mask), [0.5f0])
    # since we know there's only one level, instead of iterating through all levels,
    # we can skip that and iterate only through the first.
    for element in Makie.Contours.lines(first(Makie.Contours.levels(spine_contour)))
        append!(
            spineline, 
            Point2f.(element.vertices)
        )
        push!(spineline, Point2f(NaN))
    end
    return spineline
end

function get_geo_ticks(ga::GeoAxis)
end

function create_transform(dest::String, source::String)
    return Proj.Transformation(source, dest; always_xy=true)
end

function create_transform(dest::Observable, source::Observable)
    result = Observable{Any}()
    return map!(create_transform, result, dest, source)
end

# This is where we override the stuff to make it our stuff.

function Makie.plot!(
    axis::GeoAxis, P::Makie.PlotFunc,
    attributes::Makie.Attributes, args...; kw_attributes...)
    allattrs = merge(attributes, Attributes(kw_attributes))
    # get the source projection and pass it backend
    source = pop!(allattrs, :source_projection, axis.source_projection)
    transformfunc = create_transform(axis.target_projection, source)
    # TODO: get this to automatically figure the projection out based on
    # GeoInterface.crs or similar.
    # ALSO TODO: get Rasters.jl hooked up to GeoInterface.crs.

    # Now, we construct a transformation, knowing the previous kwargs and the new transform.
    trans = Transformation(transformfunc; get(allattrs, :transformation, Attributes())...)
    allattrs[:transformation] = trans
    # Plot using the altered keyword arguments
    plt = Makie.plot!(axis.scene, P, allattrs, args...)
    
    if Makie.is_open_or_any_parent(axis.scene)
        reset_limits!(axis)
    end
    return plt
end

function Makie.plot!(P::Type{<:Poly}, axis::GeoAxis, args...; kw_attributes...)
    attributes = Makie.Attributes(kw_attributes)
    source = pop!(attributes, :source, axis.source_projection)
    transformfunc = create_transform(axis.target_projection, source)
    arg = geomakie_transform(transformfunc, convert.(Observable, args)...)
    plt = Makie.plot!(axis.scene, P, attributes, arg)
    if Makie.is_open_or_any_parent(axis.scene)
        reset_limits!(axis)
    end
    return plt
end

function Makie.plot!(P::Makie.PlotFunc, axis::GeoAxis, args...; kw_attributes...)
    attributes = Makie.Attributes(kw_attributes)
    Makie.plot!(axis, P, attributes, args...)
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
