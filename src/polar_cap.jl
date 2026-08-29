#=
# Polar cap

GMT's `MAP_POLAR_CAP` model.  Where a pole is an interior point of the map every
meridian converges on it, and a graticule drawn at the axis' interval turns into
an unreadable rosette in the last few degrees.  Inside the cap only a few
meridians are drawn, and a parallel at the cap latitude closes the rest.
=#

"""
Longitudes apart the meridians drawn inside a polar cap are, in degrees.  GMT's
default: enough to show where the pole is, few enough not to crowd it.
"""
const POLAR_CAP_MERIDIAN_INTERVAL = 90.0

"""Slack for matching a snapped tick value against a multiple: last bits only."""
const TICKVALUE_ATOL = 1.0e-9

"""
    polar_cap_meridian(lon, interval = POLAR_CAP_MERIDIAN_INTERVAL)

Whether the meridian at `lon` is one of those drawn right through a polar cap.
"""
polar_cap_meridian(lon, interval = POLAR_CAP_MERIDIAN_INTERVAL) =
    abs(rem(lon, interval, RoundNearest)) <= TICKVALUE_ATOL

"""
    polar_cap_range(ylims, poles, cap)

The latitude range an ordinary meridian is traced over: `ylims`, stopped at the
`cap` latitude on the side of each pole in `poles`.

A view lying wholly inside a cap keeps its meridians: there is nothing else there
to draw, and an empty graticule is worse than a crowded one.
"""
function polar_cap_range(ylims, poles, cap)
    isnothing(cap) && return (ylims[1], ylims[2])
    lo = -90.0 in poles ? max(ylims[1], -cap) : ylims[1]
    hi = 90.0 in poles ? min(ylims[2], cap) : ylims[2]
    return lo < hi ? (lo, hi) : (ylims[1], ylims[2])
end

"""
    polar_cap_parallels(ylims, poles, cap)

The latitudes of the small circles closing the caps of `poles`: the `cap`
latitude of each, where it falls inside `ylims`.
"""
function polar_cap_parallels(ylims, poles, cap)
    isnothing(cap) && return Float64[]
    return Float64[
        latitude for (pole, latitude) in ((-90.0, -cap), (90.0, cap))
            if pole in poles && ylims[1] < latitude < ylims[2]
    ]
end

"""
    interior_poles(trans, drawn, radius)

The poles the map closes around: drawn, with drawing all the way round them, so
that the meridians converge on a point in the middle of the map rather than
running out onto its edge.

[`outline_normal`](@ref) answers this already -- it reports no outline where the
drawing does not end -- so a pole on the limb of an azimuthal projection or at
the top of a pseudocylindrical one is not one of these.

The map is asked about on the graticule [`POLE_PROBE`](@ref) short of the pole,
which is a fraction of a pixel away from it and, unlike the pole itself, inverts
to a latitude that projects back.
"""
function interior_poles(trans, drawn, radius)
    poles = Float64[]
    for latitude in (-90.0, 90.0)
        probe = Point2d(Makie.apply_transform(
            trans, Point2d(0.0, latitude - sign(latitude) * POLE_PROBE)))
        (all(isfinite, probe) && drawn(probe)) || continue
        isfinite(outline_normal(drawn, probe, radius)) || push!(poles, latitude)
    end
    return poles
end
