import CoordinateTransformations
import GeoInterface as GI

struct UnitCartesianFromGeographic <: CoordinateTransformations.Transformation 
end

function (::UnitCartesianFromGeographic)(geographic_point)
    # Longitude is directly translatable to a spherical coordinate
    # θ (azimuth)
    θ = deg2rad(GI.x(geographic_point))
    # The polar angle is 90 degrees minus the latitude, so we must use cosine instead of sine.
    # ϕ (polar angle)
    ϕ = deg2rad(90 - GI.y(geographic_point))
    # Since this is the unit sphere, the radius is assumed to be 1,
    # and we don't need to multiply by it.
    return Point3(
        sin(ϕ) * cos(θ),
        sin(ϕ) * sin(θ),
        cos(ϕ)
    )
end

Base.inv(::UnitCartesianFromGeographic) = GeographicFromUnitCartesian()





struct GeographicFromUnitCartesian <: CoordinateTransformations.Transformation 
end

function (::GeographicFromUnitCartesian)(xyz::AbstractVector)
    @assert length(xyz) == 3 "GeographicFromUnitCartesian expects a 3D Cartesian vector"
    x, y, z = xyz
    return Point2(
        atan(y, x),
        atan(hypot(x, y), z),
    )
end

Base.inv(::GeographicFromUnitCartesian) = UnitCartesianFromGeographic()



struct GeographicUVFromUnitCartesian <: CoordinateTransformations.Transformation 
end

function (::GeographicUVFromUnitCartesian)(xyz::AbstractVector)
    @assert length(xyz) == 3 "GeographicFromUnitCartesian expects a 3D Cartesian vector"
    x, y, z = xyz
    return Point2(
        ((atan(y, x))/(2pi) + 1)/1.5,
        ((atan(hypot(x, y), z))/pi + 0.5)/1.5,
    )
end
