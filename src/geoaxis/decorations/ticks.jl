#=
# Tick values

The default finders walk a cartographic ladder and size the interval to the
pixel length of a carrier line (the middle visible parallel for longitudes,
the middle visible meridian for latitudes), so each direction gets the step
its room allows.  Values are exact ladder multiples over the visible extent;
labels print the value, never a number read off geometry.

Any Makie tick specification also works: a finder with `get_tickvalues`, a
vector or range, or a `(values, labels)` tuple.
=#

const GEOGRAPHIC_LADDER = [90.0, 45.0, 30.0, 15.0, 10.0, 5.0, 2.0, 1.0, 0.5, 0.25, 0.2, 0.1, 0.05, 0.02, 0.01, 0.005, 0.002, 0.001]
const GEOGRAPHIC_MINORS = Dict{Float64, Float64}(
    90 => 30, 45 => 15, 30 => 10, 15 => 5, 10 => 2, 5 => 1, 2 => 1, 1 => 0.5, 0.5 => 0.25, 0.25 => 0.05,
    0.2 => 0.1, 0.1 => 0.05, 0.05 => 0.01, 0.02 => 0.01, 0.01 => 0.005, 0.005 => 0.001, 0.002 => 0.001, 0.001 => 0.0005,
)
const ARCMINUTE_LADDER = vcat(GEOGRAPHIC_LADDER[1:8],
    [30, 15, 10, 5, 2, 1] ./ 60, [30, 15, 10, 5, 2, 1] ./ 3600)
const ARCMINUTE_MINORS = let d = Dict{Float64, Float64}(k => v for (k, v) in GEOGRAPHIC_MINORS if k >= 1)
    d[1.0] = 30 / 60
    for (maj, min) in ((30, 10), (15, 5), (10, 2), (5, 1), (2, 1), (1, 0.5))
        d[maj / 60] = min / 60
    end
    for (maj, min) in ((30, 10), (15, 5), (10, 2), (5, 1), (2, 1), (1, 0.5))
        d[maj / 3600] = min / 3600
    end
    d
end

"""
    GeographicTicks(; ladder, minors, target_em = 3.5, floor = 3)

The default tick finder of `GeoAxis`.  The major step is the first `ladder`
entry not finer than `target_em` ems of carrier length per label; if that
leaves fewer than `floor` lines the ladder is walked finer.  `minors` pairs a
minor step with each major step (consumed once minor grids are drawn).
"""
Base.@kwdef struct GeographicTicks
    ladder::Vector{Float64} = GEOGRAPHIC_LADDER
    minors::Dict{Float64, Float64} = GEOGRAPHIC_MINORS
    target_em::Float64 = 3.5
    floor::Int = 3
end

"""
    ArcMinuteTicks(; target_em = 3.5, floor = 3)

Like `GeographicTicks`, but below one degree the ladder runs in minutes and
seconds of arc (30′ 15′ 10′ 5′ 2′ 1′ 30″ …), and the automatic formatter
prints `10°30′E`.
"""
Base.@kwdef struct ArcMinuteTicks
    ladder::Vector{Float64} = ARCMINUTE_LADDER
    minors::Dict{Float64, Float64} = ARCMINUTE_MINORS
    target_em::Float64 = 3.5
    floor::Int = 3
end

const LadderTicks = Union{GeographicTicks, ArcMinuteTicks}
const MAX_LINES = 400                     # most lines a ladder finder emits in one direction

"""
    interval(f, span, carrier_px, fontsize) -> major step

`span` degrees are drawn along `carrier_px` pixels; a label wants
`f.target_em * fontsize` pixels.
"""
function interval(f::LadderTicks, span::Real, carrier_px::Real, fontsize::Real)
    ladder = f.ladder
    span = abs(float(span))
    span <= 0 && return ladder[1]
    target = carrier_px > 0 ? span * (f.target_em * fontsize) / carrier_px : Inf
    # the finest step that still gives every label its room (the ladder is descending)
    i = findlast(s -> s >= target - 1e-12, ladder)
    major = i === nothing ? ladder[1] : ladder[i]
    if span / major < f.floor - 1e-9
        j = findfirst(s -> span / s >= f.floor - 1e-9, ladder)
        j === nothing || (major = ladder[j])
    end
    # a runaway carrier (a degenerate or mis-measured line) must not flood the axis
    while span / major > MAX_LINES && major < ladder[1]
        k = findlast(s -> s > major, ladder)
        k === nothing && break
        major = ladder[k]
    end
    return major
end

"Exact multiples of `step` in `[lo, hi]`, snapped to clean decimals."
function ladder_multiples(step::Real, lo::Real, hi::Real)
    step = float(step)
    k0 = ceil(Int, lo / step - 1e-9)
    k1 = floor(Int, hi / step + 1e-9)
    return Float64[round(k * step; digits = 9) for k in k0:k1]
end

"Longitude in `(-180, 180]`."
wrap_longitude(v::Real) = (w = mod(float(v) + 180.0, 360.0) - 180.0; w == -180.0 ? 180.0 : w)

"""
    tickvalues(finder, (lo, hi), carrier_px, fontsize; wrap = false) -> (majors, minors)

Tick values over the extent `lo..hi` (degrees).  `wrap` reports longitudes in
`(-180, 180]`; a full turn (`hi - lo ≥ 360`) yields one value per meridian.
`minors` is `nothing` for finders without a paired minor step.
"""
function tickvalues(f::LadderTicks, ext::Tuple, carrier_px::Real, fontsize::Real; wrap::Bool = false)
    lo, hi = float(ext[1]), float(ext[2])
    span = hi - lo
    major = interval(f, span, carrier_px, fontsize)
    if span >= 360 - 1e-9
        majors = ladder_multiples(major, -180.0 + 1e-9, 180.0)
    else
        majors = ladder_multiples(major, lo, hi)
    end
    minor = get(f.minors, major, nothing)
    minors = minor === nothing ? Float64[] : setdiff(ladder_multiples(minor, lo, hi), majors)
    wrap && (majors = unique!(wrap_longitude.(majors)))
    wrap && (minors = unique!(wrap_longitude.(minors)))
    return (majors, minors)
end

function tickvalues(f, ext::Tuple, carrier_px::Real, fontsize::Real; wrap::Bool = false)
    lo, hi = float(ext[1]), float(ext[2])
    vals = Makie.get_tickvalues(f, identity, lo, hi)
    return (convert(Vector{Float64}, collect(vals)), nothing)
end

tickvalues(::Makie.Automatic, ext::Tuple, carrier_px::Real, fontsize::Real; kw...) =
    tickvalues(GeographicTicks(), ext, carrier_px, fontsize; kw...)

function tickvalues(v::AbstractVector, ext::Tuple, carrier_px::Real, fontsize::Real; wrap::Bool = false)
    return (convert(Vector{Float64}, collect(v)), nothing)
end

function tickvalues(tl::Tuple{<:AbstractVector, <:AbstractVector}, ext::Tuple, carrier_px::Real, fontsize::Real; wrap::Bool = false)
    length(tl[1]) == length(tl[2]) ||
        error("There are $(length(tl[1])) tick values but $(length(tl[2])) tick labels.")
    return (convert(Vector{Float64}, collect(tl[1])), nothing)
end

"Tick labels supplied with the values, or `nothing`."
ticklabels_of(::Any) = nothing
ticklabels_of(tl::Tuple{<:AbstractVector, <:AbstractVector}) = String[string(s) for s in tl[2]]

# Makie's own interface, so the finders also work on an `Axis` (no pixel
# information there: about eight lines per direction).
Makie.get_tickvalues(f::LadderTicks, vmin, vmax) = first(tickvalues(f, (vmin, vmax), 8 * f.target_em * 16, 16.0))

# ---- formatters --------------------------------------------------------------

"Print `v` as a short decimal: integers without a point, others with only the digits they need."
function short_decimal(v::Real)
    x = round(float(v); digits = 9)
    x == 0 && (x = 0.0)
    isinteger(x) && abs(x) < 1e15 && return string(round(Int, x))
    return string(x)
end

"The hemisphere letter for `x`, or `nothing` on the equator, the prime meridian and the antimeridian."
function _hemisphere(x::Real, neg::Char, pos::Char, turn::Bool)
    x == 0 && return nothing
    turn && abs(x) == 180 && return nothing
    return x < 0 ? neg : pos
end

function hemisphere_label(v::Real, neg::Char, pos::Char; turn::Bool = false)
    x = round(float(v); digits = 9)
    h = _hemisphere(x, neg, pos, turn)
    return string(short_decimal(abs(x)), '°', h === nothing ? "" : string(h))
end

"`110°W`, `45°N`, `0°`, `180°`."
longitude_format(vals) = String[hemisphere_label(v, 'W', 'E'; turn = true) for v in vals]
latitude_format(vals) = String[hemisphere_label(v, 'S', 'N') for v in vals]

function dms_label(v::Real, neg::Char, pos::Char; turn::Bool = false)
    x = float(v)
    h = _hemisphere(round(x; digits = 9), neg, pos, turn)
    # whole milliarcseconds, so 10 + 1/60 is 10°1′ and not 10°0′59.999″
    total = round(abs(x) * 3600; digits = 3)
    d = floor(Int, total / 3600 + 1e-9)
    rest = total - 3600d
    m = floor(Int, rest / 60 + 1e-9)
    s = round(rest - 60m; digits = 3)
    io = IOBuffer()
    print(io, d, '°')
    (m > 0 || s > 0) && print(io, m, '′')
    s > 0 && print(io, short_decimal(s), '″')
    h === nothing || print(io, h)
    return String(take!(io))
end

"`10°30′E`, `45°N`, `0°`."
longitude_dms_format(vals) = String[dms_label(v, 'W', 'E'; turn = true) for v in vals]
latitude_dms_format(vals) = String[dms_label(v, 'S', 'N') for v in vals]

"The formatter for an axis direction: the user's, or the finder's default."
function default_formatter(fmt, finder, family::Symbol)
    fmt isa Makie.Automatic || return fmt
    if finder isa ArcMinuteTicks
        return family === :lon ? longitude_dms_format : latitude_dms_format
    end
    return family === :lon ? longitude_format : latitude_format
end

"Label strings for `values`: the supplied labels, else the formatter applied to the values."
function format_tickvalues(fmt, finder, family::Symbol, values, supplied)
    supplied === nothing || return supplied
    f = default_formatter(fmt, finder, family)
    return String[string(s) for s in Makie.get_ticklabels(f, values)]
end
