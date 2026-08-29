#=
# Polar cap

GMT's `MAP_POLAR_CAP` model.  Where a pole is an interior point of the map every
meridian converges on it, and a graticule drawn at the axis' interval turns into
an unreadable rosette in the last few degrees.  Inside the cap only meridians at
a fixed interval are traced, and a parallel at the cap latitude closes the rest.
=#

"""
Longitudes apart the meridians drawn inside a polar cap are, in degrees.  GMT's
default: enough to show where the pole is, few enough not to crowd it.
"""
const POLAR_CAP_MERIDIAN_INTERVAL = 90.0

"""Poles the map does not close around: the answer for a disabled cap."""
const NO_INTERIOR_POLES = (south = false, north = false)

"""
    polar_cap_range(ylims, poles, cap)

The latitude range an ordinary meridian is traced over: `ylims`, stopped at the
`cap` latitude on the side of each pole set in `poles`.

A view lying wholly inside a cap keeps its meridians: there is nothing else there
to draw, and an empty graticule is worse than a crowded one.  A disabled cap is
expressed by `poles` having no pole set, so `cap` is only read where a pole is.
"""
function polar_cap_range(ylims, poles, cap)
    lo = poles.south ? max(ylims[1], -cap) : ylims[1]
    hi = poles.north ? min(ylims[2], cap) : ylims[2]
    return lo < hi ? (lo, hi) : (ylims[1], ylims[2])
end

"""
    polar_cap_parallels(ylims, poles, cap)

The latitudes of the small circles closing the caps of the poles set in `poles`:
the `cap` latitude of each, where it falls inside `ylims`.
"""
function polar_cap_parallels(ylims, poles, cap)
    parallels = Float64[]
    poles.south && ylims[1] < -cap < ylims[2] && push!(parallels, -cap)
    poles.north && ylims[1] < cap < ylims[2] && push!(parallels, cap)
    return parallels
end

"""
    polar_cap_segments(ylims, poles, cap)

The latitude ranges the meridians at multiples of
[`POLAR_CAP_MERIDIAN_INTERVAL`](@ref) are traced across: the part of `ylims` the
ordinary meridians give up to each cap.

Derived from [`polar_cap_range`](@ref) so the two never disagree -- a view lying
wholly inside a cap keeps its meridians there and yields no segments here, and
nothing is traced twice.
"""
function polar_cap_segments(ylims, poles, cap)
    ordinary = polar_cap_range(ylims, poles, cap)
    segments = Tuple{Float64,Float64}[]
    ordinary == (ylims[1], ylims[2]) && return segments
    ordinary[1] > ylims[1] && push!(segments, (ylims[1], ordinary[1]))
    ordinary[2] < ylims[2] && push!(segments, (ordinary[2], ylims[2]))
    return segments
end

"""
    pole_probe_point(reference, latitude)

The graticule point a pole is asked about at: on the `reference` meridian,
[`POLE_PROBE`](@ref) degrees short of the pole, which inverts to a latitude that
projects back where the pole itself does not.
"""
pole_probe_point(reference, latitude) = Point2d(reference, latitude - sign(latitude) * POLE_PROBE)

"""
    interior_poles(trans, drawn, radius, reference)

The poles the map closes around: drawn, with drawing all the way round them, so
that the meridians converge on a point in the middle of the map rather than
running out onto its edge.

[`outline_normal`](@ref) answers this already -- it reports no outline where the
drawing does not end -- so a pole on the limb of an azimuthal projection or at
the top of a pseudocylindrical one is not one of these.

The map is asked about at [`pole_probe_point`](@ref), a fraction of a pixel short
of the pole on the view's `reference` meridian: short of it because the pole
itself need not invert, and on that meridian so that an oblique view is asked
somewhere it can actually see.
"""
function interior_poles(trans, drawn, radius, reference)
    function interior(latitude)
        probe = Point2d(Makie.apply_transform(trans, pole_probe_point(reference, latitude)))
        (all(isfinite, probe) && drawn(probe)) || return false
        return !isfinite(outline_normal(drawn, probe, radius))
    end
    return (; south = interior(-90.0), north = interior(90.0))
end
