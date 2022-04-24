using Makie: left, right, top, bottom
using Makie.MakieLayout: height, width

"""
    GeoAxis(args...; kwargs...) → ax
Create a new axis instance `ax` that is a modified `Axis` of the Makie.jl ecosystem.
All Makie.jl plotting functions work directly on `GeoAxis`, e.g., `scatter!(ax, x, y)`.

`GeoAxis` is appropriate for geospatial plotting because it automatically transforms all
plotted data given a user-defined map projection. See keyword arguments below and examples
in the online documentation. Longitude and latitude values in GeoMakie.jl are always
assumed to be **in degrees**.

In the call signature, `args...` is a standard figure location, e.g., `fig[1,1]` as given in
`Axis`. The keyword arguments decide the geospatial projection:

* `source = "+proj=longlat +datum=WGS84", dest = "+proj=eqearth"`: These two keywords
  configure the map projection to be used for the given field using Proj.jl.
  See also online the section [Changing central longitude](@ref) for data that may not
  span the (expected by default) longitude range from -180 to 180.
* `transformation = Proj.Transformation(source, dest, always_xy=true)`: Instead of
  `source, dest` you can directly use the Proj.jl package to define the projection.
  lines!(ax, GeoMakie.coastlines(); coastkwargs...)
* `lonticks = -180:60:180, latticks = -90:30:90` ticks for the longitude and latitude
  dimensions. The grid lines of the axis are also spanning these tick values.
* `hidespines = true` Hide the axis spines (rectangle surrounding the axis).
* `coastlines = false` draw coastlines
* `coastline_attributes = (;)` named tuple that gets passed to the `lines` call drawing the coastline

## Example
```julia
using GeoMakie, GLMakie

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

# Plot coastlines
coastplot = lines!(ax, GeoMakie.coastlines(); color = :black, overdraw = true, coastkwargs...)
translate!(coastplot, 0, 0, 99) # ensure they are on top of other plotted elements

# Surface example
fig = Figure()
ax = GeoAxis(fig[1,1])
surface!(ax, lons, lats, field)
display(fig)

# Scatter example
slons = rand(lons, 2000)
slats = rand(lats, 2000)
sfield = [exp(cosd(l)) + 3(y/90) for (l,y) in zip(slons, slats)]

fig = Figure()
ax = GeoAxis(fig[1,1])
el = scatter!(slons, slats; color = sfield)
display(fig)
```
"""
function GeoAxis(args...;
        source = "+proj=longlat +datum=WGS84", dest = "+proj=eqearth",
        transformation = Proj.Transformation(source, dest, always_xy=true),
        lonlims = (-180, 180),
        latlims = (-90, 90),
        hide_original_spines = true,
        coastlines = false,
        coastline_attributes = (;),
        line_density = 1_000,
        # these are the axis keywords which we will merge in
        xtickformat = geoformat_ticklabels,
        ytickformat = geoformat_ticklabels,
        xticks = LinearTicks(7),
        yticks = LinearTicks(7),
        xticklabelpad = 5.0,
        yticklabelpad = 5.0,
        kw...
    )
    ptrans = transformation

    # Automatically determine limits!
    # TODO: should we automatically verify limits
    # or not?
    axmin, axmax, aymin, aymax = find_transform_limits(transformation)

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
        kw...)


    # Set axis transformation
    ax.scene.transformation.transform_func[] = ptrans

    # Plot coastlines
    coastplot = lines!(ax, GeoMakie.coastlines(); color = :black, coastline_attributes...)
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
    @hijack_observable :xticksvisible
    @hijack_observable :yticksvisible
    @hijack_observable :xticklabelsvisible
    @hijack_observable :yticklabelsvisible
    @hijack_observable :topspinevisible
    @hijack_observable :bottomspinevisible
    @hijack_observable :leftspinevisible
    @hijack_observable :rightspinevisible


    # WARNING: for now, we only accept xticks on the bottom
    # and yticks on the left.

    draw_geoticks!(ax, hijacked_observables, line_density)

    ax.xaxis.protrusion[] = xprot
    ax.yaxis.protrusion[] = yprot

    return ax
end

function draw_geoticks!(ax::Axis, hijacked_observables, line_density)
    topscene = ax.blockscene
    scene = ax.scene

    decorations = Dict{Symbol, Any}()

    xgridpoints = Observable(Point2f[])
    ygridpoints = Observable(Point2f[])

    xtickpoints = Observable(Point2f[])
    ytickpoints = Observable(Point2f[])

    xticklabels = Observable(String[])
    yticklabels = Observable(String[])

    topspinepoints = Observable(Point2f[])
    btmspinepoints = Observable(Point2f[])
    lftspinepoints = Observable(Point2f[])
    rgtspinepoints = Observable(Point2f[])

    xlimits = Observable((0.0f0, 0.0f0))
    ylimits = Observable((0.0f0, 0.0f0))
    # First we establish the spine points

    lift(ax.finallimits, ax.xticks, ax.xtickformat, ax.yticks, ax.ytickformat, ax.scene.px_area) do limits, xticks, xtickformat, yticks, ytickformat, pxarea

        lmin = minimum(limits)
        lmax = maximum(limits)
        xlimits[] = (lmin[1], lmax[1])
        ylimits[] = (lmin[2], lmax[2])

        _xtickvalues, _xticklabels = Makie.MakieLayout.get_ticks(xticks, identity, xtickformat, xlimits[]...)
        _ytickvalues, _yticklabels = Makie.MakieLayout.get_ticks(yticks, identity, ytickformat, ylimits[]...)

        # update but do not notify
        # project xtickpoints from inputspace to scene dataspace (do transform)
        # then project to scene pixelspace.
        # TODO this is still not working right - the text positions almost look stretched
        # or multiplied out from where they should be.
        xtickpoints.val = Point2f.(
            Makie.project.(
                # obtain the camera of the Scene which will project to its screenspace
                Ref(camera(scene)),
                # go from dataspace (transformation applied to inputspace) to pixelspace
                Ref(:data), Ref(:pixel),
                # apply the transform to go from inputspace to dataspace
                Makie.apply_transform(
                    scene.transformation.transform_func[],
                    Point2f.(_xtickvalues, ylimits[][1])
                )
            )
        ) .+ Ref(Point2f(pxarea.origin) + Point2f(-ax.xticklabelpad[], 0))

        ytickpoints.val = Point2f.(
            Makie.project.(
                Ref(camera(scene)),
                Ref(:data), Ref(:pixel),
                Makie.apply_transform(
                    scene.transformation.transform_func[],
                    Point2f.(xlimits[][1], _ytickvalues)
                )
            )
        ) .+ Ref(Point2f(pxarea.origin) + Point2f(0, -ax.yticklabelpad[]))

        # notify this
        xticklabels[] = _xticklabels
        yticklabels[] = _yticklabels

        Makie.Observables.notify!(xtickpoints); Makie.Observables.notify!(ytickpoints)

        xrange = LinRange(xlimits[]..., line_density)
        yrange = LinRange(ylimits[]..., line_density)

        # first update the spine
        topspinepoints[] = Point2f.(xrange, ylimits[][2])
        btmspinepoints[] = Point2f.(xrange, ylimits[][1])
        lftspinepoints[] = Point2f.(xlimits[][1], yrange)
        rgtspinepoints[] = Point2f.(xlimits[][2], yrange)

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

        return 1
        # Now, we've updated the entire axis.
    end

    Makie.Observables.notify!(ax.xticks)

    # Time to plot!

    # First, we plot the spines:

    decorations[:topspineplot] = lines!(
        scene, topspinepoints;
        visible = hijacked_observables[:topspinevisible],
        color = ax.topspinecolor,
        # linestyle = ax.spinestyle,
        linewidth = ax.spinewidth, inspectable = false
        )
    decorations[:btmspineplot] = lines!(
        scene, btmspinepoints;
        visible = hijacked_observables[:bottomspinevisible],
        color = ax.bottomspinecolor,
        # linestyle = ax.spinestyle,
        linewidth = ax.spinewidth, inspectable = false
        )
    decorations[:lftspineplot] = lines!(
        scene, lftspinepoints;
        visible = hijacked_observables[:leftspinevisible],
        color = ax.leftspinecolor,
        # linestyle = ax.spinestyle,
        linewidth = ax.spinewidth,
        inspectable = false
        )
    decorations[:rgtspineplot] = lines!(
        scene, rgtspinepoints;
        visible = hijacked_observables[:rightspinevisible],
        color = ax.rightspinecolor,
        # linestyle = ax.spinestyle,
        linewidth = ax.spinewidth,
        inspectable = false
        )


    # Now for the grids:

    decorations[:xgridplot] = lines!(
        scene, xgridpoints;
        visible = hijacked_observables[:xgridvisible],
        color = ax.xgridcolor,
        linestyle = ax.xgridstyle,
        width = ax.xgridwidth,
        inspectable = false
    )
    decorations[:ygridplot] = lines!(
        scene, ygridpoints;
        visible = hijacked_observables[:ygridvisible],
        color = ax.ygridcolor,
        linestyle = ax.ygridstyle,
        width = ax.ygridwidth,
        inspectable = false
    )


    # And finally, the TikZ!

    # ax_scenearea = Makie.MakieLayout.sceneareanode!(ax.layoutobservables.computedbbox, ax.finallimits, ax.aspect)
    # # # This is specifically a Scene for the text!
    # textscene = Scene(ax.blockscene, px_area=ax_scenearea)

    textscene = ax.blockscene

    # TODO: fix text!
    decorations[:xtickplot] = text!(
        textscene,
        xticklabels;
        markerspace = :screen,
        visible = hijacked_observables[:xticklabelsvisible],
        position = xtickpoints,
        rotation = ax.xticklabelrotation,
        font = ax.xticklabelfont,
        fontsize = ax.xticklabelsize,
        color = ax.xticklabelcolor,
        align = (:center, :top),
        inspectable = false
    )

    decorations[:ytickplot] = text!(
        textscene,
        yticklabels;
        markerspace = :screen,
        visible = hijacked_observables[:yticklabelsvisible],
        position = ytickpoints,
        rotation = ax.yticklabelrotation,
        font = ax.yticklabelfont,
        fontsize = ax.yticklabelsize,
        color = ax.yticklabelcolor,
        align = (:right, :center),
        inspectable = false
    )

    # For diagnostics only!
    # scatter!(textscene, xtickpoints; visible = hijacked_observables[:xticklabelsvisible], color = :red, bordercolor=:black)
    # scatter!(textscene, ytickpoints; visible = hijacked_observables[:yticklabelsvisible], color = :red, bordercolor=:black)

    # Finally, we translate these plots such that they are above the content.
    Makie.update_cam!(scene)
    translate!.(values(decorations), 0, 0, 100)

    return decorations
end
