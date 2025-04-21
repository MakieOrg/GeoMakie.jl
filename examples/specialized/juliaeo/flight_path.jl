#=

# Plotting my flight path on the sphere

=#

using TidierVest, Dates # data ingestion
using DataFrames # data handling

using GeoMakie, GLMakie # plotting
import GeometryOps as GO, GeoInterface as GI # geospatial interfacing


arclength(geom; kwargs...) = arclength(GO.Planar(), geom; kwargs...)
arclength(m::GO.Manifold, geom; kwargs...) = GO.applyreduce(
    Base.Fix1(_arclength, m), # the function that operates on each element
    +,                        # the function that combines two results
    GO.TraitTarget(GO.AbstractCurveTrait), # how far to decompose
    geom; # the target geometry
    kwargs... # any kwargs like `init`, etc.
)

function _arclength(m::GO.Manifold, curve)
    first_point, rest = Iterators.peel(GI.getpoint(curve))
    second_point, rest = Iterators.peel(rest)

    distance = _point_distance(m, first_point, second_point)

    last_point = second_point

    for point in rest
        distance += _point_distance(m, last_point, point)
        last_point = point
    end

    return distance
end

_point_distance(::GO.Planar, p1, p2) = hypot(GI.x(p2) - GI.x(p1), GI.y(p2) - GI.y(p1))
function _point_distance(m::GO.Spherical, p1, p2)
    lon1, lat1 = GI.x(p1), GI.y(p1)
    lon2, lat2 = GI.x(p2), GI.y(p2)

    φ1 = lat1
    φ2 = lat2
    Δφ = (lat2-lat1)
    Δλ = (lon2-lon1)

    a = sind(Δφ/2)^2 +
            cosd(φ1) * cosd(φ2) *
            sind(Δλ/2)^2;
    c = 2 * atan(sqrt(a), sqrt(1-a));

    d = m.radius * c

    return d
end

point_along_curve(curve, dist) = point_along_curve(GO.Planar(), curve, dist)

function point_along_curve(m::GO.Manifold, curve, dist)
    current_arclength = 0.0
    current_point, rest = Iterators.peel(GI.getpoint(curve))

    for next_point in rest
        current_arclength += _point_distance(m, current_point, next_point)
        if dist < current_arclength
            # TODO: interpolate points along curve
            # Needs some interpolation strategy, or a lower level function `p1, p2, frac`.
            return current_point
        end
        current_point = next_point
    end

    return current_point
end


# create a function to parse the longitude and latitude columns, since they need the same processing
function parse_concatted_preview_value_string(numstr)
    pre_decimal, post_decimal, waste = split(numstr, '.')
    true_decimal_digits = post_decimal[1:end-length(pre_decimal)]
    return parse(Float64, "$(pre_decimal).$(true_decimal_digits)")
end

function acquire_flight_path(flight_name, day, zulu_time, departing_airport, arriving_airport)
    # Acquire the flight path by parsing the webpage
    url = "https://www.flightaware.com/live/flight/$flight_name/history/$day/$zulu_time/$departing_airport/$arriving_airport/tracklog"
    flightlog_page_parsed = TidierVest.read_html(url)
    flightlog_table_raw = TidierVest.html_elements(flightlog_page_parsed, "table.prettyTable") |> TidierVest.html_table


    # construct a cleaned table
    flightlog_table = DataFrame(
        Time = Dates.Time.(getindex.(flightlog_table_raw.var"Time (EST)EST", (16:22,)), dateformat"HH:MMp"),
        Latitude = parse_concatted_preview_value_string.(flightlog_table_raw.LatitudeLat),
        Longitude = parse_concatted_preview_value_string.(flightlog_table_raw.LongitudeLon),
        feet = map(flightlog_table_raw.feet) do fs
            if isempty(fs)
                return 36000 # this is an error in the table
            end
            ns = replace(fs, "," => "")
            return parse(Int, ns[1:length(ns)÷2])
        end
    )

    flt_path_raw = tuple.(flightlog_table.Longitude, flightlog_table.Latitude, flightlog_table.feet ./ 3.281) |> GI.LineString

    flt_path = GO.apply(GO.TraitTarget(GO.AbstractCurveTrait), flt_path_raw) do ls
        geod = Proj.geod_geodesic(6378137, 1/298.257223563)
        npoints = 100

        point1, rest = Iterators.peel(GI.getpoint(flt_path_raw))

        resulting_points = NTuple{3, Float64}[]

        for point2 in rest
            # push!(resulting_points, point)
            y1, x1, y2, x2 = GI.y(point1), GI.x(point1), GI.y(point2), GI.x(point2)
            new_ys, new_xs = Proj.geod_path(geod, y1, x1, y2, x2, npoints)
            new_zs = GI.z(point1) .+ LinRange(0, 1, npoints) .* (GI.z(point2) - GI.z(point1))

            new_zs = new_zs .* 10

            new_ys[begin] = y1
            new_ys[end] = y2


            new_xs[begin] = x1
            new_xs[end] = x2

            interpolated_points = tuple.(new_xs, new_ys, new_zs)

            append!(resulting_points, interpolated_points)
            point1 = point2
        end

        return GI.LineString(resulting_points)
    end

end

bom_zrh_flight = acquire_flight_path("SWR155", "20250102", "2000Z", "VABB", "LSZH")
zrh_lis_flight = acquire_flight_path("TAP931", "20250105", "1240Z", "LSZH", "LPPT")
lis_ter_flight = acquire_flight_path("TAP1823", "20250105", "0925Z", "LPPT", "LPLA")


using FileIO, ImageIO
# download("https://cdn.eso.org/images/original/eso0932a.tif", "eso0932a.tif")
# acknowledgment: https://www.eso.org/public/images/eso0932a/
milky_way_image = load("eso0932a.tif")
blue_marble_image = load(download("https://eoimages.gsfc.nasa.gov/images/imagerecords/73000/73580/world.topo.bathy.200401.3x5400x2700.jpg", "blue_marble.jpg"))
# begin
fig = Figure(; figure_padding = 0)
ax = GlobeAxis(fig[1, 1]; show_axis = false)

# Preparing the Earth image is simple enough, since it's natively in a long/lat projection.
earth_background_plot = meshimage!(ax, -180..180, -90..90, blue_marble_image; uv_transform = :rotl90)

# We have to rotate the Milky Way image, since it's in the celestial sphere,
# and the Earth rotates at a 23 degree angle to the ecliptic (celestial sphere equator).
milky_way_source = "+proj=ob_tran +o_proj=longlat +o_lon_p=0 +o_lat_p=23.5"
milky_way_plot = meshimage!(ax, -180..180, -90..90, milky_way_image; source = milky_way_source, uv_transform = :rotl90, zlevel = 1_000_000_000, xautolimits = false, yautolimits = false, zautolimits = false, reset_limits = false)

# Finally, we plot the flights.
bom_zrh_plot = lines!(ax, bom_zrh_flight; color = Makie.wong_colors(0.9)[2], transparency = true)
zrh_lis_plot = lines!(ax, zrh_lis_flight; color = Makie.wong_colors(0.9)[4], transparency = true)
lis_ter_plot = lines!(ax, lis_ter_flight; color = Makie.wong_colors(0.9)[end], transparency = true)

city_label_plot = text!(
    [GI.getpoint(bom_zrh_flight, 1), GI.getpoint(zrh_lis_flight, 1), GI.getpoint(lis_ter_flight, GI.npoint(lis_ter_flight))]; 
    text = ["BOM", "ZRH", "TER"],
    depth_shift = -0.01f0,
    glowwidth = 5f0,
    glowcolor = :beige 
)

# TODO: make this a plane mesh.  But this is not the time.
airplane_marker_plot = scatter!(ax, GI.getpoint(bom_zrh_flight, 1); marker = '✈', zlevel = 10_000, markersize = 15, color = :red)

bom_zrh_arclength = arclength(GO.Spherical(), bom_zrh_flight)
zrh_lis_arclength = arclength(GO.Spherical(), zrh_lis_flight)
lis_ter_arclength = arclength(GO.Spherical(), lis_ter_flight)

cc = cameracontrols(ax.scene)
# To diagnose where we are, we can simply override this 
@time record(fig, "trace_plane_path.mp4"; framerate = 60) do io
    # record each flight individually
    for i in LinRange(0, 1, 480)
        current_point = point_along_curve(GO.Spherical(), bom_zrh_flight, i * bom_zrh_arclength)
        airplane_marker_plot.args[1][] = current_point

        cc.eyeposition[] = Makie.apply_transform(earth_background_plot.transformation.transform_func[], Point3f(GI.x(current_point), GI.y(current_point), 1.1e7))
        update_cam!(ax.scene, cc)
        recordframe!(io)
    end

    # pause for 20 frames
    for i in 1:20
        recordframe!(io)
    end

    # record ZRH-LIS
    for i in LinRange(0, 1, 280)
        current_point = point_along_curve(GO.Spherical(), zrh_lis_flight, i * zrh_lis_arclength)
        airplane_marker_plot.args[1][] = current_point

        cc.eyeposition[] = Makie.apply_transform(earth_background_plot.transformation.transform_func[], Point3f(GI.x(current_point), GI.y(current_point), 1.1e7))
        update_cam!(ax.scene, cc)
        recordframe!(io)
    end

    # pause for 20 frames
    for i in 1:20
        recordframe!(io)
    end
    # record ZRH-LIS
    for i in LinRange(0, 1, 280)
        current_point = point_along_curve(GO.Spherical(), lis_ter_flight, i * lis_ter_arclength)
        airplane_marker_plot.args[1][] = current_point

        cc.eyeposition[] = Makie.apply_transform(earth_background_plot.transformation.transform_func[], Point3f(GI.x(current_point), GI.y(current_point), 1.1e7))
        update_cam!(ax.scene, cc)
        recordframe!(io)
    end

end
# end