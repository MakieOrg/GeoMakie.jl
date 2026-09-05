#=
# Identifying a transformation

The boundary layer only needs to know a projection's `+proj` token and its
numeric parameters.  PROJ hands those back for anything it can express as a
PROJ string (EPSG / ESRI codes included, in degrees and metres); what it cannot
(EPSG:22700 and friends) goes to the probe.
=#

"""
    proj_string(t::Proj.Transformation) -> Union{String, Nothing}

The PROJ-5 string of the projected side of `t` (the target CRS, or the source
CRS when the target is lon/lat), `nothing` when PROJ cannot produce one.
"""
function proj_string(t::Proj.Transformation)
    s = _crs_proj_string(Proj.proj_get_target_crs(t.pj))
    if s === nothing || occursin(r"\+proj=(longlat|latlong|lonlat)\b", s)
        # lon/lat on the target side: the projected side is the source (if any)
        s2 = _crs_proj_string(Proj.proj_get_source_crs(t.pj))
        (s2 !== nothing && !occursin(r"\+proj=(longlat|latlong|lonlat)\b", s2)) && return s2
    end
    return s
end

function _crs_proj_string(crs::Ptr)
    crs == C_NULL && return nothing
    try
        return Proj.proj_as_proj_string(crs, Proj.PJ_PROJ_5)
    catch
        return nothing
    finally
        Proj.proj_destroy(crs)
    end
end

"""
    parse_proj_string(s) -> NamedTuple

Parse `+key=value` tokens: numeric values into `params`, and the fields the
boundary layer cares about (`method`, `o_proj`, `sphere`) directly.
"""
function parse_proj_string(s::AbstractString)
    params = Dict{Symbol, Float64}()
    method = :unknown
    o_proj = :none
    ellps = ""
    for tok in split(s)
        startswith(tok, "+") || continue
        kv = split(tok[2:end], "="; limit = 2)
        key = Symbol(kv[1])
        val = length(kv) == 2 ? kv[2] : "1"
        if key == :proj
            method = Symbol(val)
        elseif key == :o_proj
            o_proj = Symbol(val)
        elseif key == :ellps
            ellps = String(val)
        else
            x = tryparse(Float64, val)
            x === nothing || (params[key] = x)
        end
    end
    sphere = haskey(params, :R) || ellps == "sphere" ||
        (haskey(params, :a) && haskey(params, :b) && params[:a] == params[:b])
    return (; method, params, sphere, o_proj)
end

"""
    identify(t) -> Union{NamedTuple, Nothing}

`(; method::Symbol, params::Dict{Symbol,Float64}, sphere::Bool, o_proj::Symbol)`
for a `Proj.Transformation`, `nothing` for anything PROJ cannot describe (or a
non-PROJ transform), which then falls to the probe.
"""
function identify(t::Proj.Transformation)
    s = proj_string(t)
    s === nothing && return nothing
    id = parse_proj_string(s)
    id.method == :unknown && return nothing
    return id
end
identify(::Any) = nothing
