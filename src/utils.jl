rec_point(x::Vector{<: AbstractFloat}) = Point2f0(x)
rec_point(x) = rec_point.(x)

rec_project(source::Projection, dest::Projection, array) = rec_project.(source, dest, array)
rec_project(source::Projection, dest::Projection, point::Point2f0) = transform(source, dest, point)
