##########################################################################################
# TODOs
##########################################################################################
# TODO: restore the infastructure of the previous GeoAxis where the axis grid is 
# curved and follows the projection used.
# TODO: create a function that can do surface plots for unstructured points
# (George has some script that does it lying around)

##########################################################################################
# API declaration
##########################################################################################
"""
    geosurface(field, lons, lats; kwargs...)
    geoscatter(field, lons, lats; kwargs...)
    geolines(field, lons, lats; kwargs...)
Plot a geospatial `field` with given longitude and latitude coordinates (in degrees)
using a chosen projection as a plot over the Earth. Return `fig, ax, el` with `el` 
being the plotted element (surface, scatter, or line plot).
You can use the in-place versions `geosurface!(ax, field, lons, lats; ...)` which take
a pre-initialied axis as an input. These versions only return `el`.

## Structure of `field` 
Notice that the `geosurface` function expects `field` to be an `AbstractMatrix`, 
defined over a regular longitude-latitude grid. In contrast, `geoscatter, geolines` expect
`field` to be an `AbstractVector`, where each coordinate `lons[i], lats[i]` has value
`field[i]`.

## Keywords
* `plotkwargs = NamedTuple()`: Keywords propagated to the inner plotting function (e.g., 
  `surface!` or `scatter!`).
* `coastlines = true`: Wheteher to plot coastlines.
* `coastkwargs = NamedTuple()` Keywords propagated to the coastline plot (which is a line plot).
* `source = "+proj=longlat +datum=WGS84", dest = "+proj=wintri"`: These two keywords
  configure the map projection to be used for the given field.
* `transformation = Proj4.Transformation(source, dest, always_xy=true)`: IUnstead of
  `source, dest` you can directly use the Proj4.jl package to define the projection.
"""
function geoplot end


##########################################################################################
# Source code
##########################################################################################
funs = (:geosurface, :geoscatter, :geolines)
for f in funs
    inplacef = Symbol(string(f), "!")
    @eval begin
        function ($f)(args...; kwargs...)
            fig = Figure()
            ax = Axis(fig[1,1])
            el = $(inplacef)(ax, args...; kwargs...)
            return fig, ax, el
        end
    end
end

function geoplot!(ax, A, lons, lats;
        coastlines = true, coastkwargs = NamedTuple(), 
        source = "+proj=longlat +datum=WGS84", dest = "+proj=wintri",
        transformation = Proj4.Transformation(source, dest, always_xy=true),
        plotkwargs = NamedTuple(),
        _plottype! = A isa AbstractMatrix ? surface : scatter!,
    )

    gridtype = _plottype! == surface! ? :lonlat : :unstructured
    prepare_geoaxis!(ax, lons, lats, transformation, gridtype)
    coastlines && lines!(ax, GeoMakie.coastlines(), color = :black, overdraw = true, coastkwargs...)
   
    if _plottype! == surface!
        el = _plottype!(ax, lons, lats, A; plotkwargs...)
    else
        el = _plottype!(ax, lons, lats; color = A, plotkwargs...)
    end
    return el
end
geolines!(args...; kwargs...) = geoplot!(args...; kwargs..., _plottype! = lines!)
geoscatter!(args...; kwargs...) = geoplot!(args...; kwargs..., _plottype! = scatter!)
geosurface!(args...; kwargs...) = geoplot!(args...; kwargs..., _plottype! = surface!)

function prepare_geoaxis!(ax, lons, lats, transformation, gridtype = :lonlat)
    ax.aspect = DataAspect()
    ptrans = Makie.PointTrans{2}(transformation)
    ax.scene.transformation.transform_func[] = ptrans

    # Okay, this seems to be super inefficient! we make this huge array of points
    # *only* to set the axis limits? This cannot be correct.
    if gridtype == :lonlat
        points = [Point2f0(lon, lat) for lon in lons, lat in lats]
    elseif gridtype == :unstructured
        points = [Point2f0(lon, lat) for (lon, lat) in zip(lons, lats)]
    end
    rectLimits = FRect2D(Makie.apply_transform(ptrans, points))
    limits!(ax, rectLimits)

    # change ticks into lon/lat coordinates
    # lonticks = range(lons[1], lons[end]; length = 4)
    # latticks = range(lats[1], lats[end]; length = 4)

    lonticks = -180:60:180
    latticks = -90:30:90
    xticks = first.(transformation.(Point2f0.(lonticks, latticks[1]))) 
    yticks = last.(transformation.(Point2f0.(lonticks[1], latticks)))
    ax.xticks = (xticks, string.(lonticks, 'ᵒ'))
    ax.yticks = (yticks, string.(latticks, 'ᵒ'))

    return nothing
end