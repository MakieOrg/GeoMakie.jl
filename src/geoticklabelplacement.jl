# Pixel-space geometry for GeoAxis tick labels.  Nothing here knows about a
# GeoAxis: the caller projects graticule endpoints to pixel space first.

const TICKLABEL_MODES = (:axis, :normal)
const TICKLABEL_SIDES = (:bottom, :top, :left, :right)

"""
Incidence angle, in radians, below which a graticule counts as tangent to the
boundary.  Below it the sign of the boundary normal is sampling noise.
"""
const TICKLABEL_TANGENCY = 0.2

"""
Two anchors within this fraction of the viewport diagonal are one anchor.  It is
relative rather than a pixel count so that it does not change as the axis
protrusion resizes the scene.
"""
const TICKLABEL_COLLAPSE = 3.0e-3

"""Validate a tick-label placement mode and return it unchanged."""
function ticklabel_mode(mode)
    mode isa Symbol && mode in TICKLABEL_MODES || throw(ArgumentError(
        "tick-label placement mode must be one of $(join(repr.(TICKLABEL_MODES), ", ")); got $(repr(mode))"
    ))
    return mode
end

"""Validate a GeoAxis side and return it unchanged."""
function ticklabel_side(side)
    side isa Symbol && side in TICKLABEL_SIDES || throw(ArgumentError(
        "GeoAxis side must be one of $(join(repr.(TICKLABEL_SIDES), ", ")); got $(repr(side))"
    ))
    return side
end

"""Return `v` as a unit `Vec2d`, or `nothing` when it is nonfinite or zero."""
function unit_direction(v)
    d = Vec2d(v[1], v[2])
    all(isfinite, d) || return nothing
    len = norm(d)
    (isfinite(len) && len > 0) || return nothing
    return d ./ len
end

"""
    axis_direction(side)

The outward, axis-constrained direction for `side`.  Longitude labels on
`:bottom` and `:top` move vertically; latitude labels on `:left` and `:right`
move horizontally.
"""
function axis_direction(side::Symbol)
    side === :bottom && return Vec2d(0, -1)
    side === :top && return Vec2d(0, 1)
    side === :left && return Vec2d(-1, 0)
    side === :right && return Vec2d(1, 0)
    ticklabel_side(side) # always throws
end

"""
    outward_frame(sample)

The unit pixel-space direction pointing out of the map at a graticule endpoint,
or `nothing` when the endpoint is not on a boundary.

`sample.intersect_dir` is the boundary direction there: a viewport edge where the
graticule was clipped, the orthogonal graticule where it was not.  Its normal is
the direction a label must clear.  `sample.dir` points from inside the map to the
endpoint and picks which of the two normals faces out.

Below [`TICKLABEL_TANGENCY`](@ref) that sign is noise, so the result rotates
smoothly onto `dir`, which is outward by construction.  Rotating rather than
switching keeps the result continuous in the sampled geometry, which the axis
protrusion depends on.  A boundary with no direction at all -- the pole of an
azimuthal projection, where every meridian ends on a parallel of zero length --
is not a boundary, and gets no label.
"""
function outward_frame(sample)
    edge = unit_direction(sample.intersect_dir)
    isnothing(edge) && return nothing
    normal = Vec2d(-edge[2], edge[1])
    dir = unit_direction(sample.dir)
    isnothing(dir) && return normal
    orientation = dot(normal, dir)
    oriented = orientation < 0 ? -normal : normal
    weight = clamp(abs(orientation) / sin(TICKLABEL_TANGENCY), 0, 1)
    isone(weight) && return oriented
    # `oriented` is within 90 degrees of `dir`, so the two never cancel.
    blended = unit_direction((1 - weight) .* dir .+ weight .* oriented)
    return isnothing(blended) ? dir : blended
end

"""The two unit axes of a glyph box rotated by `rotation` radians."""
function rotated_axes(rotation::Real)
    isfinite(rotation) || throw(ArgumentError("glyph rotation must be finite; got $rotation"))
    c, s = cos(rotation), sin(rotation)
    return (Vec2d(c, s), Vec2d(-s, c))
end

"""
    glyph_support(half_extents, direction; rotation = 0)

The support distance of a rotated glyph box along the unit vector `direction`:
how far the box reaches from its centre that way.
"""
function glyph_support(half_extents, direction; rotation::Real = 0)
    xaxis, yaxis = rotated_axes(rotation)
    return abs(dot(direction, xaxis)) * half_extents[1] +
        abs(dot(direction, yaxis)) * half_extents[2]
end

"""The pixel-space axis-aligned bounding box enclosing a rotated glyph box."""
function glyph_bbox(center, half_extents; rotation::Real = 0)
    xaxis, yaxis = rotated_axes(rotation)
    aabb = Vec2d(
        abs(xaxis[1]) * half_extents[1] + abs(yaxis[1]) * half_extents[2],
        abs(xaxis[2]) * half_extents[1] + abs(yaxis[2]) * half_extents[2],
    )
    return Rect2{Float64}(Vec2d(center[1], center[2]) - aabb, 2 .* aabb)
end

"""
    bbox_gap(a, b)

The Euclidean pixel gap between two axis-aligned bounding boxes.  Overlapping
boxes have a gap of zero, so a single `bbox_gap(a, b) < required` test rejects
both overlaps and boxes that merely crowd each other.
"""
function bbox_gap(a, b)
    amin, amax = extrema(a)
    bmin, bmax = extrema(b)
    dx = max(amin[1] - bmax[1], bmin[1] - amax[1], 0.0)
    dy = max(amin[2] - bmax[2], bmin[2] - amax[2], 0.0)
    return hypot(dx, dy)
end

"""Whether two projected anchors land within `atol` pixels of each other."""
function anchors_collapsed(a, b; atol)
    pa = Vec2d(a[1], a[2])
    pb = Vec2d(b[1], b[2])
    all(isfinite, pa) && all(isfinite, pb) || return false
    return norm(pa - pb) <= atol
end

"""
    corner_anchor(anchor, orthogonal_anchors, atol)

Whether `anchor` lands within `atol` of an anchor belonging to the orthogonal
axis.  True at rectangular viewport corners, and at projection poles where the
meridians all converge onto the parallel that ends there.
"""
corner_anchor(anchor, orthogonal_anchors, atol) =
    any(other -> anchors_collapsed(anchor, other; atol), orthogonal_anchors)

"""
    place_ticklabel(sample, side, half_extents, pad;
                    mode = :axis, rotation = 0, min_axis_dot = 0.5)

Place one tick label against the graticule endpoint `sample`, in pixel space.

Both modes leave exactly `pad` pixels between the glyph box and the endpoint.
`:normal` moves the label along the outward boundary normal.  `:axis` moves it
along the side's own axis instead, so that longitude labels get no horizontal
drift and latitude labels no vertical drift.

The axis-constrained shift diverges as the boundary turns parallel to the axis,
so below an incidence of `min_axis_dot` the direction rotates onto the normal,
reaching it at zero incidence.  The label degrades instead of disappearing, and
the shift stays continuous -- an anchor at the threshold would otherwise flip
between two shifts on floating-point noise, taking the axis protrusion with it.
The returned `mode` is `:axis` only where no rotation was needed.

Returns `nothing` for degenerate geometry, never for a configuration.  The
result is a named tuple of `center`, `anchor`, `normal`, `direction`, `shift`,
`support`, `bbox`, `mode`, and `side`.
"""
function place_ticklabel(
        sample, side::Symbol, half_extents, pad;
        mode::Symbol = :axis, rotation::Real = 0, min_axis_dot::Real = 0.5,
    )
    anchor = Point2d(sample.projected[1], sample.projected[2])
    all(isfinite, anchor) || return nothing
    normal = outward_frame(sample)
    isnothing(normal) && return nothing

    support = glyph_support(half_extents, normal; rotation)
    outward = axis_direction(side)
    axis_dot = dot(normal, outward)
    blend = mode === :axis ? clamp((min_axis_dot - axis_dot) / min_axis_dot, 0, 1) : 1.0
    direction = iszero(blend) ? outward :
        normalize((1 - blend) * outward + blend * normal)
    # Divide out the component along the normal to keep the clearance at `pad`.
    shift = (pad + support) / dot(normal, direction)
    placed = iszero(blend) ? :axis : :normal

    center = anchor + direction * shift
    return (
        center = center,
        anchor = anchor,
        normal = normal,
        direction = direction,
        shift = shift,
        support = support,
        bbox = glyph_bbox(center, half_extents; rotation),
        mode = placed,
        side = side,
    )
end

# Measuring a formatted tick label.  `Makie.text_bb` takes only `AbstractString`,
# but a formatter -- including Makie's automatic one, in scientific notation --
# can return `RichText` or `LaTeXString`, which `string` would measure wrongly.

const TICKLABEL_NO_COLOR = RGBAf(0, 0, 0, 0)
const TICKLABEL_NO_ROTATION = Quaternionf(0, 0, 0, 1)

function glyph_collection_extents(gc)
    n = length(gc.glyphs)
    return Makie.unchecked_boundingbox(
        gc.glyphs, gc.origins, Makie.collect_vector(gc.scales, n), gc.extents,
        TICKLABEL_NO_ROTATION,
    )
end

label_boundingbox(label::AbstractString, font, fontsize, fonts) =
    Makie.text_bb(label, font, fontsize)

function label_boundingbox(label::Makie.RichText, font, fontsize, fonts)
    gc = Makie.layout_text(
        label, fontsize, font, fonts, (:center, :center),
        TICKLABEL_NO_ROTATION, 0.0f0, 1.0f0, TICKLABEL_NO_COLOR,
    )
    return glyph_collection_extents(gc)
end

# Fraction bars and square-root rules are returned separately from the glyphs and
# are not measured here, so a label dominated by them measures slightly small.
function label_boundingbox(label::Makie.LaTeXString, font, fontsize, fonts)
    _, gc, _ = Makie.texelems_and_glyph_collection(
        label, fontsize, (:center, :center), TICKLABEL_NO_ROTATION,
        TICKLABEL_NO_COLOR, TICKLABEL_NO_COLOR, 0.0f0, -1,
    )
    return glyph_collection_extents(gc)
end

label_boundingbox(label, font, fontsize, fonts) =
    label_boundingbox(string(label), font, fontsize, fonts)

"""
    label_extents(label, font, fontsize, fonts)

Half-width and half-height of `label` in pixels, dispatching on the label type
the way the `Text` recipe's own `convert_text_string!` does.

The result is unrotated: passing a rotation here would give the rotated box's
axis-aligned bounds, and [`glyph_support`](@ref) needs the box itself.
"""
function label_extents(label, font, fontsize, fonts)
    extent = widths(label_boundingbox(label, font, fontsize, fonts))
    return Vec2d(extent[1] / 2, extent[2] / 2)
end
