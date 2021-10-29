function geosurface!(ax, A, lons, lats; 
        coastlines = true, coastkwargs = NamedTuple(), 
        transformation = Proj4.Transformation("+proj=longlat +datum=WGS84", "+proj=wintri", always_xy=true)
        surfkwargs = NamedTuple(),
    )

    prepare_geoaxis!(ax, lons, lats, transformation, :regular)
    coastlines && lines!(ax, GeoMakie.coastlines(), color = :black, overdraw = true, coastkwargs...)
    hm = surface!(ax, lons, lats, A; shading = false, surfkwargs...)
    return hm
end

function geoscatter!(ax, A, lons, lats;
        coastlines = true, coastkwargs = NamedTuple(), 
        transformation = Proj4.Transformation("+proj=longlat +datum=WGS84", "+proj=wintri", always_xy=true)
        scatterkwargs = NamedTuple(),
    )

    prepare_geoaxis!(ax, lons, lats, transformation, :unstructured)
    coastlines && lines!(ax, GeoMakie.coastlines(), color = :black, overdraw = true, coastkwargs...)
    sc = scatter!(ax, lons, lats; color = A, scatterkwargs...)
    return sc
end

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
    lonrange = range(lons[1], lons[end]; length = 4)
    latrange = range(lats[1], lats[end]; length = 4)
    latrange = -90:30:90
    xticks = first.(trans.(Point2f0.(lonrange, lats[1]))) 
    yticks = last.(trans.(Point2f0.(lons[1], latrange)))
    ax.xticks = (xticks, string.(lonrange, 'ᵒ'))
    ax.yticks = (yticks, string.(latrange, 'ᵒ'))

    return nothing
end