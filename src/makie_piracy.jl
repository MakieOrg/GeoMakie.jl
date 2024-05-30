
# Quick fixes for Makie
Makie.to_colormap(::Nothing) = nothing

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

