using Geodesy


# This is how we implement Makie's transformation interface.
function Makie.apply_transform(f::Geodesy.ECEFfromLLA, pt::V) where V <: VecTypes{3, T} where {T}
    # The convention in Makie is that x is longitude, y is latitude, and z is altitude if present.
    # However, the `LLA` coordinate space expects x to be latitude and y to be longitude,
    # so we have to manually swap the coordinates.
    return V((f(LLA(pt[2], pt[1], pt[3])) ./ 2.5f3)...)
    # Enterprising observers will note the division by 50,000.  This is to "normalize" the sphere; 
    # Geodesy.jl outputs in meters, which would make the sphere hilariously large. 
    # This also fits well with Makie's limit finding, which works in input space, and not transformed space.
end

# If a Point2f is passed, we decide to handle that by assuming altitude to be 0.  
function apply_transform(f::Geodesy.ECEFfromLLA, pt::V) where V <: VecTypes{N, T} where {N, T}
    return apply_transform(f, to_ndim(Point3f, pt, 0))
end

# This is a necessary dispatch for all vectors of points.
function apply_transform(f::Geodesy.ECEFfromLLA, data::AbstractArray)
    map(point-> apply_transform(f, point), data)
end

# ## Bonus points

# Now, we define the inverse transformation as well.
# This is actually not necessary if we're just plotting something,
# but useful nonetheless.
Makie.inverse_transform(f::Geodesy.ECEFfromLLA) = Base.inv(f)
# and its application:
function Makie.apply_transform(f::Geodesy.LLAfromECEF, pt::V) where V <: VecTypes{3, T} where {T}
    return V((f(ECEF(pt[1], pt[2], pt[3]) .* 5f4))...) # invert the previous scale factor
end

function apply_transform(f::Geodesy.LLAfromECEF, pt::V) where V <: VecTypes{N, T} where {N, T}
    return apply_transform(f, to_ndim(Point3f, pt, 0))
end

# This is a necessary dispatch for all vectors of points.
function apply_transform(f::Geodesy.LLAfromECEF, data::AbstractArray)
    map(point-> apply_transform(f, point), data)
end

# Examples

# f, a, p = surface(-180..180, -90..90, rand(100, 100); axis = (; type = LScene))
# mesh_transform = Makie.PointTrans{3}() do p::Point3
#     return Point3f((transf(LLA(p[2], p[1], p[3])) ./ 5f4)...) # use a scale factor to avoid Float32 inaccuracy
# end 
# p.transformation.transform_func[] = mesh_transform
# f

# The above is a pretty simple example.  It actually doesn't work in GLMakie since surface is probably assumed to be some kind of height map.
