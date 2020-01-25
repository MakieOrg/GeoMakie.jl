@recipe(Coastlines) do scene
    merge(
        default_theme(scene, Lines),
        Theme(crs = (source = LonLat(), dest = LonLat()),)
    )
end

function AbstractPlotting.plot!(p::Coastlines)

    @extract p (crs,)

    new_linevec = Node(COASTLINES_LINEVEC)

    lift(crs.source, crs.dest) do source, dest
        new_linevec[] = Proj4.transform.(source, dest, COASTLINES_LINEVEC)
    end

    lines!(p, new_linevec)
end

coastlines(; kwargs...) = coastlines(1; kwargs...)
coastlines!(sc = AbstractPlotting.current_scene(); kwargs...) = coastlines!(sc, 1; kwargs...)

@recipe(Earth, bbox) do scene
    merge(
        default_theme(scene, Surface),
        Theme(
            crs = (
                source = LonLat(),
                dest = LonLat()
            ),
            shading = false
        )
    )
end

function AbstractPlotting.plot!(p::Earth)

    @extract p (crs,)

    lons = LinRange(-180, 179, size(EARTH_IMG)[2])
    lats = LinRange(89.5, -89.5, size(EARTH_IMG)[1])

    xs = Node([lon for lat in lats, lon in lons])
    ys = Node([lat for lat in lats, lon in lons])

    lift(crs.source, crs.dest) do source, dest

        xs.val = [lon for lat in lats, lon in lons]
        ys.val = [lat for lat in lats, lon in lons]
        Proj4.transform!(source, dest, vec(xs.val), vec(ys.val))

        xs[] = xs[]
        ys[] = ys[]
    end

    surface!(p, xs, ys, zeros(size(xs[])); color = EARTH_IMG, shading = false, show_axis = false)
end

earth(; kwargs...) = earth(1; kwargs...)
earth!(sc = AbstractPlotting.current_scene(); kwargs...) = earth!(sc, 1; kwargs...)
