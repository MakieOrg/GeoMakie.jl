using CoordinateTransformations

struct LogTransformation{T <: Real} <: CoordinateTransformations.Transformation
    base
end

struct PowerTransformation{T <: Real} <: CoordinateTransformations.Transformation
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

compose(lt::LogTransformation, pt::PowerTransformation) = lt.base == pt.base ? IdentityTransformation() : ComposedTransformation(lt, pt)
compose(pt::PowerTransformationlt::LogTransformation) = lt.base == pt.base ? IdentityTransformation() : ComposedTransformation(pt, lt)
