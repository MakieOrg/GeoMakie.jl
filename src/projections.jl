"""
    TransverseMercator(; central_longitude=0.0, central_latitude=0.0, false_easting=0.0, false_northing=0.0, scale_factor=1.0, units = "m")

## Parameters

* `central_longitude`:
    The true longitude of the central meridian in degrees.
    Defaults to 0.
* `central_latitude`:
    The true latitude of the planar origin in degrees. Defaults to 0.
* `false_easting`:
    X offset from the planar origin in metres. Defaults to 0.
* `false_northing`:
    Y offset from the planar origin in metres. Defaults to 0.
* `scale_factor`:
    Scale factor at the central meridian. Defaults to 1.
"""
function TransverseMercator(; central_longitude=0.0, central_latitude=0.0, false_easting=0.0, false_northing=0.0, scale_factor=1.0, units = "m")
    proj4_params = [
        ("proj", "tmerc"),
        ("lon_0", central_longitude),
        ("lat_0", central_latitude),
        ("k", scale_factor),
        ("x_0", false_easting),
        ("y_0", false_northing),
        ("units", units)
    ]

    return Projection(proj4_params)
end

"""
UTM(zone, southern_hemisphere=false; units = "m")

## Parameters
zone:
    The numeric zone of the UTM required.
`southern_hemisphere`:
    Set to True if the zone is in the southern hemisphere. Defaults to
    False.
"""
function UTM(zone, southern_hemisphere=false; units = "m")
    proj4_params = [
        ("proj", "utm"),
        ("units", units),
        ("zone", zone)
    ]

    if southern_hemisphere
        push!(proj4_params, ("south", nothing))
    end

    return Projection(proj4_params)
end

"""
    Mercator(; central_longitude=0.0,
            latitude_true_scale=nothing, false_easting=0.0, false_northing=0.0,
            scale_factor=nothing, units = "m")

## Parameters
*  `central_longitude`:
   The central longitude. Defaults to 0.
*  `latitude_true_scale`:
   The latitude where the scale is 1. Defaults to 0 degrees.
*  `false_easting`:
   X offset from the planar origin in metres. Defaults to 0.
*  `false_northing`:
   Y offset from the planar origin in metres. Defaults to 0.
*  `scale_factor`:
   Scale factor at natural origin. Defaults to unused.

!!! note
    Only one of ``latitude_true_scale`` and ``scale_factor`` should
    be included.
"""
function Mercator(; central_longitude=0.0,
                    latitude_true_scale=nothing, false_easting=0.0, false_northing=0.0,
                    scale_factor=nothing, units = "m"
        )

    @assert isnothing(latitude_true_scale) && isnothing(scale_factor) "Only one of latitude_true_scale and scale_factor can be included!"

    proj4_params = [
        ("proj", "merc"),
        ("lon_0", central_longitude),
        ("x_0", false_easting),
        ("y_0", false_northing),
        ("units", units)
    ]

    if latitude_true_scale !== nothing
        push!(proj4_params, ("lat_true_scale", latitude_true_scale))
    elseif scale_factor !== nothing
        push!(proj4_params, ("k_0", scale_factor))
    end

    return Projection(proj4_params)

end

"""
AlbersEqualArea(; central_longitude=0.0, central_latitude=0.0,
                 false_easting=0.0, false_northing=0.0,
                 standard_parallels=(20.0, 50.0)
        )

This projection is conic and equal-area, and is commonly used for maps of
the conterminous United States.

## Parameters
* `central_longitude`:
    The central longitude. Defaults to 0.
* `central_latitude`:
    The central latitude. Defaults to 0.
* `false_easting`:
    X offset from planar origin in metres. Defaults to 0.
* `false_northing`:
    Y offset from planar origin in metres. Defaults to 0.
* `standard_parallels`:
    The one or two latitudes of correct scale. Defaults to (20, 50).
"""
function AlbersEqualArea(; central_longitude=0.0, central_latitude=0.0,
                 false_easting=0.0, false_northing=0.0,
                 standard_parallels=(20.0, 50.0), units = "m")

    proj4_params = [
        ("proj", "aea"),
        ("lon_0", central_longitude),
        ("lat_0", central_latitude),
        ("x_0", false_easting),
        ("y_0", false_northing),
        ("lat_1", standard_parallels[1]),
        ("lat_2", standard_parallels[2]),
        ("units", units)
    ]

    return Projection(proj4_params)
end

"""
    Robinson(; central_longitude=0.0, false_easting=0.0, false_northing=0.0, units = "m")

The Robinson projection is the successor of the van der Grinten series of projections,
and was created specifically for the purpose of world mapping.

## Parameters
* `central_longitude`:
    The central longitude. Defaults to 0.
* `false_easting`:
    X offset from planar origin in metres. Defaults to 0.
* `false_northing`:
    Y offset from planar origin in metres. Defaults to 0.

"""
function Robinson(;
    central_longitude=0.0,
    radius = nothing,
    false_easting=0.0,
    false_northing=0.0,
    units = "m"
    )

    proj4_params = [
        ("proj", "robin"),
        ("lon_0", central_longitude),
        ("x_0", false_easting),
        ("y_0", false_northing),
    ]

    if radius !== nothing
        push!(proj4_params, ("R", radius))
    end

    return Projection(proj4_params)

end

"""
WinkelTripel(; central_longitude = 0, first_parallel = 0, false_easting=0,
            false_northing=0, units = "m")

The Winkel tripel projection was the successor of the Robinson projection, and
minimizes the triplet (_tripel_) of distortions: area, direction, and distance.
"""
function WinkelTripel(;
            central_longitude = 0,
            first_parallel = 0,
            false_easting=0,
            false_northing=0,
            units = "m"
        )

    proj4_params = [
        ("proj", "wintri"),
        ("lon_0", central_longitude),
        ("lat_1", first_parallel),
        ("x_0", false_easting),
        ("y_0", false_northing),
        ("units", units)
    ]


    return Projection(proj4_params)
end
