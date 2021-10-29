function geosurface!(ax, A, lon, lat; 
        coastlines = true, coastkwargs = NamedTuple(), 
        transformation = Proj4.Transformation("+proj=longlat +datum=WGS84", "+proj=wintri", always_xy=true)
        surfkwargs = NamedTuple(),
    )

    prepare_geoaxis!(ax, lons, lats, transformation, :regular)
    coastlines && lines!(ax, GeoMakie.coastlines(), color = :black, overdraw = true, coastkwargs...)
    hm = surface!(ax, lons, lats, A; shading = false, surfkwargs...)
    return hm
end

function geoscatter!(ax, A, lon, lat;
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
    return nothing
end