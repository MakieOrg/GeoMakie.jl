#=
# Geodesy.jl integration

This code integrates Geodesy.jl's coordinate transformations into Makie's transformation system.

Ideally, it would be in an extension on Geodesy in Makie, but the code is evolving sufficiently quickly 
that it's best to leave it here.
=#

# This is how we implement Makie's transformation interface.
function Makie.apply_transform(f::Geodesy.ECEFfromLLA, pt::V) where V <: VecTypes{3, T} where {T}
    # The convention in Makie is that x is longitude, y is latitude, and z is altitude if present.
    # However, the `LLA` coordinate space expects x to be latitude and y to be longitude,
    # so we have to manually swap the coordinates.
    return V((f(LLA(pt[2], pt[1], pt[3])))...)
end

# If a Point2f is passed, we decide to handle that by assuming altitude to be 0.  
function Makie.apply_transform(f::Geodesy.ECEFfromLLA, pt::V) where V <: VecTypes{2, T} where {T}
    return Makie.apply_transform(f, Point3d(pt[1], pt[2], 0))
end

# This is a necessary dispatch for all vectors of points.
function Makie.apply_transform(f::Geodesy.ECEFfromLLA, data::AbstractArray)
    map(point-> Makie.apply_transform(f, point), data)
end

# ## Bonus points

# Now, we define the inverse transformation as well.
# This is actually not necessary if we're just plotting something,
# but useful nonetheless.
Makie.inverse_transform(f::Geodesy.ECEFfromLLA) = Base.inv(f)
# and its application:
function Makie.apply_transform(f::Geodesy.LLAfromECEF, pt::V) where V <: VecTypes{3, T} where {T}
    return V((f(ECEF(pt[1], pt[2], pt[3])))...)
end

function Makie.apply_transform(f::Geodesy.LLAfromECEF, pt::V) where V <: VecTypes{N, T} where {N, T}
    return Makie.apply_transform(f, to_ndim(Point3d, pt, 0))
end

# This is a necessary dispatch for all vectors of points.
function Makie.apply_transform(f::Geodesy.LLAfromECEF, data::AbstractArray)
    map(point-> Makie.apply_transform(f, point), data)
end

# Examples

# f, a, p = surface(-180..180, -90..90, rand(100, 100); axis = (; type = LScene))
# transf = Geodesy.ECEFfromLLA(WGS84())

# mesh_transform = Makie.PointTrans{3}() do p::Point3
#      # use a scale factor to avoid Float32 inaccuracy
# end 

# Makie.apply_transform(mesh_transform, Point3f(1))

# a.scene.transformation.transform_func[] = mesh_transform
# f

# # The above is a pretty simple example.  It actually doesn't work in GLMakie since surface is probably assumed to be some kind of height map.




# function fpoint2(x::Point2)
#     return Point2f(sqrt(x[1]), cos(x[2])-0.5)
# end

# function fpoint3(x::Point3)
#     return Point3f(x[1] + 10, x[2] - 77, x[3] /  4)
# end
# trans2 = Makie.PointTrans{2}(fpoint2)

# cfs = CoordinateTransformations.CartesianFromSpherical()
# function fpoint3_1(x::Point3) 
#     c = cfs(CoordinateTransformations.Spherical(x...))
#     return Point3f(c)
# end


# trans3 = Makie.PointTrans{3}(fpoint3_1)

# f, a, p = lines(Point3f.(rand(10), rand(10), 0))
# p.transformation.transform_func[] = trans3
# f

#=
transf2 = Makie.PointTrans{3}() do p
    ϕ, θ, r = p
    sθ, cθ = sincos(deg2rad(θ))
    sϕ, cϕ = sincos(deg2rad(ϕ))
    Point3(r * cθ * cϕ, r * sθ * cϕ, r * sϕ)
end

f, a, p = meshimage(0..360, 0..180, GeoMakie.earth(); z_level = 100, axis = (; type = LScene));

lats = -180:180
lons = -90:90
grid = Point2f.(lons, lats')
transformed_grid = Makie.apply_transform(transf, grid)
# transformed_grid = Geodesy.ECEFfromLLA(WGS84()).(splat(LLA).(grid)) .|> Point3f

f, a, p = surface(first.(transformed_grid), getindex.(transformed_grid, 2), last.(transformed_grid); color = rand(100, 100), axis = (; type = LScene))
f, a, p = surface(first.(grid), last.(grid), ones(100, 100); color = rand(100, 100), axis = (; type = LScene))
lp = lines!(a, Point3f.(1:10, 1:10, 110); color = :red, linewidth = 2)
p.transformation.transform_func[] = transf
lp.transformation.transform_func[] = transf2
f

=#


