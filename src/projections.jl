function Projection(args::Vector{<: Union{Pair, Tuple{String, Any}}})

    str = ""

    for (arg, val) in args
        if val === nothing
            str *= "+" * string(arg)
        else
            str *= "+$arg=$val"
        end
        str *= " "
    end

    return Projection(str)
end

Projection(args::Pair...) = Projection(args)

function Proj4.transform(
        src::Projection, dest::Projection,
        x::AbstractVecOrMat{<: AbstractFloat},
        y::AbstractVecOrMat{<: AbstractFloat},
        z::AbstractVecOrMat{<: AbstractFloat} = zeros(size(y))
    )

    @assert size(x) == size(y) == size(z)

    xv, yv, zv = vec(Float64.(x)), vec(Float64.(y)), vec(Float64.(z))

    Proj4.transform!(src, dest, xv, yv, zv)

    return xv, yv, zv
end

function Proj4.transform!(
    src::Projection, dest::Projection,
    x::VecOrMat{Float64},
    y::VecOrMat{Float64},
    z::VecOrMat{Float64} = zeros(size(y))
    )

    return Proj4.transform!(src, dest, vec(x), vec(y), vec(z))
end

function Proj4.transform!(src::Projection, dest::Projection, x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64} = zeros(length(y)); radians = false)
    @assert length(x) == length(y) == length(z) "Input vectors must have the same length!"
    if !radians && is_latlong(src)
        x .= deg2rad.(x)
        y .= deg2rad.(y)
    end
    Proj4._transform!(src.rep, dest.rep, length(x), 1, x, y, z)
    if !radians && is_latlong(dest)
        x .= deg2rad.(x)
        y .= deg2rad.(y)
    end
    position
end

Proj4.transform(src::Projection, dest::Projection, x::Point2f0) = Point2f0(Proj4.transform(src, dest, [x[1], x[2]]))

# Proj4.transform!(src::Projection, dest::Projection, points::T) where T <: StructVector{Point2f0} = Proj4.transform!(src, dest, points.data)

const PtrOrVecCdouble = Union{Ptr{Cdouble}, Vector{Cdouble}}
"Low level interface to libproj transform, C_NULL can be passed in for z, if it's 2-dimensional"
function Proj4._transform!(src_ptr::Ptr{Cvoid}, dest_ptr::Ptr{Cvoid}, point_count::Integer, point_stride::Integer,
                     x::PtrOrVecCdouble, y::PtrOrVecCdouble, z::PtrOrVecCdouble)
    @assert src_ptr != C_NULL && dest_ptr != C_NULL
    err = ccall((:pj_transform, Proj4.libproj), Cint, (Ptr{Cvoid}, Ptr{Cvoid}, Clong, Cint, Ptr{Cdouble}, Ptr{Cdouble},
                Ptr{Cdouble}), src_ptr, dest_ptr, point_count, point_stride, x, y, z)
    err != 0 && error("transform error: $(_strerrno(err))")
end

"""
    LonLat()

Standard latitude-longitude grid.
"""
LonLat() = Projection("+proj=longlat +datum=WGS84")
const PlateCarree = LonLat

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

struct PROJ{ST, DT}
    source::ST
    dest::DT
end

function (proj::PROJ)(x::Point2)
    matr = transform(proj.source, proj.dest, [x[1] x[2] 0])
    return Point2f0(matr[1], matr[2])
end

function proj(source, dest)
    return Makie.PointTrans{2}(PROJ(source, dest))
end
