rec_point(x::Vector{<: AbstractFloat}) = Point2f0(x)
rec_point(x) = rec_point.(x)

rec_project(source::Projection, dest::Projection, array) = rec_project.(source, dest, array)
rec_project(source::Projection, dest::Projection, point::Point2f0) = transform(source, dest, point)

const __TupTypes = Union{
                    Tuple{String, Any},
                    Tuple{String},
                    String
                }

function Proj4.Projection(args::Vector{<:__TupTypes})
    str = ""

    for arg in args
        if arg isa Tuple{String, T} where T <: Union{String, Real}
            opt, val = arg
            str *= " +$opt=$val"
        elseif arg isa Tuple{String} || arg isa Tuple{String, Nothing}
            opt = arg[1]
            str *= " +$opt"
        elseif arg isa String
            str *= " +$arg"
        end
    end

    return Projection(str)
end
