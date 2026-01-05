"""
    abstract type GlobeTransform 

The supertype for all globe transforms.  
    
All subtypes must be callable with a Point, and have a field `zlevel`.

Construct via [`create_globe_transform`](@ref).  Used in [`GlobeAxis`](@ref).
"""
abstract type GlobeTransform end

function create_globe_transform(dest::Geodesy.Ellipsoid, src::Type, zlevel)
    return GeodesyGlobeTransform(dest, src, zlevel)
end

function create_globe_transform(dest::Geodesy.Ellipsoid, src::Union{String, GeoFormatTypes.GeoFormat}, zlevel)
    return ProjGlobeTransform(dest, src, zlevel)
end

function create_globe_transform(dest, src, zlevel)
    return ProjGlobeTransform(dest, src, zlevel)
end

"""
    struct ProjGlobeTransform <: GlobeTransform
    ProjGlobeTransform(dest, src, zlevel)

Proj.jl based transformation to the `dest` ellipsoid (from Geodesy.jl).
"""
struct ProjGlobeTransform <: GlobeTransform
    transf::Proj.Transformation
    zlevel::Float64
end

function ProjGlobeTransform(dest::Geodesy.Datum, src, zlevel)
    return ProjGlobeTransform(Geodesy.ellipsoid(dest), src, zlevel)
end
function ProjGlobeTransform(dest::Geodesy.Ellipsoid, src, zlevel)
    # if a sphere is requested, then use the radius directly.
    if iszero(dest.f) || dest.a == dest.b
        dest_str = "+proj=cart +R=$(dest.a)"
    else # it's an actual ellipsoid, so provide shape params.
        dest_str = "+proj=cart +a=$(dest.a) +b=$(dest.b)"
    end
    transf = create_transform(dest_str, src)
    return ProjGlobeTransform(transf, zlevel)
end
ProjGlobeTransform(dest, src, zlevel) = ProjGlobeTransform(create_transform(dest, src), zlevel)


function (f::ProjGlobeTransform)(pt::Makie.VecTypes{3, T}) where {T}
    return Point3(f.transf((pt[1], pt[2], pt[3] + f.zlevel)))
end
function (f::ProjGlobeTransform)(pt::Makie.VecTypes{2, T}) where {T}
    return Point3(f.transf((pt[1], pt[2], f.zlevel)))
end
function (f::ProjGlobeTransform)(pt)
    z = GI.is3d(pt) ? GI.z(pt) + f.zlevel : f.zlevel
    return Point3(f.transf((GI.x(pt), GI.y(pt), z)))
end

struct InverseProjGlobeTransform <: GlobeTransform
    inv_transf::Proj.Transformation
    zlevel::Float64
end

function InverseProjGlobeTransform(transf::ProjGlobeTransform)
    inv_transf = Base.inv(transf.transf)
    return InverseProjGlobeTransform(inv_transf, 0.0)
end

function (f::InverseProjGlobeTransform)(pt::Makie.VecTypes{3, T}) where {T}
    return Point3(f.inv_transf((pt[1], pt[2], pt[3])))
end
function (f::InverseProjGlobeTransform)(pt::Makie.VecTypes{2, T}) where {T}
    return Point3(f.inv_transf((pt[1], pt[2], f.zlevel)))
end
function (f::InverseProjGlobeTransform)(pt)
    z = GI.is3d(pt) ? GI.z(pt) + f.zlevel : f.zlevel
    return Point3(f.inv_transf((GI.x(pt), GI.y(pt), z)))
end

Makie.inverse_transform(f::ProjGlobeTransform) = InverseProjGlobeTransform(f)
Makie.inverse_transform(f::InverseProjGlobeTransform) = ProjGlobeTransform(Base.inv(f.inv_transf), f.zlevel)

struct GeodesyGlobeTransform{CoordType, T} <: GlobeTransform
    transf::T
    zlevel::Float64
end

function GeodesyGlobeTransform(dest::Geodesy.Ellipsoid, src::Type{Geodesy.LLA}, zlevel)
    transf = Geodesy.ECEFfromLLA(dest)
    return GeodesyGlobeTransform{src, typeof(transf)}(transf, zlevel)
end
function GeodesyGlobeTransform(dest::Geodesy.Ellipsoid, src::Type{Geodesy.UTM}, zlevel)
    transf = Geodesy.ECEFfromUTM(dest)
    return GeodesyGlobeTransform{src, typeof(transf)}(transf, zlevel)
end
function GeodesyGlobeTransform(dest::Geodesy.Ellipsoid, src::Type{Geodesy.UTMZ}, zlevel)
    return GeodesyGlobeTransform{src}(Geodesy.ECEFfromUTMZ(dest), zlevel)
end

function (f::GeodesyGlobeTransform{Geodesy.LLA})(pt::Makie.VecTypes{3, T}) where {T}
    return Point3(f.transf(Geodesy.LLA(pt[2], pt[1], pt[3] + f.zlevel))...)
end
function (f::GeodesyGlobeTransform{Geodesy.LLA})(pt::Makie.VecTypes{2, T}) where {T}
    return Point3(f.transf(Geodesy.LLA(pt[2], pt[1], f.zlevel))...)
end

struct InverseGeodesyGlobeTransform{CoordType, T} <: GlobeTransform
    inv_transf::T
    zlevel::Float64
end

function InverseGeodesyGlobeTransform(transf::GeodesyGlobeTransform{Src}) where Src
    inv_transf = Base.inv(transf.transf)
    return InverseGeodesyGlobeTransform{src, typeof(inv_transf)}(inv_transf, 0.0)
end

function (f::InverseGeodesyGlobeTransform{Geodesy.LLA})(pt::Makie.VecTypes{3, T}) where {T}
    lla = f.inv_transf(pt)
    return Point3(lla.lon, lla.lat, lla.alt)
end
function (f::InverseGeodesyGlobeTransform{Geodesy.LLA})(pt::Makie.VecTypes{2, T}) where {T}
    lla = f.inv_transf(Point3(pt[1], pt[2], f.zlevel))
    return Point3(lla.lon, lla.lat, lla.alt)
end

Makie.inverse_transform(f::GeodesyGlobeTransform) = InverseGeodesyGlobeTransform(f)


# ## Generic methods for globe transforms
# First, single point transformation
function Makie.apply_transform(t::GlobeTransform, v::V) where V <: VecTypes{2,T} where {T}
    return t(Point2(v[1], v[2]))
end
function Makie.apply_transform(t::GlobeTransform, v::V) where V <: VecTypes{3,T} where {T}
    return t(Point3(v[1], v[2], v[3]))
end
# Then, bounding box transformation via densification.
# TODO: is there a better way, knowing we are on an ellipsoid of revolution?
function iterated_bounds_3d(f, (xmin, xmax), (ymin, ymax), N = 21; zlevel = 0)
    umin, umax = Inf, -Inf
    vmin, vmax = Inf, -Inf
    wmin, wmax = Inf, -Inf
    for x in LinRange(xmin, xmax, N)
        for y in LinRange(ymin, ymax, N)
            u, v, w = Makie.apply_transform(f, Vec(x, y, zlevel))
            isfinite(u) && (umin = min(umin, u))
            isfinite(u) && (umax = max(umax, u))
            isfinite(v) && (vmin = min(vmin, v))
            isfinite(v) && (vmax = max(vmax, v))
            isfinite(w) && (wmin = min(wmin, w))
            isfinite(w) && (wmax = max(wmax, w))
        end
    end
    return (umin, umax), (vmin, vmax), (wmin, wmax)
end

# Converting rectangles requires densifying the edges.
function Makie.apply_transform(f::GlobeTransform, r::Rect2{T}; zlevel = f.zlevel) where {T}
    xmin, ymin = minimum(r)
    xmax, ymax = maximum(r)

    if isapprox(xmin, -180, rtol = 1e-4)
        xmin - -180e0
    end
    if isapprox(xmax, 180; rtol = 1e-4)
        xmax = 180e0
    end
    if isapprox(ymin, -90; rtol = 1e-4)
        ymin = -90e0
    end
    if isapprox(ymax, 90; rtol = 1e-4)
        ymax = 90e0
    end

    try
        (umin, umax), (vmin, vmax), (wmin, wmax) = iterated_bounds_3d(f, (xmin,xmax), (ymin,ymax); zlevel)
        return Rect3(Vec3(T(umin), T(vmin), T(wmin)), Vec3(T(umax-umin), T(vmax-vmin), T(wmax-wmin)))
    catch e
        @show r
        rethrow(e)
    end
end
function Makie.apply_transform(f::GlobeTransform, r::Rect3{T}) where {T}
    r2 = Rect2{T}(r)
    tr2 = Makie.apply_transform(f, r2; zlevel = origin(r)[3] + widths(r)[3] + f.zlevel)
    return Rect3{T}(tr2.origin, tr2.widths)
end