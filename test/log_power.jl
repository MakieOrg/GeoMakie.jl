# # Implementing log/exponent transformations
# The CoordinateTransformations library provides a flexible and extensible framework
# for constructing coordinate transformations.

using CoordinateTransformations

struct LogTransformation{T <: Real} <: CoordinateTransformations.Transformation
    base
end

struct ExponentialTransformation{T <: Real} <: CoordinateTransformations.Transformation
    base::T
end

const ExpTransformation = ExponentialTransformation

function LogTransformation(; base::T = ℯ) where T
    return LogTransformation(base)
end

function ExponentialTransformation(; base::T = ℯ) where T
    return ExponentialTransformation(base)
end

(lt::LogTransformation)(x) = log.(lt.base, x)
(pt::ExponentialTransformation)(x) = lt.base .^ x

Base.inv(lt::LogTransformation) = ExponentialTransformation(lt.base)
Base.inv(pt::ExponentialTransformation) = LogTransformation(pt.base)

compose(lt::LogTransformation, pt::ExponentialTransformation) = lt.base == pt.base ? IdentityTransformation() : ComposedTransformation(lt, pt)
compose(pt::ExponentialTransformationlt::LogTransformation) = lt.base == pt.base ? IdentityTransformation() : ComposedTransformation(pt, lt)
