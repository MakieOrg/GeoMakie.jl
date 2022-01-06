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
  configure the map projection to be used for the given field using Proj4.jl.
  See also online the section [Changing central longitude](@ref) for data that may not
  span the (expected by default) longitude range from -180 to 180.
* `transformation = Proj4.Transformation(source, dest, always_xy=true)`: Instead of
  `source, dest` you can directly use the Proj4.jl package to define the projection.
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
        transformation = Proj4.Transformation(source, dest, always_xy=true),
        lonticks = -180:60:180,
        latticks = -90:30:90,
        hidespines = true,
        coastlines = false,
        coastline_attributes = (;),
        aspect = DataAspect(),
        kw...
    )
    ptrans = Makie.PointTrans{2}() do p
        transformation(p) ./ 10_0000f0
    end

    xticks = first.(Makie.apply_transform(ptrans, Point2f0.(lonticks, latticks[1])))
    yticks = last.(Makie.apply_transform(ptrans, Point2f0.(lonticks[1], latticks)))
    # Generate Axis instance
    ax = Axis(args...;
        aspect = aspect,
        xticks = (xticks, string.(lonticks, 'ᵒ')),
        yticks = (yticks, string.(latticks, 'ᵒ')),
        limits = (extrema(lonticks), extrema(latticks)),
        kw...)

    # Set axis transformation
    ax.scene.transformation.transform_func[] = ptrans

    # Plot coastlines
    if coastlines
        coastplot = lines!(ax, GeoMakie.coastlines(); color = :black, coastline_attributes...)
        translate!(coastplot, 0, 0, 99) # ensure they are on top of other plotted elements
    end
    # Draw tick lines
    ax.xgridvisible=false; ax.ygridvisible=false
    # TODO: How to get "default" grid line style from the theme?
    for lon in lonticks
        coords = [Point2f(lon, l) for l in range(latticks[1], latticks[end]; length = 100)]
        gridplot = lines!(ax, coords; color = :gray20, linewidth = 0.5)
        translate!(gridplot, 0, 0, 100) # ensure they are on top of other plotted elements
    end

    for lat in latticks
        coords = [Point2f(l, lat) for l in range(lonticks[1], lonticks[end]; length = 100)]
        gridplot = lines!(ax, coords; color = :gray20, linewidth = 0.5)
        translate!(gridplot, 0, 0, 100) # ensure they are on top of other plotted elements
    end

    hidespines && hidespines!(ax)
    return ax
end
