# Pixel-space geometry used to place GeoAxis tick labels.
#
# These helpers deliberately do not depend on a GeoAxis.  The caller is responsible
# for projecting anchors, outward directions, and clipping tangents to pixel space
# before calling them.  Keeping this layer independent makes its geometry testable
# without constructing a Figure or selecting a rendering backend.

const _GEO_TICKLABEL_MODES = (:axis, :normal)
const _GEO_TICKLABEL_SIDES = (:bottom, :top, :left, :right)

function _geo_ticklabel_validate_symbol(value::Symbol, supported, name)
    value in supported || throw(ArgumentError(
        "unsupported $name $value; expected one of $(join(repr.(supported), ", "))"
    ))
    return value
end
_geo_ticklabel_mode(mode::Symbol) =
    _geo_ticklabel_validate_symbol(mode, _GEO_TICKLABEL_MODES, "tick-label placement mode")
_geo_ticklabel_mode(mode) = throw(ArgumentError(
    "tick-label placement mode must be a Symbol, got $(typeof(mode))"
))

_geo_ticklabel_side(side::Symbol) =
    _geo_ticklabel_validate_symbol(side, _GEO_TICKLABEL_SIDES, "GeoAxis side")
_geo_ticklabel_side(side) =
    throw(ArgumentError("GeoAxis side must be a Symbol, got $(typeof(side))"))

"""
    _geo_ticklabel_point(sample)

Return the pixel-space point represented by `sample`.  A sample may be a point-like
object or a record with a `projected` field, such as `SpinePoint`.
"""
function _geo_ticklabel_point(sample)
    value = hasproperty(sample, :projected) ? getproperty(sample, :projected) : sample
    length(value) == 2 || throw(ArgumentError("a tick-label point must have two coordinates"))
    return Point2d(value[1], value[2])
end

_geo_ticklabel_isfinite(value) = all(isfinite, value)

function _geo_ticklabel_unit(value; atol = sqrt(eps(Float64)))
    point = _geo_ticklabel_point(value)
    _geo_ticklabel_isfinite(point) || return nothing
    magnitude = norm(point)
    isfinite(magnitude) && magnitude > atol || return nothing
    return Point2d(point ./ magnitude)
end

"""
    _geo_ticklabel_axis_direction(side)

Return the outward, axis-constrained direction for a side.  Longitude labels on
`:bottom` and `:top` move vertically; latitude labels on `:left` and `:right` move
horizontally.
"""
function _geo_ticklabel_axis_direction(side)
    side = _geo_ticklabel_side(side)
    side === :bottom && return Point2d(0, -1)
    side === :top    && return Point2d(0, 1)
    side === :left   && return Point2d(-1, 0)
    return Point2d(1, 0)
end

function _geo_ticklabel_intersection_tangent(sample, supplied)
    value = if !isnothing(supplied)
        supplied
    elseif hasproperty(sample, :intersect_dir)
        getproperty(sample, :intersect_dir)
    else
        return nothing
    end
    return _geo_ticklabel_unit(value)
end

function _geo_ticklabel_distinct_neighbor(samples, index, step, anchor, atol)
    j = index + step
    while firstindex(samples) <= j <= lastindex(samples)
        candidate = _geo_ticklabel_point(samples[j])
        if _geo_ticklabel_isfinite(candidate) && norm(candidate - anchor) > atol
            return candidate
        end
        j += step
    end
    return nothing
end

"""
    _geo_ticklabel_boundary_tangent(samples, index; intersect_dir=nothing, atol=1e-6)

Estimate a unit boundary tangent at `samples[index]`.  A finite, nonzero
`intersect_dir` takes precedence because a clipping edge provides the best local
tangent.  Otherwise the tangent is a central secant through the nearest distinct
adjacent anchors, with a one-sided secant at either end.

`intersect_dir`, including one stored on the sample, must already be expressed in
pixel space.  The sign of the returned tangent is unspecified.
"""
function _geo_ticklabel_boundary_tangent(
        samples, index; intersect_dir = nothing, atol = 1e-6)
    checkbounds(samples, index)
    isfinite(atol) && atol >= 0 || throw(ArgumentError("atol must be finite and nonnegative"))

    sample = samples[index]
    tangent = _geo_ticklabel_intersection_tangent(sample, intersect_dir)
    !isnothing(tangent) && return tangent

    anchor = _geo_ticklabel_point(sample)
    _geo_ticklabel_isfinite(anchor) || return nothing
    before = _geo_ticklabel_distinct_neighbor(samples, index, -1, anchor, atol)
    after = _geo_ticklabel_distinct_neighbor(samples, index, 1, anchor, atol)

    if !isnothing(before) && !isnothing(after)
        tangent = _geo_ticklabel_unit(after - before; atol)
        !isnothing(tangent) && return tangent
    end
    !isnothing(after) && return _geo_ticklabel_unit(after - anchor; atol)
    !isnothing(before) && return _geo_ticklabel_unit(anchor - before; atol)
    return nothing
end

"""
    _geo_ticklabel_boundary_normal(samples, index, outward; kwargs...)

Rotate the sampled boundary tangent by 90 degrees and orient it toward `outward`,
the outward direction of the graticule at the endpoint.  Returns `nothing` when
the geometry is nonfinite, collapsed, or cannot determine which normal is outward.
"""
function _geo_ticklabel_boundary_normal(
        samples, index, outward; intersect_dir = nothing, atol = 1e-6)
    tangent = _geo_ticklabel_boundary_tangent(samples, index; intersect_dir, atol)
    isnothing(tangent) && return nothing
    outward_unit = _geo_ticklabel_unit(outward; atol)
    isnothing(outward_unit) && return nothing

    normal = Point2d(-tangent[2], tangent[1])
    orientation = dot(normal, outward_unit)
    isfinite(orientation) && abs(orientation) > atol || return nothing
    orientation < 0 && (normal = -normal)
    return (tangent = tangent, normal = normal)
end

function _geo_ticklabel_half_extents(half_extents)
    result = _geo_ticklabel_point(half_extents)
    _geo_ticklabel_isfinite(result) && all(x -> x >= 0, result) || throw(ArgumentError(
        "glyph half-extents must be finite and nonnegative"
    ))
    return result
end

function _geo_ticklabel_half_extents(width::Real, height::Real)
    isfinite(width) && isfinite(height) && width >= 0 && height >= 0 ||
        throw(ArgumentError("glyph width and height must be finite and nonnegative"))
    return Point2d(width / 2, height / 2)
end

function _geo_ticklabel_rotated_axes(rotation::Real)
    isfinite(rotation) || throw(ArgumentError("glyph rotation must be finite"))
    c, s = cos(rotation), sin(rotation)
    return (Point2d(c, s), Point2d(-s, c))
end

"""
    _geo_ticklabel_glyph_support(half_extents, direction; rotation=0)

Return the exact support distance of a rectangular glyph box in `direction`.
`half_extents` are the unrotated half-width and half-height, and `rotation` is in
radians.  Unlike projecting a rotated axis-aligned bounding box, this computes
support from the two actually rotated glyph axes.
"""
function _geo_ticklabel_glyph_support(half_extents, direction; rotation::Real = 0)
    half_extents = _geo_ticklabel_half_extents(half_extents)
    direction = _geo_ticklabel_unit(direction)
    isnothing(direction) && throw(ArgumentError("glyph support direction must be finite and nonzero"))
    xaxis, yaxis = _geo_ticklabel_rotated_axes(rotation)
    return abs(dot(direction, xaxis)) * half_extents[1] +
        abs(dot(direction, yaxis)) * half_extents[2]
end

_geo_ticklabel_glyph_support(width::Real, height::Real, direction; rotation::Real = 0) =
    _geo_ticklabel_glyph_support(
        _geo_ticklabel_half_extents(width, height), direction; rotation
    )

"""
    _geo_ticklabel_bbox(center, half_extents; rotation=0)

Return the pixel-space axis-aligned bounding box enclosing the rotated glyph box.
"""
function _geo_ticklabel_bbox(center, half_extents; rotation::Real = 0)
    center = _geo_ticklabel_point(center)
    _geo_ticklabel_isfinite(center) || throw(ArgumentError("glyph center must be finite"))
    half_extents = _geo_ticklabel_half_extents(half_extents)
    xaxis, yaxis = _geo_ticklabel_rotated_axes(rotation)
    aabb_half = Point2d(
        abs(xaxis[1]) * half_extents[1] + abs(yaxis[1]) * half_extents[2],
        abs(xaxis[2]) * half_extents[1] + abs(yaxis[2]) * half_extents[2],
    )
    return Rect2{Float64}(center - aabb_half, 2 .* aabb_half)
end

_geo_ticklabel_bbox(center, width::Real, height::Real; rotation::Real = 0) =
    _geo_ticklabel_bbox(center, _geo_ticklabel_half_extents(width, height); rotation)

"""Return whether two pixel-space bounding boxes overlap by more than `atol`."""
function _geo_ticklabel_bboxes_overlap(a, b; atol = 0.0)
    isfinite(atol) && atol >= 0 || throw(ArgumentError("atol must be finite and nonnegative"))
    amin, amax = extrema(a)
    bmin, bmax = extrema(b)
    return min(amax[1], bmax[1]) - max(amin[1], bmin[1]) > atol &&
        min(amax[2], bmax[2]) - max(amin[2], bmin[2]) > atol
end

"""Return the Euclidean pixel gap between two axis-aligned bounding boxes."""
function _geo_ticklabel_bbox_gap(a, b)
    amin, amax = extrema(a)
    bmin, bmax = extrema(b)
    dx = max(amin[1] - bmax[1], bmin[1] - amax[1], 0.0)
    dy = max(amin[2] - bmax[2], bmin[2] - amax[2], 0.0)
    return hypot(dx, dy)
end

"""
    _geo_ticklabel_clearance(center, endpoint, normal, half_extents; rotation=0)

Measure signed normal clearance in pixels between the graticule endpoint and the
nearest point of the rotated glyph box.  The requested padding is achieved when
this value equals `pad`.
"""
function _geo_ticklabel_clearance(
        center, endpoint, normal, half_extents; rotation::Real = 0)
    center = _geo_ticklabel_point(center)
    endpoint = _geo_ticklabel_point(endpoint)
    normal = _geo_ticklabel_unit(normal)
    isnothing(normal) && return NaN
    return dot(center - endpoint, normal) -
        _geo_ticklabel_glyph_support(half_extents, normal; rotation)
end

"""
    _geo_ticklabel_axis_drift(center, endpoint, side)

Measure unwanted tangential drift for axis-constrained placement.  It is horizontal
for top/bottom longitude labels and vertical for left/right latitude labels.
"""
function _geo_ticklabel_axis_drift(center, endpoint, side)
    center = _geo_ticklabel_point(center)
    endpoint = _geo_ticklabel_point(endpoint)
    direction = _geo_ticklabel_axis_direction(side)
    tangent = Point2d(-direction[2], direction[1])
    return abs(dot(center - endpoint, tangent))
end

"""Return clearance, axis drift, and center displacement for a placed glyph."""
function _geo_ticklabel_metrics(
        center, endpoint, normal, side, half_extents; rotation::Real = 0)
    return (
        clearance = _geo_ticklabel_clearance(
            center, endpoint, normal, half_extents; rotation
        ),
        drift = _geo_ticklabel_axis_drift(center, endpoint, side),
        displacement = norm(_geo_ticklabel_point(center) - _geo_ticklabel_point(endpoint)),
    )
end

"""Return whether two projected anchors collapse to the same pixel location."""
function _geo_ticklabel_anchors_collapsed(a, b; atol = 1.0)
    isfinite(atol) && atol >= 0 || throw(ArgumentError("atol must be finite and nonnegative"))
    a = _geo_ticklabel_point(a)
    b = _geo_ticklabel_point(b)
    _geo_ticklabel_isfinite(a) && _geo_ticklabel_isfinite(b) || return false
    return norm(a - b) <= atol
end

"""Return whether `samples[index]` coincides with another anchor in `samples`."""
function _geo_ticklabel_collapsed_anchor(samples, index; atol = 1.0)
    checkbounds(samples, index)
    return any(eachindex(samples)) do other
        other != index && _geo_ticklabel_anchors_collapsed(samples[index], samples[other]; atol)
    end
end

"""
    _geo_ticklabel_corner_anchor(anchor, orthogonal_anchors; atol=1)

Detect a sampled-boundary corner by matching an anchor from one axis against the
anchors selected for the orthogonal axis.  This also catches projection poles where
longitude and latitude boundary anchors converge without a rectangular viewport
corner.
"""
function _geo_ticklabel_corner_anchor(anchor, orthogonal_anchors; atol = 1.0)
    return any(other -> _geo_ticklabel_anchors_collapsed(anchor, other; atol),
        orthogonal_anchors)
end

"""
    _geo_ticklabel_placement(samples, index, outward, side, half_extents, pad;
        mode=:axis, rotation=0, intersect_dir=nothing,
        min_axis_dot=0.5, max_shift=40, atol=1e-6)

Compute a tick-label center from sampled boundary geometry in pixel space.

In `:normal` mode the center is displaced along the local boundary normal by
`pad + support`.  In `:axis` mode it is displaced along the outward vertical
(top/bottom) or horizontal (left/right) axis by
`(pad + support) / dot(normal, axis_direction)`.  This preserves exact normal
clearance without giving latitude labels vertical drift or longitude labels
horizontal drift.

The function returns a named tuple containing placement geometry and its glyph
bounding box.  It returns `nothing` for nonfinite or degenerate sampled geometry,
for an axis incidence below `min_axis_dot`, or for a center shift above
`max_shift`.  Configuration errors (unsupported symbols, nonfinite dimensions,
negative padding, or invalid thresholds) throw `ArgumentError`.
"""
function _geo_ticklabel_placement(
        samples, index, outward, side, half_extents, pad;
        mode = :axis,
        rotation::Real = 0,
        intersect_dir = nothing,
        min_axis_dot = 0.5,
        max_shift = 40.0,
        atol = 1e-6,
    )
    mode = _geo_ticklabel_mode(mode)
    side = _geo_ticklabel_side(side)
    half_extents = _geo_ticklabel_half_extents(half_extents)
    isfinite(pad) && pad >= 0 || throw(ArgumentError("tick-label pad must be finite and nonnegative"))
    isfinite(min_axis_dot) && 0 <= min_axis_dot <= 1 || throw(ArgumentError(
        "min_axis_dot must be finite and in [0, 1]"
    ))
    isfinite(max_shift) && max_shift >= 0 || throw(ArgumentError(
        "max_shift must be finite and nonnegative"
    ))

    checkbounds(samples, index)
    endpoint = _geo_ticklabel_point(samples[index])
    _geo_ticklabel_isfinite(endpoint) || return nothing
    frame = _geo_ticklabel_boundary_normal(
        samples, index, outward; intersect_dir, atol
    )
    isnothing(frame) && return nothing
    tangent, normal = frame
    axis_direction = _geo_ticklabel_axis_direction(side)
    axis_dot = dot(normal, axis_direction)
    support = _geo_ticklabel_glyph_support(half_extents, normal; rotation)

    direction, shift = if mode === :normal
        normal, pad + support
    else
        isfinite(axis_dot) && axis_dot >= min_axis_dot || return nothing
        axis_direction, (pad + support) / axis_dot
    end
    isfinite(shift) && shift <= max_shift || return nothing

    center = endpoint + direction * shift
    bbox = _geo_ticklabel_bbox(center, half_extents; rotation)
    return (
        center = center,
        endpoint = endpoint,
        tangent = tangent,
        normal = normal,
        direction = direction,
        shift = shift,
        support = support,
        clearance = _geo_ticklabel_clearance(
            center, endpoint, normal, half_extents; rotation
        ),
        drift = _geo_ticklabel_axis_drift(center, endpoint, side),
        axis_dot = axis_dot,
        bbox = bbox,
        mode = mode,
        side = side,
    )
end

function _geo_ticklabel_placement(
        samples, index, outward, side, width::Real, height::Real, pad; kwargs...)
    return _geo_ticklabel_placement(
        samples, index, outward, side,
        _geo_ticklabel_half_extents(width, height), pad; kwargs...
    )
end

"""Convenience overload using the sample's `dir` field as the outward direction."""
function _geo_ticklabel_placement(samples, index, side::Symbol, half_extents, pad; kwargs...)
    sample = samples[index]
    hasproperty(sample, :dir) || throw(ArgumentError(
        "sample has no `dir` field; pass an outward direction explicitly"
    ))
    return _geo_ticklabel_placement(
        samples, index, getproperty(sample, :dir), side, half_extents, pad; kwargs...
    )
end
