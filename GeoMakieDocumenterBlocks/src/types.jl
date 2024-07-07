abstract type Feature end

struct CopyPastableExample <: Feature end

abstract type Badge <: Feature end
struct JuliaFileBadge <: Badge end
struct DateBadge <: Badge end
struct AuthorBadge <: Badge end
struct LicenseBadge <: Badge 
    name::String
    link::String
end


@kwdef struct ExampleConfig <: Documenter.Plugin
    features::Vector{Feature} = Feature[CopyPastableExample()]
    known_examples::Vector = []
    gallery_dict::Dict = Dict{String, Any}()
end