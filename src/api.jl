funs = (:geosurface, :geoscatter, :geolines)
for f in funs
    inplacef = Symbol(string(f), "!")
    @eval function ($f)(args...; kwargs...)
        fig = Figure()
        ax = Axis(fig[1,1])
        el = $(inplacef)(ax, args...; kwargs...)
        return fig, ax, el
    end
end

function geosurface!(ax, A, lons, lats; 
        coastlines = true, coastkwargs = NamedTuple(), 
        source = "+proj=longlat +datum=WGS84", dest = "+proj=wintri",
        transformation = Proj4.Transformation(source, dest, always_xy=true),
        plotkwargs = NamedTuple(),
    )

    prepare_geoaxis!(ax, lons, lats, transformation, :regular)
    coastlines && lines!(ax, GeoMakie.coastlines(), color = :black, overdraw = true, coastkwargs...)
    hm = surface!(ax, lons, lats, A; shading = false, plotkwargs...)
    return hm
end

function geoscatter!(ax, A, lons, lats;
        coastlines = true, coastkwargs = NamedTuple(), 
        source = "+proj=longlat +datum=WGS84", dest = "+proj=wintri",
        transformation = Proj4.Transformation(source, dest, always_xy=true),
        plotkwargs = NamedTuple(),
        _plottype = scatter!,
    )

    prepare_geoaxis!(ax, lons, lats, transformation, :unstructured)
    coastlines && lines!(ax, GeoMakie.coastlines(), color = :black, overdraw = true, coastkwargs...)
    sc = scatter!(ax, lons, lats; color = A, plotkwargs...)
    return sc
end
geolines!(args...; kwargs...) = geoscatter!(args...; kwargs..., _plottype = lines!)

function prepare_geoaxis!(ax, lons, lats, transformation, type = :regular)
    ax.aspect = DataAspect()
    ptrans = Makie.PointTrans{2}(transformation)
    ax.scene.transformation.transform_func[] = ptrans

    # Okay, this seems to be super inefficient! we make this huge array of points
    # *only* to set the axis limits? This cannot be correct.
    if type == :regular
        points = [Point2f0(lon, lat) for lon in lons, lat in lats]
    elseif type == :unstructured
        points = [Point2f0(lon, lat) for (lon, lat) in zip(lons, lats)]
    end
    rectLimits = FRect2D(Makie.apply_transform(ptrans, points))
    limits!(ax, rectLimits)

    # This is necessary because at the moment we do not have a GeoAxis
    # and as such the grid and the ticks are all in orthogonal
    # coordinate system and in units of meters instead of degrees
    # hidedecorations!(ax)
    # hidespines!(ax)

    # change ticks into lon/lat coordinates
    lonticks = range(lons[1], lons[end]; length = 4)
    latticks = range(lats[1], lats[end]; length = 4)
    xticks = first.(transformation.(Point2f0.(lonticks, lats[1]))) 
    yticks = last.(transformation.(Point2f0.(lons[1], latticks)))
    ax.xticks = (xticks, string.(lonticks, 'ᵒ'))
    ax.yticks = (yticks, string.(latticks, 'ᵒ'))

    return nothing
end