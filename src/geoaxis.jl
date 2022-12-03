using Makie: left, right, top, bottom
using Makie: height, width

"""
    GeoAxis(fig_or_scene; kwargs...) → ax::Axis

Create a modified `Axis` of the Makie.jl ecosystem.
All Makie.jl plotting functions work directly on `GeoAxis`, e.g., `scatter!(ax, x, y)`.
You can pass any keyword which `Axis` accepts, and manipulate it just like a
regular `Axis`.

This is because it _is_ a regular `Axis`, using the interface you are already
familiar with, functions like `xlims!` and attributes like `ax.xticks`, etc. just work.

`GeoAxis` is appropriate for geospatial plotting because it automatically transforms
all plotted data, given a user-defined map projection. See keyword arguments below
and examples in the online documentation. Longitude and latitude values in GeoMakie.jl
are always assumed to be **in degrees**.

In order to automatically adjust the limits to your data, you can call `datalims!(ax)`
on any `GeoAxis`.

In the call signature, `fig_or_scene` can be a standard figure location, e.g.,
`fig[1,1]` as given in `Axis`. The keyword arguments decide the geospatial projection.

## Keyword arguments

* `source = "+proj=longlat +datum=WGS84", dest = "+proj=eqearth"`: These two keywords
  configure the map projection to be used for the given field using Proj.jl.
  See also online the section [Changing central longitude](@ref) for data that may not
  span the (expected by default) longitude range from -180 to 180.
* `transformation = Proj.Transformation(source, dest, always_xy=true)`: Instead of
  `source, dest`, you can directly use the Proj.jl package to define the projection.
* `lonlims = (-180, 180)`: The limits for longitude (x-axis).  For automatic
  determination, pass `lonlims=automatic`.
* `latlims = (-90, 90)`: The limits for latitude (y-axis).  For automatic
  determination, pass `latlims=automatic`.
* `coastlines = false`: Draw the coastlines of the world, from the Natural Earth dataset.
* `coastline_attributes = (;)`: Attributes that get passed to the `lines` call drawing the coastline.
* `line_density = 1000`: The number of points sampled per grid line.  Do not set
  this higher than 10,000 for performance and file size reasons..
* `remove_overlapping_ticks = true`: Remove ticks which could overlap each other.
  X-axis (longitude) ticks take priority over Y-axis (latitude) ticks.

## Example

```julia
using GeoMakie
fig = Figure()
ax = GeoAxis(fig[1,1]; coastlines = true)
image!(ax, -180..180, -90..90, rotr90(GeoMakie.earth()); interpolate = false)
el = scatter!(rand(-180:180, 5), rand(-90:90, 5); color = rand(RGBf, 5))
fig

```
"""
function GeoAxis(args...;
        source = "+proj=longlat +datum=WGS84", dest = "+proj=eqearth",
        transformation = Proj.Transformation(Makie.to_value(source), Makie.to_value(dest), always_xy=true),
        lonlims = (-180, 180),
        latlims = (-90, 90),
        coastlines = false,
        coastline_attributes = (;label = "Coastlines",),
        line_density = 1_000,
        remove_overlapping_ticks = true,
        # these are the axis keywords which we will merge in
        xtickformat = _replace_if_automatic(Axis, :xtickformat, longitude_format),
        ytickformat = _replace_if_automatic(Axis, :ytickformat, latitude_format),
        xticks = LinearTicks(7),
        yticks = LinearTicks(7),
        xticklabelpad = 5.0,
        yticklabelpad = 5.0,
        # xticklabelalign = (:center, :center),
        # yticklabelalign = (:center, :center),
        alignmode = Outside(),
        kw...
    )

    _transformation = Observable{Proj.Transformation}(Makie.to_value(transformation))
     Makie.Observables.onany(source, dest) do src, dst
        _transformation[] = Proj.Transformation(Makie.to_value(src), Makie.to_value(dst); always_xy = true)
    end
    Makie.Observables.onany(transformation) do trans
        _transformation[] = trans
    end

    # Automatically determine limits!
    # TODO: should we automatically verify limits
    # or not?

    if lonlims == Makie.automatic || latlims == Makie.automatic
        axmin, axmax, aymin, aymax = find_transform_limits(_transformation[])
    end

    verified_lonlims = lonlims
    if lonlims == Makie.automatic
        verified_lonlims = axmin < axmax ? (axmin, axmax) : (axmax, axmin)
    end
    verified_latlims = latlims
    if latlims == Makie.automatic
        verified_latlims = aymin < aymax ? (aymin, aymax) : (aymax, aymin)
    end
    # Apply defaults
    # Generate Axis instance
    ax = Axis(args...;
        aspect = DataAspect(),
        xtickformat = xtickformat,
        ytickformat = ytickformat,
        xticks = xticks,
        yticks = yticks,
        limits = (verified_lonlims, verified_latlims),
        xticklabelpad = xticklabelpad,
        yticklabelpad = yticklabelpad,
        # xticklabelalign = xticklabelalign, # these do not work with Axis because it wants a float
        # yticklabelalign = yticklabelalign, # these do not work with Axis because it wants a float
        alignmode = alignmode,
        kw...)


    # Set axis transformation
    Makie.Observables.connect!(ax.scene.transformation.transform_func, _transformation)

    # Plot coastlines
    coast_line = GeoMakie.coastlines()
    coastplot = lines!(ax, coast_line; color = :black, coastline_attributes...)
    translate!(coastplot, 0, 0, 99) # ensure they are on top of other plotted elements
    xprot = ax.xaxis.protrusion[]
    yprot = ax.yaxis.protrusion[]
    if !coastlines
        delete!(ax, coastplot)
    end

    # Set the axis's native grid to always be invisible, and
    # forward those updates to our observables.
    # First we need to hijack the axis's protrusions and store them

    hijacked_observables = Dict{Symbol, Observable}()
    ## This macro is defined in `utils.jl`
    @hijack_observable :xgridvisible
    @hijack_observable :ygridvisible
    @hijack_observable :xminorgridvisible
    @hijack_observable :yminorgridvisible
    @hijack_observable :xticksvisible
    @hijack_observable :yticksvisible
    # @hijack_observable :xticklabelsvisible
    # @hijack_observable :yticklabelsvisible
    @hijack_observable :topspinevisible
    @hijack_observable :bottomspinevisible
    @hijack_observable :leftspinevisible
    @hijack_observable :rightspinevisible


    # WARNING: for now, we only accept xticks on the bottom
    # and yticks on the left.

    draw_geoticks!(ax, hijacked_observables, line_density, remove_overlapping_ticks)

    ax.xaxis.protrusion[] = xprot
    ax.yaxis.protrusion[] = yprot

    return ax
end

function draw_geoticks!(ax::Axis, hijacked_observables, line_density, remove_overlapping_ticks)
    topscene = ax.blockscene
    scene = ax.scene

    decorations = Dict{Symbol, Any}()

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

    # Extract x and y ticklabel plots from the axis, to avoid duplication

    decorations[:xticklabel] = ax_xticklabel_plot = ax.blockscene.plots[10]
    decorations[:yticklabel] = ax_yticklabel_plot = ax.blockscene.plots[15]

    # First we establish the spine points

    lift(ax.finallimits, ax.xticks, ax.xtickformat, ax.yticks, ax.ytickformat, ax.xminorticks, ax.yminorticks, ax.scene.px_area, getproperty(ax.scene, :transformation).transform_func, ax.spinewidth, ax.xgridwidth, ax.ygridwidth) do limits, xticks, xtickformat, yticks, ytickformat, xminor, yminor, pxarea, _tfunc, spinewidth, xgridwidth, ygridwidth

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
        xtickpoints.val = project_to_pixelspace(scene, _xtickpos_in_inputspace) .+
                            Ref(Point2f(pxarea.origin))

        ytickpoints.val = project_to_pixelspace(scene, _ytickpos_in_inputspace) .+
                            Ref(Point2f(pxarea.origin))


        if are_ticks_colocated(scene, xtickpoints.val, _xticklabels, ax.xticklabelsize[])
            ax.xticklabelsvisible[] = false
        else
            xtickpoints.val = xtickpoints.val .+ directional_pad.(
                Ref(scene), Ref(limits), _xtickpos_in_inputspace,
                _xticklabels, Ref(Point2f(ax.xticklabelpad[], 0)), ax.xticklabelsize[], ax.xticklabelfont[],
                ax.xticklabelrotation[]
            )
        end


        if are_ticks_colocated(scene, ytickpoints.val, _yticklabels, ax.yticklabelsize[])
            ax.yticklabelsvisible[] = false
        else
            ytickpoints.val = ytickpoints.val .+ directional_pad.(
                Ref(scene), Ref(limits), _ytickpos_in_inputspace,
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

        xrange = LinRange(xlimits[]..., line_density)
        yrange = LinRange(ylimits[]..., line_density)

        # first update the spine
        topspinepoints[] = Point2f.(xrange, ylimits[][2])
        btmspinepoints[] = Point2f.(xrange, ylimits[][1])
        lftspinepoints[] = Point2f.(xlimits[][1], yrange)
        rgtspinepoints[] = Point2f.(xlimits[][2], yrange)

        clippoints[] = vcat(
            btmspinepoints[],
            rgtspinepoints[],
            reverse(topspinepoints[]),
            reverse(lftspinepoints[])
        )

        # now, the grid.  Each visible "gridline" is separated from the next
        # by a `Point2f(NaN)`.  The approach here allows us to avoid appending.
        # x first
        _xgridpoints = fill(Point2f(NaN), (line_density+1) * length(_xtickvalues))

        current_ind = 1
        for x in _xtickvalues
            _xgridpoints[current_ind:(current_ind+line_density-1)] = Point2f.(x, yrange)
            current_ind += line_density + 1
        end
        # now y
        _ygridpoints = fill(Point2f(NaN), (line_density+1) * length(_ytickvalues))

        current_ind = 1
        for y in _ytickvalues
            _ygridpoints[current_ind:(current_ind+line_density-1)] = Point2f.(xrange, y)
            current_ind += line_density + 1
        end

        xgridpoints[] = _xgridpoints
        ygridpoints[] = _ygridpoints

        # Do the same for minor ticks
        _xminorgridpoints = fill(Point2f(NaN), (line_density+1) * length(_xminortickvalues))

        current_ind = 1
        for x in _xminortickvalues
            _xminorgridpoints[current_ind:(current_ind+line_density-1)] = Point2f.(x, yrange)
            current_ind += line_density + 1
        end
        # now y
        _yminorgridpoints = fill(Point2f(NaN), (line_density+1) * length(_yminortickvalues))

        current_ind = 1
        for y in _yminortickvalues
            _yminorgridpoints[current_ind:(current_ind+line_density-1)] = Point2f.(xrange, y)
            current_ind += line_density + 1
        end

        xminorgridpoints[] = _xminorgridpoints
        yminorgridpoints[] = _yminorgridpoints

        ax_xticklabel_plot.align = (:center, :center)
        ax_yticklabel_plot.align = (:center, :center)

        return 1
        # Now, we've updated the entire axis.
    end

    Makie.Observables.notify(ax.xticks)

    # Time to plot!


    # First, we clip our scene:
    # decorations[:clip] = clip!(scene, clippoints)
    # translate!(decorations[:clip], 0, 0, -9999)
    # This makes the clip plot the first in the list of plots
    # insert!(scene.plots, 1, pop!(scene.plots))

    # Now we plot the spines:
    decorations[:topspineplot] = lines!(
        scene, topspinepoints;
        visible = hijacked_observables[:topspinevisible],
        color = ax.topspinecolor,
        # linestyle = ax.spinestyle,
        linewidth = ax.spinewidth,
        )
    decorations[:btmspineplot] = lines!(
        scene, btmspinepoints;
        visible = hijacked_observables[:bottomspinevisible],
        color = ax.bottomspinecolor,
        # linestyle = ax.spinestyle,
        linewidth = ax.spinewidth,
        )
    decorations[:lftspineplot] = lines!(
        scene, lftspinepoints;
        visible = hijacked_observables[:leftspinevisible],
        color = ax.leftspinecolor,
        # linestyle = ax.spinestyle,
        linewidth = ax.spinewidth,
        )
    decorations[:rgtspineplot] = lines!(
        scene, rgtspinepoints;
        visible = hijacked_observables[:rightspinevisible],
        color = ax.rightspinecolor,
        # linestyle = ax.spinestyle,
        linewidth = ax.spinewidth,
        )


    # Now for the grids:

    decorations[:xgridplot] = lines!(
        scene, xgridpoints;
        visible = hijacked_observables[:xgridvisible],
        color = ax.xgridcolor,
        linestyle = ax.xgridstyle,
        width = ax.xgridwidth,
        transparency=true,
    )
    decorations[:ygridplot] = lines!(
        scene, ygridpoints;
        visible = hijacked_observables[:ygridvisible],
        color = ax.ygridcolor,
        linestyle = ax.ygridstyle,
        width = ax.ygridwidth,
        transparency=true,
    )

    decorations[:xminorgridplot] = lines!(
        scene, xminorgridpoints;
        visible = hijacked_observables[:xminorgridvisible],
        color = ax.xminorgridcolor,
        linestyle = ax.xminorgridstyle,
        width = ax.xminorgridwidth,
        transparency=true,
    )

    decorations[:yminorgridplot] = lines!(
        scene, yminorgridpoints;
        visible = hijacked_observables[:yminorgridvisible],
        color = ax.yminorgridcolor,
        linestyle = ax.yminorgridstyle,
        width = ax.yminorgridwidth,
        transparency=true,
    )


    # And finally, the TikZ!

    textscene = ax.blockscene

    # decorations[:xtickplot] = text!(
    #     textscene,
    #     xticklabels;
    #     markerspace = :pixel,
    #     visible = hijacked_observables[:xticklabelsvisible],
    #     position = xtickpoints,
    #     rotation = ax.xticklabelrotation,
    #     font = ax.xticklabelfont,
    #     fontsize = ax.xticklabelsize,
    #     color = ax.xticklabelcolor,
    #     align = (:center, :center),
    # )
    #
    # decorations[:ytickplot] = text!(
    #     textscene,
    #     yticklabels;
    #     markerspace = :pixel,
    #     visible = hijacked_observables[:yticklabelsvisible],
    #     position = ytickpoints,
    #     rotation = ax.yticklabelrotation,
    #     font = ax.yticklabelfont,
    #     fontsize = ax.yticklabelsize,
    #     color = ax.yticklabelcolor,
    #     align = (:center, :center),
    # )


    # Currently, I hijack the axis text for this.  However, I don't know what it would do
    # to interaction times, hence why I have left the old code commented out above.
    Makie.Observables.connect!(ax_xticklabel_plot[1], Makie.@lift tuple.($xticklabels, $xtickpoints))
    Makie.Observables.connect!(ax_yticklabel_plot[1], Makie.@lift tuple.($yticklabels, $ytickpoints))

    # For diagnostics only!
    # scatter!(textscene, xtickpoints; visible = hijacked_observables[:xticklabelsvisible], color = :red, bordercolor=:black)
    # scatter!(textscene, ytickpoints; visible = hijacked_observables[:yticklabelsvisible], color = :red, bordercolor=:black)

    # Finally, we translate these plots such that they are above the content.
    translate!.(values(decorations), 0, 0, 100)

    # Set common attributes for all plots
    setproperty!.(values(decorations), Ref(:inspectable), Ref(false))
    setproperty!.(values(decorations), Ref(:xautolimits), Ref(false))
    setproperty!.(values(decorations), Ref(:yautolimits), Ref(false))

    return decorations
end



function _datalims_exclude(plot)
    !(to_value(get(plot, :xautolimits, true)) || to_value(get(plot, :yautolimits, true))) ||
    !Makie.is_data_space(to_value(get(plot, :space, :data))) ||
    !to_value(get(plot, :visible, true))
end
# Applicable only to geoaxis
# in the future, once PolarAxis is implemented as an example,
# change this to `Makie.data_limits(ax::GeoAxis)`
function datalims(ax::Axis)
    nplots = length(plots(ax.scene))

    n_axisplots = if nplots ≥ 8 &&
                    ax.scene.plots[2] isa Makie.Lines &&
                    haskey(ax.scene.plots[2], :label) &&
                    ax.scene.plots[2].label[] == "Coastlines"
                8
        else
                7
        end

    return Makie.data_limits(ax.scene.plots[(n_axisplots+1):end], _datalims_exclude)

end

function datalims!(ax::Axis)
    lims = datalims(ax)
    min = lims.origin[1:2]
    max = lims.widths[1:2] .+ lims.origin[1:2]
    xlims!(ax, min[1], max[1])
    ylims!(ax, min[2], max[2])
    return (min[1], max[1], min[2], max[2])
end
