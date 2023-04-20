using Geodesy
transf = ECEFfromLLA(WGS84())

mesh_transform = Makie.PointTrans{3}() do p::Point3
    return Point3f((transf(LLA(p[2], p[1], p[3])) ./ 5f4)...) # use a scale factor to avoid Float32 inaccuracy
end 