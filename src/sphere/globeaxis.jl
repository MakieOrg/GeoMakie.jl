#=
# GlobeAxis

The idea behind the globe axis is to have a 3D axis that can show a globe or a sphere, centered at (0, 0, 0) in cartesian space.

We can have multiple parametrizations of the globe, from simple unit sphere to fancy ellipsoids or even irregular ellipsoid like things (if you want to plot GRACE data for example).

Per plot we want the following config:
- source CRS / datum
- default radius / z-value - this can plug into the transformation we give it, so that people can layer their plots

Per axis we want the following config:
- whether to show default:
    - earth map
    - smaller mesh sphere (maybe using icosphere)
    - coastlines
- whether to show grid lines
- whether to show (potentially) lat/long labels where the grid lines vanish?  That would be tricky but a great feature.
- camera controls (rotation speed etc)
- max/min zoom

For now, a simple implementation is to have a single globe.  We can always decide on more or less complexity later.
=#


Makie.@Block GlobeAxis <: Makie.AbstractAxis begin
    scene::Scene
    globe_limits::Observable{Rect3d}
    mouseeventhandle::Makie.MouseEventHandle
    scrollevents::Observable{Makie.ScrollEvent}
    keysevents::Observable{Makie.KeysEvent}
    # interactions::Dict{Symbol, Tuple{Bool, Any}}
    elements::Dict{Symbol, Any}
    final_ellipsoid::Observable{Geodesy.Ellipsoid}
    transform_func::Observable{Any}
    inv_transform_func::Observable{Any}
    @attributes begin
        # unused - only for compat with Makie AbstractAxis functions
        xscale = identity
        yscale = identity
        zscale = identity
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
        dest = "+proj=cart +datum=WGS84"


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

        # mesh background
        backgroundvisible::Bool = true
        "The color of the background mesh."
        backgroundcolor = @inherit(:backgroundcolor, :white)
        "The opacity of the background mesh."
        backgroundalpha::Float64 = 1.0
        "Whether the background mesh has transparency or not."
        backgroundtransparency::Bool = true
        "The ratio of the background mesh radius to the globe radius."
        backgroundradius::Float64 = 0.9

        # grid lines and ticks
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
    end
end

function Makie.initialize_block!(axis::GlobeAxis; scenekw = NamedTuple())

    # Set up transformations first, so that the scene can be set up
    # and linked to those.
    transform_obs = Observable{Any}(identity; ignore_equal_values=true)
    transform_inv_obs = Observable{Any}(identity; ignore_equal_values=true)
    transform_ticks_obs = Observable{Any}(identity; ignore_equal_values=true)
    transform_ticks_inv_obs = Observable{Any}(identity; ignore_equal_values=true)
    setfield!(axis, :transform_func, transform_obs)
    setfield!(axis, :inv_transform_func, transform_inv_obs)

    scene = axis_setup!(axis, transform_obs; scenekw)


end

function reset_limits!(axis::GlobeAxis)
    notify(axis.scene.theme.limits)
    center!(axis.scene)
    return
end
tightlimits!(::GlobeAxis) = nothing # TODO implement!?  By getting the bbox of the sphere / ellipsoid and using that to compute the camera eyeposition / lookat / fov

function axis_setup!(axis::GlobeAxis, transform_obs::Observable; scenekw = NamedTuple())

    topscene = axis.blockscene

    # pick a camera and draw axis.
    scenekw = merge((clear = false, camera=cam3d!), scenekw)
    axis.scene = Scene(blockscene, lift(round_to_IRect2D, blockscene, axis.layoutobservables.computedbbox); transformation = Makie.Transformation(topscene.transformation; transform_func = transform_obs), scenekw...)
    # Axis should not have a transform func, but all other plots should!
    _ax = axis.scene[OldAxis]
    isnothing(_ax) || (_ax.transformation = Makie.Transformation(axis.scene; transform_func = identity))

    on(blockscene, axis.show_axis) do show_axis
        ax = axis.scene[OldAxis]
        if show_axis
            if isnothing(ax)
                # Add axis on first plot!, if requested
                # update limits when scene limits change
                limits = lift(blockscene, axis.scene.theme.limits) do lims
                    if lims === automatic
                        dl = boundingbox(axis.scene, p -> Makie.isaxis(p) || Makie.not_in_data_space(p))
                        if any(isinf, widths(dl)) || any(isinf, Makie.origin(dl))
                            Rect3d((0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
                        else
                            dl
                        end
                    else
                        lims
                    end
                end
                Makie.axis3d!(axis.scene, limits)
                # Make sure axis is always in pos 1
                sort!(axis.scene.plots, by=!Makie.isaxis)
            else
                ax.visible = true
            end
        else
            if !isnothing(ax)
                ax.visible = false
            end
        end
    end
    notify(axis.show_axis)

    return axis.scene
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
    # However, for spheres, we want to keep user zoom level if possible.
    # Makie.needs_tight_limits(plot) && Makie.tightlimits!(axis)
    if Makie.is_open_or_any_parent(axis.scene)
        Makie.reset_limits!(axis)
    end
    return plot
end
function Makie.MakieCore._create_plot!(F, attributes::Dict, ax::GeoAxis, args...)
    source = pop!(attributes, :source, nothing)
    dest = pop!(attributes, :dest, nothing)
    plot = Plot{Makie.default_plot_func(F, args)}(args, attributes)
    isnothing(source) || (plot.kw[:source] = source)
    isnothing(dest) || (plot.kw[:dest] = dest)
    Makie.plot!(ax, plot)
    return plot
end

# Makie.interactions(ax::GlobeAxis) = ax.interactions

function Makie.update_state_before_display!(ax::GlobeAxis)
    Makie.reset_limits!(ax)
    return
end


# Legend API

function Makie.get_plots(ax::GlobeAxis)
    n_skip = isnothing(ax.scene[OldAxis]) ? 1 : 2
    return Makie.get_plots(ax.scene)[n_skip:end]
end

function Makie.Legend(fig_or_scene, axis::GlobeAxis, title = nothing; merge = false, unique = false, kwargs...)
    plots, labels = Makie.get_labeled_plots(axis, merge = merge, unique = unique)
    isempty(plots) && error("There are no plots with labels in the given axis that can be put in the legend. Supply labels to plotting functions like `plot(args...; label = \"My label\")`")
    Makie.Legend(fig_or_scene, plots, labels, title; kwargs...)
end


