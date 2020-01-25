@recipe(Coastlines) do scene
    merge(
        default_theme(scene, Lines),
        Theme(crs = (source = LonLat(), dest = LonLat()),)
    )
end

function plot!(p::Coastlines)

    @extract p (crs,)

    new_linevec = Node(COASTLINES_LINEVEC)

    lift(crs.source, crs.dest) do source, dest
        new_linevec[] = Proj4.transform.(source, dest, COASTLINES_LINEVEC)
    end

    lines!(p, p.attributes, )
end

@recipe(Earth) do scene
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

function plot!(p::Earth)

    @extract p (crs,)

    lons = LinRange(-179, 180, size(EARTH_IMG)[2])
    lats = LinRange(90, -89, size(EARTH_IMG)[1])

    xs = Node([lon for lat in lats, lon in lons])
    ys = Node([lat for lat in lats, lon in lons])

    lift(crs.source, crs.dest) do src, dest

        xs.val = [lon for lat in lats, lon in lons]
        ys.val = [lat for lat in lats, lon in lons]
        Proj4.transform!(source, dest, vec(xs), vec(ys))

        notify!(xs)
        notify!(ys)
    end

    surface!(p, p.attributes, xs, ys, zeros(size(xs)); color = EARTH_IMG, shading = false, show_axis = false)
end
