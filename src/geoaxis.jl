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

        "The x axis scale"
        xscale = identity
        "The y axis scale"
        yscale = identity
    end
end

include("makie-axis.jl")

function Makie.initialize_block!(axis::GeoAxis)
    scene = axis_setup!(axis)
    lonticks = -180:60:180
    latticks = -90:30:90
    ptrans = create_transform(axis.target_projection, axis.source_projection)
    for lon in lonticks
        coords = Makie.apply_transform(ptrans[], [Point2f(lon, l) for l in range(latticks[1], latticks[end]; length=100)])
        gridplot = lines!(axis, coords; color=:gray20, linewidth=0.5)
        translate!(gridplot, 0, 0, 100) # ensure they are on top of other plotted elements
    end

    for lat in latticks
        coords = Makie.apply_transform(ptrans[], [Point2f(l, lat) for l in range(lonticks[1], lonticks[end]; length=100)])
        gridplot = lines!(axis, coords; color=:gray20, linewidth=0.5)
        translate!(gridplot, 0, 0, 100) # ensure they are on top of other plotted elements
    end
    setfield!(axis, :elements, Dict{Symbol,Any}())
    return axis
end

function create_transform(dest::String, source::String)
    return Proj.Transformation(source, dest; always_xy=true)
end

function create_transform(dest::Observable, source::Observable)
    result = Observable{Any}()
    return map!(create_transform, result, dest, source)
end

function Makie.plot!(
    axis::GeoAxis, P::Makie.PlotFunc,
    attributes::Makie.Attributes, args...; kw_attributes...)
    allattrs = merge(attributes, Attributes(kw_attributes))
    source = pop!(allattrs, :source, axis.source_projection)
    transformfunc = create_transform(axis.target_projection, source)
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
    transformfunc = create_transform(axis.target_projection, source)
    arg = geomakie_transform(transformfunc, args...)
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

function geomakie_transform(trans, polygons::AbstractVector{<:Polygon})
    return map(poly-> geomakie_transform(trans, poly), polygons)
end

function geomakie_transform(trans, polygon::Polygon)
    return Polygon(
        geomakie_transform(trans, GeometryBasics.coordinates(polygon.exterior)),
        geomakie_transform.((trans,), GeometryBasics.coordinates.(polygon.interiors)),
    )
    return map(poly -> Makie.apply_transform(trans, poly), polygons)
end

geomakie_transform(t::Observable, p::AbstractVector{<:Polygon}) = lift(geomakie_transform, t, p)

function geomakie_transform(trans::Observable, obs...)
    return map((args...)-> Makie.apply_transform(args...), trans, obs...)
end
