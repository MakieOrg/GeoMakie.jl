
# Quick fixes for Makie
Makie.to_colormap(::Nothing) = nothing

# Add plotting capabilities for MultiLineStrings
function Makie.convert_arguments(trait::PointBased, mls::AbstractArray{<: GeometryBasics.MultiLineString})
    return Makie.convert_arguments(trait, _mls2ls.(mls)) # _mls2ls in geojson.jl
end

Makie.convert_arguments(trait::PointBased, l::GeometryBasics.Line) = (l.points,)
# Special convert for linesegments because it has special syntax
function Makie.convert_arguments(::Type{<: LineSegments}, ls::AbstractArray{<: GeometryBasics.Line})
    return Makie.convert_arguments(LineSegments, getproperty.(getproperty.(ls, :points), :data))
end
# Regular convert for all pointbased functions.  Only problem is that it probably
# will fail for polygons.  Do we care?
function Makie.convert_arguments(trait::PointBased, ls::AbstractArray{<: GeometryBasics.Line{N, T}}) where {N, T}
    ret = foldl(ls; init = [Point{N, T}(NaN)]) do acc, l
        append!(acc, l.points)
        push!(acc, Point{N, T}(NaN))
    end
    return (ret,)
end

function _append_nanpoint_and_return(ls::GeometryBasics.LineString{N, T}) where {N, T}
    return push!(copy(GeometryBasics.coordinates(ls)), Point{N, T}(NaN))
end

function Makie.convert_arguments(trait::PointBased, mps::AbstractVector{<: GeometryBasics.MultiPolygon{N, T}}) where {N, T}
    return Makie.convert_arguments(
        trait, 
        GeometryBasics.LineString.(
            GO.applyreduce.(
                (_append_nanpoint_and_return,), 
                (vcat,), 
                (GO.TraitTarget{GO.AbstractCurveTrait}(),), 
                mps; 
                init = [Point{N, T}(NaN)]
            )
        )
    )
end

#=
function Makie.transform_bbox(scenelike, lims::Rect{N, T}) where {N, T}
    mini = Makie.to_ndim(Point3d, minimum(lims), 0.0)
    maxi = Makie.to_ndim(Point3d, maximum(lims), 0.0)
    minx, miny, minz = 0.0, 0.0, 0.0
    maxx, maxy, maxz = 0.0, 0.0, 0.0
    dx, dy, dz = maxi .- mini
    for i in LinRange(0, 1, 21)
        for j in LinRange(0, 1, 21)
            for k in LinRange(0, 1, 21)
                x = mini[1] + i * dx
                y = mini[2] + j * dy
                z = mini[3] + k * dz
                p = Point3d(x, y, z)
                tp = Makie.transform_func(scenelike)(p)
                minx, miny, minz = min(minx, tp[1]), min(miny, tp[2]), min(minz, tp[3])
                maxx, maxy, maxz = max(maxx, tp[1]), max(maxy, tp[2]), max(maxz, tp[3])
            end
        end
    end
    if N == 2
        return Rect{N, T}((minx, miny), (maxx - minx, maxy - miny))
    else # N can only be 3 here since this is a plotting package
        return Rect{N, T}((minx, miny, minz), (maxx - minx, maxy - miny, maxz - minz))
    end
end
=#


# `needs_tight_limits`` should dispatch on axes too
# because what looks bad on one axis (regular Axis)
# will look good on a GeoAxis
# and vice versa

Makie.needs_tight_limits(axis::Makie.AbstractAxis, plot::Makie.Plot) = Makie.needs_tight_limits(plot)
