using CoordinateTransformations

struct LogTransformation{T} {where T} <: CoordinateTransformations.Transformation
    base
end

struct PowerTransformation{T} <: CoordinateTransformations.Transformation
    base::T
end

function LogTransformation(; base::T = ℯ) where T
    return LogTransformation(base)
end

function PowerTransformation(; base::T = ℯ) where T
    return PowerTransformation(base)
end

(lt::LogTransformation)(x) = log.(lt.base, x)
(pt::PowerTransformation)(x) = lt.base .^ x

Base.inv(lt::LogTransformation) = PowerTransformation(lt.base)
Base.inv(pt::PowerTransformation) = LogTransformation(pt.base)
