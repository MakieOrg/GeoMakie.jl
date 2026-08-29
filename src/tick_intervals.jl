#=
# Tick intervals

The ladder a graticule's interval is chosen from, and the choice itself.  Nothing
here knows about an axis: the caller measures the spans and the room it has, and
gets an interval back.
=#

"""
Degrees in each unit the geographic ladder is built on: a degree, a minute, a
second.  An interval is a whole number of one of them and never a decimal
fraction of a degree, so that a tick label reads as a coordinate.
"""
const GEOGRAPHIC_UNITS = (1.0, 1 / 60, 1 / 3600)

"""
GMT's geographic ladder: the major intervals a graticule may take in each of
[`GEOGRAPHIC_UNITS`](@ref), each paired with the minor interval drawn inside it.

| major | 2 | 5 | 10 | 15 | 30 | 60 | 90 |
|:------|--:|--:|---:|---:|---:|---:|---:|
| minor | 1 | 1 |  2 |  5 | 10 | 15 | 30 |

The pairing is a table and not a division: fifteen degrees takes minors of five
and ten takes two, which no one divisor gives.
"""
const GEOGRAPHIC_LADDER = ((2, 1), (5, 1), (10, 2), (15, 5), (30, 10), (60, 15), (90, 30))

"""
[`GEOGRAPHIC_LADDER`](@ref) in degrees, ascending, as `(major, minor)` pairs.
"""
const GEOGRAPHIC_INTERVALS = sort!(
    [
        (major * unit, minor * unit)
            for unit in GEOGRAPHIC_UNITS for (major, minor) in GEOGRAPHIC_LADDER
    ]; by = first,
)

"""
    geographic_interval(target)

`target` degrees rounded up to [`GEOGRAPHIC_INTERVALS`](@ref) -- the first
interval on the ladder that reaches it -- as a `(; major, minor)` pair, also in
degrees.

A `target` past either end of the ladder gets the end it passed.  A nonfinite one
gets the coarse end: a broken layout then draws a graticule of a few lines rather
than one of a hundred thousand.
"""
function geographic_interval(target::Real)
    coarsest = GEOGRAPHIC_INTERVALS[end]
    isfinite(target) || return (; major = coarsest[1], minor = coarsest[2])
    index = findfirst(pair -> pair[1] >= target, GEOGRAPHIC_INTERVALS)
    major, minor = isnothing(index) ? coarsest : GEOGRAPHIC_INTERVALS[index]
    return (; major, minor)
end

"""
    geographic_interval_below(limit)

`limit` degrees rounded down to [`GEOGRAPHIC_INTERVALS`](@ref) -- the last
interval on the ladder that stays within it -- as a `(; major, minor)` pair.  A
`limit` under the whole ladder gets the finest interval there is.
"""
function geographic_interval_below(limit::Real)
    finest = GEOGRAPHIC_INTERVALS[1]
    isfinite(limit) || return (; major = finest[1], minor = finest[2])
    index = findlast(pair -> pair[1] <= limit, GEOGRAPHIC_INTERVALS)
    major, minor = isnothing(index) ? finest : GEOGRAPHIC_INTERVALS[index]
    return (; major, minor)
end

"""
Width of a longitude label as a multiple of the font size, with the gap that
separates two of them: `120ᵒW` is about two and a half em at the default font,
and one more em of air reads as a gap rather than as kerning.
"""
const TICKLABEL_WIDTH_EM = 3.5

"""
Height of a latitude label as a multiple of the font size, with its gap.  Latitude
labels stack up the side of the axis, so only their height crowds them.
"""
const TICKLABEL_HEIGHT_EM = 2.0

"""
    typographic_interval(span, available, label)

The interval that leaves exactly `label` pixels between neighbouring labels: the
`span` degrees on show, scaled by the label's share of the `available` pixels.

Returns `Inf` where there is no room to measure against, which asks
[`geographic_interval`](@ref) for the coarsest interval it has.
"""
function typographic_interval(span, available, label)
    all(isfinite, (span, available, label)) || return Inf
    available > 0 || return Inf
    return abs(span) * label / available
end

"""
The fewest lines a graticule is drawn with in either direction.

Equalizing on the coarser interval leaves the shorter direction too few, or none:
a polar view is a whole turn of longitude across fifty degrees of latitude, and
the turn asks for an interval the fifty degrees have no room to repeat.  Three
lines is the fewest that reads as a grid rather than as an accident.
"""
const MIN_GRATICULE_LINES = 3

"""
    graticule_interval(xspan, yspan, width, height, xfontsize, yfontsize)

The `(; major, minor)` interval in degrees for both directions of a graticule,
given its spans in degrees, the pixels it is drawn across, and the tick label
font sizes.

One interval serves both: a graticule reads as a grid only when its two spacings
agree, and the coarser of the two is the one that fits.  See
[`TICKLABEL_WIDTH_EM`](@ref) and [`TICKLABEL_HEIGHT_EM`](@ref) for the label size
the fit is measured against, and [`MIN_GRATICULE_LINES`](@ref) for the floor that
keeps the shorter direction drawn.
"""
function graticule_interval(xspan, yspan, width, height, xfontsize, yfontsize)
    fits = geographic_interval(max(
        typographic_interval(xspan, width, TICKLABEL_WIDTH_EM * xfontsize),
        typographic_interval(yspan, height, TICKLABEL_HEIGHT_EM * yfontsize),
    ))
    shortest = min(abs(xspan), abs(yspan))
    isfinite(shortest) || return fits
    keeps_lines = geographic_interval_below(shortest / MIN_GRATICULE_LINES)
    return fits.major <= keeps_lines.major ? fits : keeps_lines
end

"""
Slack, in multiples of the interval, when looking for the first tick in range.
`-122.6 / 0.1` is `-1225.9999999999998`, and a bare `ceil` of it skips the tick at
`-122.6` -- the left edge of the view, where a label is most wanted.
"""
const TICK_MULTIPLE_EPS = 1.0e-9

"""
    graticule_tickvalues(lo, hi, interval; fallback = Makie.WilkinsonTicks(5; k_min = 3))

Every multiple of `interval` between `lo` and `hi`, snapped by
[`snap_tickvalues`](@ref).

`fallback`, any Makie tick finder, takes over in two cases: an `interval` that
places fewer than two ticks in the view, and an `interval` of zero -- which is
how a view finer than [`LADDER_DEGREE_FLOOR`](@ref) is drawn.
"""
function graticule_tickvalues(lo, hi, interval; fallback = Makie.WilkinsonTicks(5; k_min = 3))
    (isfinite(lo) && isfinite(hi)) || return Float64[]
    lo, hi = min(lo, hi), max(lo, hi)
    values = Float64[]
    if isfinite(interval) && interval > 0
        quotient = lo / interval
        start = ceil(quotient - TICK_MULTIPLE_EPS * max(1.0, abs(quotient)))
        values = collect(Float64, (start * interval):interval:hi)
    end
    length(values) >= 2 && return snap_tickvalues(values)
    return snap_tickvalues(Makie.get_tickvalues(fallback, identity, lo, hi))
end

"""
The finest interval the axis takes from the ladder, in degrees.

Below a degree the ladder counts minutes and seconds, which
[`geoformat_ticklabels`](@ref) renders as the decimals they are made of --
`-122.56666666666666ᵒ`.  Until a formatter reads them as coordinates, a view
that fine is left to the fallback tick finder, whose decimal degrees the
formatter does render.
"""
const LADDER_DEGREE_FLOOR = 1.0

"""
    wrap_longitudes(values)

`values` brought back onto `[-180, 180]`, for labelling.

A graticule is traced on the turn the map was cut on, which need not be the one
its labels are read on: a full view of an orthographic centred on 60W is traced
from -420 to -60, and the meridian it starts at is 60W, not 420W.  Values already
in range are returned exactly, so that `180` stays `180` and does not become
`-180` on a map that shows both edges.
"""
wrap_longitudes(values) = [-180 <= v <= 180 ? v : mod(v + 180, 360) - 180 for v in values]

"""
Projections whose top parallel degenerates: the pole is a point on the map's own
edge, so the parallels approaching it shrink to nothing and a label on one has
nowhere to sit.  Matched on the `+proj=` name, which is what the axis can know
today; the redesign types this properly in a later stage.
"""
const POINT_POLE_PROJECTIONS = (
    "moll", "hammer", "aitoff", "wintri", "sinu", "hatano",
    "eck1", "eck2", "eck3", "eck4", "eck5", "eck6",
)

"""
The highest parallel drawn on a projection whose pole degenerates.  GMT's
choice: everything above it is crowded into the last few pixels of the map.
"""
const DEGENERATE_POLE_LATITUDE = 60.0

"""
    proj_name(crs)

The `+proj=` name of a CRS, or `""` where there is none to read.
"""
proj_name(crs) = ""
function proj_name(crs::AbstractString)
    matched = match(r"\+proj=([A-Za-z0-9_]+)", crs)
    return isnothing(matched) ? "" : String(matched[1])
end
proj_name(crs::_GFTCRS) = proj_name(gft2str(crs))

"""
    graticule_latitude_limit(dest)

The highest latitude a parallel is drawn at on the destination projection: 90
degrees, or [`DEGENERATE_POLE_LATITUDE`](@ref) for the
[`POINT_POLE_PROJECTIONS`](@ref).
"""
graticule_latitude_limit(dest) =
    proj_name(dest) in POINT_POLE_PROJECTIONS ? DEGENERATE_POLE_LATITUDE : 90.0

"""
    limit_graticule_latitudes(values, limit)

`values` without the parallels above `limit`.

The limit gives way where honouring it would leave a single parallel or none:
zoomed into the polar region there is nothing else to draw, and an unlabelled
axis is worse than a crowded one.
"""
function limit_graticule_latitudes(values, limit)
    kept = filter(v -> abs(v) <= limit, values)
    return length(kept) >= 2 ? kept : values
end
