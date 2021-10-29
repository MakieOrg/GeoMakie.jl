##########################################################################################
# TODOs
##########################################################################################
# TODO: restore the infastructure of the previous GeoAxis where the axis grid is 
# curved and follows the projection used.
# TODO: create a function that can do surface plots for unstructured points
# (George has some script that does it lying around)

##########################################################################################
# GeoAxis implementation
##########################################################################################
"""
    GeoAxis(args...; kwargs...)
Create a new axis instance that is based on `Axis`, but is appropriate for geospatial
plotting by incorporating a user-defined map projection when plotting data.
`args...` is a standard figure location, e.g., `fig[1,1]` as given in
`Axis`. The keyword arguments decide the geospatial projection:

* `source = "+proj=longlat +datum=WGS84", dest = "+proj=eqearth"`: These two keywords
configure the map projection to be used for the given field.
* `transformation = Proj4.Transformation(source, dest, always_xy=true)`: Instead of
  `source, dest` you can directly use the Proj4.jl package to define the projection.
* `coastlines = true`: Whether to plot coastlines.
* `coastkwargs = NamedTuple()` Keywords propagated to the coastline plot (which is a line plot).
* `lonticks = -180:60:180, latticks = -90:30:90` ticks for the longitude and latitude
  dimensions (in degrees).

## Example
```julia
using GeoMakie, GLMakie

lons = -180:180
lats = -90:90
field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

# Surface example
fig = Figure()
ax = GeoAxis(fig[1,1])
el = surface!(ax, lons, lats, field)
display(fig)

# %% Scatter example
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
        transformation = Proj4.Transformation(source, dest, always_xy=true),
        coastlines = true, coastkwargs = NamedTuple(),
        lonticks = -180:60:180,
        latticks = -90:30:90,  
        kw... # TODO: Where is `kw` propagated into?
    )

    # Generate Axis instance
    ax = Axis(args...; aspect = DataAspect(), interpolate_grid = true)
    # TODO:
    # ax = Axis(args...; interpolate_grid=true)
    # interpolate_grid would need to be implemented in the axis code, but that should be fairly straightforward 
    # needed to make the grid warp correctly

    # Set axis transformation
    ptrans = Makie.PointTrans{2}(transformation)
    ax.scene.transformation.transform_func[] = ptrans

    # set axis limits
    # TODO: I don't know how to set correct limits. but this seems tremendously
    # inefficient. Like, why do we have to create millions of points?
    # Shouldn't we only need to create 4 points to set the limits of a 2D axis???
    lons = -180:180
    lats = -90:90
    points = [Point2f0(lon, lat) for lon in lons, lat in lats]
    rectLimits = FRect2D(Makie.apply_transform(ptrans, points))
    limits!(ax, rectLimits)

    # Plot coastlines
    coastlines && lines!(ax, GeoMakie.coastlines(), color = :black, overdraw = true, coastkwargs...)

    # Set ticks
    # TODO: Use latitude longitude that makes sense with given data
    # lonticks = range(lons[1], lons[end]; length = 4)
    # latticks = range(lats[1], lats[end]; length = 4)

    xticks = first.(transformation.(Point2f0.(lonticks, latticks[1]))) 
    yticks = last.(transformation.(Point2f0.(lonticks[1], latticks)))
    ax.xticks = (xticks, string.(lonticks, 'ᵒ'))
    ax.yticks = (yticks, string.(latticks, 'ᵒ'))

    # Draw tick lines
    ax.xgridvisible=false; ax.ygridvisible=false
    # TODO: How to get "default" grid line style from the theme?
    for lon in lonticks
        coords = [Point2f0(lon, l) for l in range(latticks[1], latticks[end]; length = 100)]
        lines!(coords; color = :gray20, linewidth = 0.5)
    end
    for lat in latticks
        coords = [Point2f0(l, lat) for l in range(lonticks[1], lonticks[end]; length = 100)]
        lines!(coords; color = :gray20, linewidth = 0.5)
    end

    return ax
end
