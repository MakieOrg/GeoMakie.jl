#=
# GeoAxis
=#

const Rect2d = Rect2{Float64}

Makie.@Block GeoAxis <: Makie.AbstractAxis begin
    scene::Scene
    targetlimits::Observable{Rect2d}
    finallimits::Observable{Rect2d}
    mouseeventhandle::Makie.MouseEventHandle
    scrollevents::Observable{Makie.ScrollEvent}
    keysevents::Observable{Makie.KeysEvent}
    interactions::Dict{Symbol, Tuple{Bool, Any}}
    elements::Dict{Symbol, Any}
    transform_func::Observable{Any}
    inv_transform_func::Observable{Any}
    @attributes begin
        # unused - only for compat with Makie AbstractAxis functions
        xscale = identity
        yscale = identity
        # Layout observables for Block
        "The horizontal alignment of the block in its suggested bounding box."
        halign = :center
        "The vertical alignment of the block in its suggested bounding box."
        valign = :center
        "The width setting of the block."
        width = Makie.Auto()
        "The height setting of the block."
        height = Makie.Auto()
        "Controls if the parent layout can adjust to this block's width"
        tellwidth::Bool = true
        "Controls if the parent layout can adjust to this block's height"
        tellheight::Bool = true
        "The align mode of the block in its parent GridLayout."
        alignmode = Makie.Inside()

        # Projection
        "Projection of the source data. This is the value plots will default to, but can be overwritten via `plot(...; source=...)`"
        source = "+proj=longlat +datum=WGS84"
        "Projection that the axis uses to display the data."
        dest = "+proj=eqearth"

        "Controls if the y axis goes upwards (false) or downwards (true)"
        yreversed::Bool = false
        "Controls if the x axis goes rightwards (false) or leftwards (true)"
        xreversed::Bool = false
        "The relative margins added to the autolimits in x direction."
        xautolimitmargin::Tuple{Float64,Float64} = (0.05f0, 0.05f0)
        "The relative margins added to the autolimits in y direction."
        yautolimitmargin::Tuple{Float64,Float64} = (0.05f0, 0.05f0)
        "The limits that the user has manually set. They are reinstated when calling `reset_limits!` and are set to nothing by `autolimits!`. Can be either a tuple (xlow, xhigh, ylow, high) or a tuple (nothing_or_xlims, nothing_or_ylims). Are set by `xlims!`, `ylims!` and `limits!`."
        limits = (nothing, nothing)
        "The forced aspect ratio of the axis. `nothing` leaves the axis unconstrained, `DataAspect()` forces the same ratio as the ratio in data limits between x and y axis, `AxisAspect(ratio)` sets a manual ratio."
        aspect = Makie.DataAspect()
        autolimitaspect = nothing

        # appearance controls
        "The set of fonts which text in the axis should use.s"
        fonts = (; regular = "TeX Gyre Heros Makie")
        "The axis title string."
        title = ""
        "The font family of the title."
        titlefont = :bold
        "The title's font size."
        titlesize::Float64 = @inherit(:fontsize, 16f0)
        "The gap between axis and title."
        titlegap::Float64 = 4f0
        "Controls if the title is visible."
        titlevisible::Bool = true
        "The horizontal alignment of the title."
        titlealign::Symbol = :center
        "The color of the title"
        titlecolor::RGBAf = @inherit(:textcolor, :black)
        "The axis title line height multiplier."
        titlelineheight::Float64 = 1
        "The axis subtitle string."
        subtitle = ""
        "The font family of the subtitle."
        subtitlefont = :regular
        "The subtitle's font size."
        subtitlesize::Float64 = @inherit(:fontsize, 16f0)
        "The gap between subtitle and title."
        subtitlegap::Float64 = 0
        "Controls if the subtitle is visible."
        subtitlevisible::Bool = true
        "The color of the subtitle"
        subtitlecolor::RGBAf = @inherit(:textcolor, :black)
        "The axis subtitle line height multiplier."
        subtitlelineheight::Float64 = 1


        "The xlabel string."
        xlabel = ""
        "The ylabel string."
        ylabel = ""
        "The font family of the xlabel."
        xlabelfont = :regular
        "The font family of the ylabel."
        ylabelfont = :regular
        "The color of the xlabel."
        xlabelcolor::RGBAf = @inherit(:textcolor, :black)
        "The color of the ylabel."
        ylabelcolor::RGBAf = @inherit(:textcolor, :black)
        "The font size of the xlabel."
        xlabelsize::Float64 = @inherit(:fontsize, 16f0)
        "The font size of the ylabel."
        ylabelsize::Float64 = @inherit(:fontsize, 16f0)
        "Controls if the xlabel is visible."
        xlabelvisible::Bool = true
        "Controls if the ylabel is visible."
        ylabelvisible::Bool = true
        "The padding between the xlabel and the ticks or axis."
        xlabelpadding::Float64 = 3f0
        "The padding between the ylabel and the ticks or axis."
        ylabelpadding::Float64 = 5f0 # xlabels usually have some more visual padding because of ascenders, which are larger than the hadvance gaps of ylabels
        "The xlabel rotation in radians."
        xlabelrotation = Makie.automatic
        "The ylabel rotation in radians."
        ylabelrotation = Makie.automatic

        "The x (longitude) ticks - can be a vector or a Makie tick finding algorithm."
        xticks = Makie.automatic
        "The y (latitude) ticks - can be a vector or a Makie tick finding algorithm."
        yticks = Makie.automatic

        "Format for x (longitude) ticks."
        xtickformat = Makie.automatic
        "Format for y (latitude) ticks."
        ytickformat = Makie.automatic
        "The font family of the xticklabels."
        xticklabelfont = :regular
        "The font family of the yticklabels."
        yticklabelfont = :regular
        "The color of xticklabels."
        xticklabelcolor::RGBAf = @inherit(:textcolor, :black)
        "The color of yticklabels."
        yticklabelcolor::RGBAf = @inherit(:textcolor, :black)
        "The font size of the xticklabels."
        xticklabelsize::Float64 = @inherit(:fontsize, 16f0)
        "The font size of the yticklabels."
        yticklabelsize::Float64 = @inherit(:fontsize, 16f0)
        "Controls if the xticklabels are visible."
        xticklabelsvisible::Bool = true
        "Controls if the yticklabels are visible."
        yticklabelsvisible::Bool = true
        "The space reserved for the xticklabels."
        xticklabelspace::Union{Makie.Automatic, Float64} = Makie.automatic
        "The space reserved for the yticklabels."
        yticklabelspace::Union{Makie.Automatic, Float64} = Makie.automatic
        "The space between xticks and xticklabels."
        xticklabelpad::Float64 = 5f0
        "The space between yticks and yticklabels."
        yticklabelpad::Float64 = 5f0
        "The counterclockwise rotation of the xticklabels in radians."
        xticklabelrotation::Float64 = 0f0
        "The counterclockwise rotation of the yticklabels in radians."
        yticklabelrotation::Float64 = 0f0
        "Placement direction for longitude tick labels. `:axis` moves labels vertically; `:normal` follows the projected boundary normal."
        xticklabelplacement::Symbol = :axis
        "Placement direction for latitude tick labels. `:axis` moves labels horizontally; `:normal` follows the projected boundary normal."
        yticklabelplacement::Symbol = :axis
        "The horizontal and vertical alignment of the xticklabels."
        xticklabelalign::Union{Makie.Automatic, Tuple{Symbol, Symbol}} = Makie.automatic
        "The horizontal and vertical alignment of the yticklabels."
        yticklabelalign::Union{Makie.Automatic, Tuple{Symbol, Symbol}} = Makie.automatic
        "The size of the xtick marks."
        xticksize::Float64 = 6f0
        "The size of the ytick marks."
        yticksize::Float64 = 6f0
        "Controls if the xtick marks are visible."
        xticksvisible::Bool = true
        "Controls if the ytick marks are visible."
        yticksvisible::Bool = true
        "The alignment of the xtick marks relative to the axis spine (0 = out, 1 = in)."
        xtickalign::Float64 = 0f0
        "The alignment of the ytick marks relative to the axis spine (0 = out, 1 = in)."
        ytickalign::Float64 = 0f0
        "The width of the xtick marks."
        xtickwidth::Float64 = 1f0
        "The width of the ytick marks."
        ytickwidth::Float64 = 1f0
        "The color of the xtick marks."
        xtickcolor::RGBAf = RGBf(0, 0, 0)
        "The color of the ytick marks."
        ytickcolor::RGBAf = RGBf(0, 0, 0)
        # "The width of the axis spines."
        # spinewidth::Float64 = 1f0
        "Controls if the x grid lines are visible."
        xgridvisible::Bool = true
        "Controls if the y grid lines are visible."
        ygridvisible::Bool = true
        "The width of the x grid lines."
        xgridwidth::Float64 = 1f0
        "The width of the y grid lines."
        ygridwidth::Float64 = 1f0
        "The color of the x grid lines."
        xgridcolor::RGBAf = RGBAf(0, 0, 0, 0.5)
        "The color of the y grid lines."
        ygridcolor::RGBAf = RGBAf(0.0, 0, 0, 0.5)
        "The linestyle of the x grid lines."
        xgridstyle = nothing
        "The linestyle of the y grid lines."
        ygridstyle = nothing
        "Controls if minor ticks on the x axis are visible"
        xminorticksvisible::Bool = false
        "The alignment of x minor ticks on the axis spine"
        xminortickalign::Float64 = 0f0
        "The tick size of x minor ticks"
        xminorticksize::Float64 = 4f0
        "The tick width of x minor ticks"
        xminortickwidth::Float64 = 1f0
        "The tick color of x minor ticks"
        xminortickcolor::RGBAf = :black
        "The tick locator for the x minor ticks"
        xminorticks = IntervalsBetween(2)
        "Controls if minor ticks on the y axis are visible"
        yminorticksvisible::Bool = false
        "The alignment of y minor ticks on the axis spine"
        yminortickalign::Float64 = 0f0
        "The tick size of y minor ticks"
        yminorticksize::Float64 = 4f0
        "The tick width of y minor ticks"
        yminortickwidth::Float64 = 1f0
        "The tick color of y minor ticks"
        yminortickcolor::RGBAf = :black
        "The tick locator for the y minor ticks"
        yminorticks = IntervalsBetween(2)
        "Controls if the x minor grid lines are visible."
        xminorgridvisible::Bool = false
        "Controls if the y minor grid lines are visible."
        yminorgridvisible::Bool = false
        "The width of the x minor grid lines."
        xminorgridwidth::Float64 = 1f0
        "The width of the y minor grid lines."
        yminorgridwidth::Float64 = 1f0
        "The color of the x minor grid lines."
        xminorgridcolor::RGBAf = RGBAf(0, 0, 0, 0.05)
        "The color of the y minor grid lines."
        yminorgridcolor::RGBAf = RGBAf(0, 0, 0, 0.05)
        "The linestyle of the x minor grid lines."
        xminorgridstyle = nothing
        "The linestyle of the y minor grid lines."
        yminorgridstyle = nothing
        # "Controls if the axis spine is visible."
        # spinevisible::Bool = true
        # "The color of the axis spine."
        # spinecolor::RGBAf = :black
        # spinetype::Symbol = :geospine
        "The button for panning."
        panbutton::Makie.Mouse.Button = Makie.Mouse.right
        "The key for limiting panning to the x direction."
        xpankey::Makie.Keyboard.Button = Makie.Keyboard.x
        "The key for limiting panning to the y direction."
        ypankey::Makie.Keyboard.Button = Makie.Keyboard.y
        "The key for limiting zooming to the x direction."
        xzoomkey::Makie.Keyboard.Button = Makie.Keyboard.x
        "The key for limiting zooming to the y direction."
        yzoomkey::Makie.Keyboard.Button = Makie.Keyboard.y

        "Locks interactive panning in the x direction."
        xpanlock::Bool = false
        "Locks interactive panning in the y direction."
        ypanlock::Bool = false
        "Locks interactive zooming in the x direction."
        xzoomlock::Bool = false
        "Locks interactive zooming in the y direction."
        yzoomlock::Bool = false
        "Controls if rectangle zooming affects the x dimension."
        xrectzoom::Bool = true
        "Controls if rectangle zooming affects the y dimension."
        yrectzoom::Bool = true

        xaxisposition::Symbol = :bottom
        yaxisposition::Symbol = :left

    end
end

# Makie generic object API
Makie.transform_func(ax::GeoAxis) = ax.transform_func[]

# Spines

const SpinePoint = NamedTuple{(:input, :projected, :dir, :intersect_dir),Tuple{Point2d,Point2d,Point2d,Point2d}}

struct Spines
    top::Vector{SpinePoint}
    bottom::Vector{SpinePoint}
    left::Vector{SpinePoint}
    right::Vector{SpinePoint}
end

Spines() = Spines(SpinePoint[], SpinePoint[], SpinePoint[], SpinePoint[])

"""
    clip_segment_to_rect(rect, line_start, line_end)

Clip a projected line segment to `rect` with the Liang--Barsky algorithm.  The
return value is `(start, stop, start_side, stop_side, t_start, t_stop)`, where
either side is `nothing` when the corresponding endpoint was already inside
the rectangle and the `t` values locate the endpoints on the original
segment.  Unlike testing endpoint membership, this also finds segments whose
two endpoints are outside but which pass through the rectangle.
"""
function clip_segment_to_rect(rect::Rect2, line_start::Point2, line_end::Point2)
    mini, maxi = extrema(rect)
    delta = line_end - line_start

    bottom = Line(Point2d(mini[1], mini[2]), Point2d(maxi[1], mini[2]))
    right = Line(Point2d(maxi[1], mini[2]), Point2d(maxi[1], maxi[2]))
    top = Line(Point2d(maxi[1], maxi[2]), Point2d(mini[1], maxi[2]))
    left = Line(Point2d(mini[1], maxi[2]), Point2d(mini[1], mini[2]))

    # Each `p * t <= q` constraint carries the rectangle side at equality.
    constraints = (
        (-delta[1], line_start[1] - mini[1], left),
        ( delta[1], maxi[1] - line_start[1], right),
        (-delta[2], line_start[2] - mini[2], bottom),
        ( delta[2], maxi[2] - line_start[2], top),
    )

    t_start, t_stop = 0.0, 1.0
    start_side = nothing
    stop_side = nothing
    for (p, q, side) in constraints
        if iszero(p)
            q < 0 && return nothing
            continue
        end

        t = q / p
        if p < 0 # entering the rectangle
            t > t_stop && return nothing
            if t > t_start
                t_start = t
                start_side = side
            end
        else # leaving the rectangle
            t < t_start && return nothing
            if t < t_stop
                t_stop = t
                stop_side = side
            end
        end
    end

    t_stop < t_start && return nothing
    # Preserve original in-bounds endpoints exactly.  Recomputing `a + 0d` or
    # `a + 1d` can differ by a few ulps, which would incorrectly split two
    # consecutive sampled segments into separate components.
    clipped_start = iszero(t_start) ? Point2d(line_start) : Point2d(line_start + t_start * delta)
    clipped_stop = isone(t_stop) ? Point2d(line_end) : Point2d(line_start + t_stop * delta)
    return clipped_start, clipped_stop, start_side, stop_side, t_start, t_stop
end

"""
    valid_line_in_limits(trans, trans_rev, rect, point_start, point_stop, n = 100)

Sample a source-space line, project it, and return every connected component
inside `rect`, as `(lines, lines_transformed, intersections, spans)`.

`lines` holds each component's source-space vertices, `lines_transformed` their
projected counterparts, `intersections` the rectangle edges its two ends were
clipped against (`nothing` for an end already inside), and `spans` its
`(first, last)` position along the sampled line, in `[0, 1]`.

The spans are the only ordering that survives the inverse projection, whose
source coordinates can wrap near an antimeridian.

Non-finite samples and discontinuities break the line into components, and each
segment is clipped separately so that a segment crossing the rectangle between
two outside endpoints is still drawn.
"""
function valid_line_in_limits(trans, trans_rev, rect, point_start, point_stop, n = 100)
    # Odd samples are the segment endpoints, even samples their midpoints, which
    # the continuity test below needs.  One pass projects both.
    m = 2n - 1
    xrange = LinRange(point_start[1], point_stop[1], m)
    yrange = LinRange(point_start[2], point_stop[2], m)
    sampled = [Point2d(xrange[i], yrange[i]) for i in 1:m]
    projected = [Point2d(Makie.apply_transform(trans, p)) for p in sampled]

    # Floor the sagitta test at a fraction of the viewport.  Purely relative, it
    # splits continuous geometry near a projection singularity, where curvature
    # outruns the chord; a real discontinuity jumps a visible distance.
    continuity_floor = 1.0e-3 * norm(widths(rect))

    lines = Vector{Point2d}[]
    lines_t = Vector{Point2d}[]
    intersections = Vector{Union{Line{2,Float64},Nothing}}[]
    spans = Tuple{Float64,Float64}[]

    current = 0
    for i in 1:2:(m - 2)
        a, b = sampled[i], sampled[i + 2]
        a_t, b_t = projected[i], projected[i + 2]
        if !(isfinite(a_t) && isfinite(b_t))
            current = 0
            continue
        end

        # PROJ's interrupted projections can jump between two finite
        # coordinates.  A midpoint transformed far from the chord's midpoint
        # identifies that without a projection-specific distance threshold.
        midpoint_t = projected[i + 1]
        chord = norm(b_t - a_t)
        sagitta = norm(midpoint_t - Point2d((a_t + b_t) ./ 2))
        if !isfinite(midpoint_t) || sagitta > 0.25 * max(chord, continuity_floor)
            current = 0
            continue
        end

        clipped = clip_segment_to_rect(rect, a_t, b_t)
        if isnothing(clipped)
            current = 0
            continue
        end
        clipped_start_t, clipped_stop_t, start_side, stop_side, t_start, t_stop = clipped
        # A tangent contact is a point, not a drawable connected component.
        clipped_start_t == clipped_stop_t && continue

        clipped_start = iszero(t_start) ? a : Point2d(Makie.apply_transform(trans_rev, clipped_start_t))
        clipped_stop = isone(t_stop) ? b : Point2d(Makie.apply_transform(trans_rev, clipped_stop_t))
        span_start = (i - 1 + 2t_start) / (m - 1)
        span_stop = (i - 1 + 2t_stop) / (m - 1)

        # Consecutive clipped segments share an exact transformed sample.
        # Otherwise an out-of-bounds gap separates two components.
        if current > 0 && lines_t[current][end] == clipped_start_t
            push!(lines[current], clipped_stop)
            push!(lines_t[current], clipped_stop_t)
            intersections[current][2] = stop_side
            spans[current] = (spans[current][1], span_stop)
        else
            push!(lines, Point2d[clipped_start, clipped_stop])
            push!(lines_t, Point2d[clipped_start_t, clipped_stop_t])
            push!(intersections, Union{Line{2,Float64},Nothing}[start_side, stop_side])
            push!(spans, (span_start, span_stop))
            current = length(lines)
        end
    end
    return lines, lines_t, intersections, spans
end

"""
    boundary_tangent(trans, point, dim; step = 0.01)

The projected direction of the map's own boundary at a graticule endpoint, in
degrees-based source coordinates.

Where the viewport did not cut the graticule off, the boundary is the graticule
of the *other* family through the same point: an extreme parallel closes off a
meridian, an extreme meridian closes off a parallel.  That is what a tick label
has to clear.  The graticule's own direction is not -- near a pole it swings
inward and would drag the label in with it.

The boundary of a projection whose limb is not a graticule, such as an oblique
orthographic, is only approximated this way.

Returns a zero or nonfinite direction where the boundary itself is degenerate,
as at a projection pole that is a single point.
"""
function boundary_tangent(trans, point, dim; step = 1.0e-2)
    # Stepping past +/-180 degrees of longitude wraps to the far side of the map,
    # which would measure the antimeridian instead of the boundary.
    limit = dim == 1 ? 180.0 : 90.0
    center = clamp(point[dim], -limit + step, limit - step)
    at(offset) = Makie.apply_transform(trans, Point2d(
        dim == 1 ? (center + offset, point[2]) : (point[1], center + offset)))
    low, high = at(-step), at(step)
    (isfinite(low) && isfinite(high)) || return Point2d(NaN)
    return Point2d(high .- low)
end

function add_to_lines!(result, trans, valid_line, line_transformed, intersections, coordinate, dim,
                       spine_start, spine_end)
    append!(result, line_transformed)
    push!(result, Point2d(NaN))

    # Restore the exact tick coordinate the graticule was traced at.  Inverting a
    # clipped endpoint through PROJ only recovers it to floating-point accuracy
    # -- latitude zero comes back as -8.39e-16 -- and a label reports that value.
    anchor_input(p) = dim == 1 ? Point2d(coordinate, p[2]) : Point2d(p[1], coordinate)
    # A clipped end lies on a viewport edge, which is the boundary there; an
    # unclipped one lies on the edge of the map itself.
    edge(line, p) = isnothing(line) ? boundary_tangent(trans, p, dim) :
        Point2d(line[1] .- line[2])
    i_start, i_end = intersections

    if !isnothing(spine_start)
        v1_t, v2_t = line_transformed[1], line_transformed[2]
        push!(spine_start, (
            input = anchor_input(valid_line[1]),
            projected = v1_t,
            dir = normalize(v1_t .- v2_t),
            intersect_dir = edge(i_start, valid_line[1]),
        ))
    end

    if !isnothing(spine_end)
        s1_t, s2_t = line_transformed[end], line_transformed[end - 1]
        push!(spine_end, (
            input = anchor_input(valid_line[end]),
            projected = s1_t,
            dir = normalize(s1_t .- s2_t),
            intersect_dir = edge(i_end, valid_line[end]),
        ))
    end
    return
end

"""
    source_extent(trans, trans_inverse, rect; n = 65)

The source-space extent of the projected view `rect`, as `(xlims, ylims)`, or
`nothing` when no sample of `rect` lies inside the projection.

Inverse-projecting the corners of `rect` is not enough, for two reasons.  A
corner can be outside the projection: the top corners of a full-world Robinson
view are past the ends of the pole line, which is 0.53 as wide as the equator,
and PROJ answers there with a finite coordinate that does not project back.  And
longitudes come back wrapped into `[-180, 180]`, so on a map whose central
meridian is not zero the two vertical edges of the view -- one map seam, reached
from either side -- inverse-project to nearly the same longitude.  Their bounding
box is then a sliver, and it is centred on the seam rather than on the map.  A
world map with `+lon_0=150` reports a longitude extent of about `(-176, 177)`
instead of `(-30, 330)`.

So samples are kept only when they project back onto themselves, which drops the
ones outside the projection, and longitudes are unwrapped along each row of
samples, which puts the seam at the ends of the extent where it belongs.  A view
that wraps right round is recognised separately and re-centred, since it has no
longitude extremes to find.

`n` is the sampling density per side.  The interior is sampled, not just the
boundary: the pole of a polar view is in the middle of it, and so is the highest
latitude the view reaches.
"""
function source_extent(trans, trans_inverse, rect; n = 65)
    mini, maxi = extrema(rect)
    span = maxi .- mini
    # A sample projects back onto itself to within rounding; one that is outside
    # the projection comes back a visible fraction of the view away, if at all.
    tol = 1.0e-6 * max(span[1], span[2])
    function inverse(p)
        q = Point2d(Makie.apply_transform(trans_inverse, p))
        all(isfinite, q) || return nothing
        back = Point2d(Makie.apply_transform(trans, q))
        (all(isfinite, back) && norm(back - p) <= tol) || return nothing
        return q
    end

    # Rows are unwrapped onto the same turn as the centre of the view.  A polar
    # projection crosses the branch cut at a different sample on every row, and
    # without a shared reference two rows can land a turn apart.
    center = inverse(Point2d((mini .+ maxi) ./ 2))
    reference = isnothing(center) ? 0.0 : center[1]

    # Which fifteen-degree slices of longitude the view lands in.  Rows of a
    # polar projection each cross the branch cut somewhere else, so this, and not
    # the unwrapped extremes, is what recognises a view that wraps right round.
    slices = falses(24)
    slice_width = 360.0 / length(slices)

    low = Point2d(Inf, Inf)
    high = Point2d(-Inf, -Inf)
    for j in 1:n
        y = mini[2] + span[2] * (j - 1) / (n - 1)
        # Unwrapping needs samples that are continuous in longitude, so the
        # offset restarts on every row and after every gap in one.
        longitudes = Float64[]
        previous = NaN
        offset = 0.0
        for i in 1:n
            q = inverse(Point2d(mini[1] + span[1] * (i - 1) / (n - 1), y))
            if isnothing(q)
                previous = NaN
                continue
            end
            # A step of more than half a turn between neighbouring samples is the
            # seam, not motion across the map.
            isfinite(previous) &&
                (offset -= 360.0 * round((q[1] + offset - previous) / 360.0))
            previous = q[1] + offset
            push!(longitudes, previous)
            slices[mod(floor(Int, q[1] / slice_width), length(slices)) + 1] = true
            low = Point2d(low[1], min(low[2], q[2]))
            high = Point2d(high[1], max(high[2], q[2]))
        end
        isempty(longitudes) && continue
        row_low, row_high = extrema(longitudes)
        shift = 360.0 * round((reference - (row_low + row_high) / 2) / 360.0)
        low = Point2d(min(low[1], row_low + shift), low[2])
        high = Point2d(max(high[1], row_high + shift), high[2])
    end
    (all(isfinite, low) && all(isfinite, high)) || return nothing

    # A view that wraps right round has no meaningful longitude extremes: every
    # row crosses the branch cut somewhere else, so their union lands on whatever
    # turn the unwrapping happened to pick.  A polar view reports -268 to 90,
    # which traces the same graticule as -180 to 180 but samples it from a
    # stranger place.  Re-centre on the middle of the view, keeping the width:
    # widening to a full turn would put both ends on the seam, where they are one
    # point and the graticule between them is a jump across the whole map.
    if all(slices)
        half = min(180.0, (high[1] - low[1]) / 2)
        low = Point2d(reference - half, low[2])
        high = Point2d(reference + half, high[2])
    elseif high[1] - low[1] > 360.0
        # Tracing more than one turn redraws the same graticule over itself.
        middle = (low[1] + high[1]) / 2
        low = Point2d(middle - 180.0, low[2])
        high = Point2d(middle + 180.0, high[2])
    end
    return ((low[1], high[1]), (low[2], high[2]))
end

function project_tick_points!(result, trans, trans_inverse, range, coordinate, dim, limit_rect,
                              spine_start, spine_end)
    # dim == 1 traces a meridian at constant longitude, dim == 2 a parallel.
    point_fun(tick) = dim === 1 ? Point2d(coordinate, tick) : Point2d(tick, coordinate)

    lines, lines_transformed, intersections, spans = valid_line_in_limits(
        trans, trans_inverse, limit_rect, point_fun(range[1]), point_fun(range[end]))
    valid_components = findall(i -> length(lines[i]) >= 2, eachindex(lines))
    isempty(valid_components) && return

    # A graticule may have several visible components.  Take its outer endpoints
    # from the earliest and latest ones, which the spans identify; a short first
    # component would otherwise donate both anchors.
    start_component = argmin(i -> spans[i][1], valid_components)
    end_component = argmax(i -> spans[i][2], valid_components)

    # A component that comes back to where it started has no endpoint on the map
    # boundary: every parallel of a polar projection is a circle in the middle of
    # the map, and anchoring a label where its trace happens to begin would draw
    # it over the data.  The traced range stops a little short of a full turn, so
    # the gap is measured against the component's own length rather than against
    # a fixed distance.  A clipped end is on the viewport edge and always counts.
    function has_endpoints(i)
        any(!isnothing, intersections[i]) && return true
        c = lines_transformed[i]
        arc = sum(j -> norm(c[j + 1] - c[j]), 1:(length(c) - 1); init = 0.0)
        return norm(c[end] - c[1]) >= 0.1 * arc
    end

    for i in valid_components
        ends = has_endpoints(i)
        add_to_lines!(
            result, trans, lines[i], lines_transformed[i], intersections[i], coordinate, dim,
            ends && i == start_component ? spine_start : nothing,
            ends && i == end_component ? spine_end : nothing,
        )
    end
    return
end

"""
    is_high_side(sample, component, middle)

Whether a projected graticule endpoint belongs to the high side of `component`:
`:right` for component 1, `:top` for component 2.

The outward direction decides, which survives longitude wrapping, oblique poles,
and reversed axes.  Where that component is too small to trust, the anchor's
position relative to the viewport centre `middle` decides instead.  Every anchor
is classified; one dropped here is a tick label lost.
"""
function is_high_side(sample, component, middle)
    outward = outward_frame(sample)
    if !isnothing(outward) && abs(outward[component]) > sin(TICKLABEL_TANGENCY)
        return outward[component] > 0
    end
    return sample.projected[component] >= middle[component]
end

"""Format `values` with a user formatter, or with GeoMakie's degree formatter."""
function ticklabel_strings(formatter, values)
    formatter isa Makie.Automatic && return geoformat_ticklabels(values)
    labels = Makie.get_ticklabels(formatter, values)
    length(labels) == length(values) || throw(ArgumentError(
        "tick formatter returned $(length(labels)) labels for $(length(values)) tick values"))
    return labels
end

"""
    ticklabel_candidates(samples, tickvalues, labels, dim, side, font, fontsize, fonts,
                         pad, rotation, mode; corner_anchors, occupied, collision_gap)

Place one side's tick labels and drop the ones that collide.

`samples` are that side's projected endpoints, each carrying its exact tick value
in component `dim`, which indexes into `tickvalues`/`labels`.  Those cover the
whole tick vector rather than the visible subset, so that a user formatter sees
the same input however many graticules are on screen.

Returns `(positions, labels, placements, protrusion)`, the first three ordered by
tick value.
"""
function ticklabel_candidates(
        samples, tickvalues, labels, dim, side, font, fontsize, fonts, pad, rotation, mode;
        corner_anchors = Point2d[], corner_atol = 0.0, occupied = Rect2{Float64}[],
        collision_gap = 2.0,
    )
    isempty(samples) && return (Point2d[], Any[], NamedTuple[], 0.0f0)

    # Resolve collisions from the centre of the side outward, measured where the
    # labels are drawn: the central label is the one worth keeping when anchors
    # crowd at a projection pole, and the order graticules were traced in stops
    # mattering.  The midpoint of the projected extent, not the median, which
    # drifts toward wherever anchors bunch up.
    tangential = side in (:bottom, :top) ? 1 : 2
    low, high = extrema(p.projected[tangential] for p in samples)
    middle = (low + high) / 2
    priority = sortperm(eachindex(samples);
        by = i -> abs(samples[i].projected[tangential] - middle))

    placements = NamedTuple[]
    placement_labels = Any[]
    placement_values = Float64[]
    corner_fallback = nothing
    for i in priority
        sample = samples[i]
        isfinite(sample.input) || continue
        tick = findfirst(==(sample.input[dim]), tickvalues)
        isnothing(tick) && continue

        label = labels[tick]
        placement = place_ticklabel(
            sample, side, label_extents(label, font, fontsize, fonts), pad; mode, rotation)
        isnothing(placement) && continue

        if corner_anchor(sample.projected, corner_anchors, corner_atol)
            # Anchors shared with the orthogonal axis are suppressed.  Dropping
            # both is right at a rectangular corner, but every meridian of an
            # elliptical projection ends at a pole, so keep the central one
            # rather than leaving the axis unlabelled.
            isnothing(corner_fallback) &&
                (corner_fallback = (placement, label, sample.input[dim]))
            continue
        end

        push!(placements, placement)
        push!(placement_labels, label)
        push!(placement_values, sample.input[dim])
    end
    if isempty(placements) && !isnothing(corner_fallback)
        push!(placements, corner_fallback[1])
        push!(placement_labels, corner_fallback[2])
        push!(placement_values, corner_fallback[3])
    end
    # Reserve space for every candidate, not only the ones surviving the filter
    # below.  Which labels collide depends on the size of the scene, and this
    # number decides that size; feeding the filtered set back would let the
    # layout chase one label in and out of the frame forever.
    protrusion = ticklabel_protrusion(placements, side)

    accepted = Int[]
    boxes = copy(occupied)
    for (i, placement) in enumerate(placements)
        any(box -> bbox_gap(placement.bbox, box) < collision_gap, boxes) && continue
        push!(accepted, i)
        push!(boxes, placement.bbox)
    end

    order = accepted[sortperm(placement_values[accepted])]
    return (
        Point2d[placements[i].center for i in order],
        Any[placement_labels[i] for i in order],
        NamedTuple[placements[i] for i in order],
        protrusion,
    )
end

"""
    ticklabel_protrusion(placements, side)

How far the labels of `side` reach beyond their graticule endpoints, along that
side's outward axis.

Measured from the anchors rather than from the viewport, so that the layout loop
`labels -> viewport -> protrusion -> labels` gains no coupling.  An anchor inside
the viewport therefore over-reserves, which is the safe direction.

Rounded up to whole pixels: reserving space moves the anchors by a fraction of a
pixel and this reach with them, and without a quantum the layout can chase a
two-cycle instead of settling.
"""
function ticklabel_protrusion(placements, side)
    isempty(placements) && return 0.0f0
    outward = axis_direction(side)
    component = side in (:bottom, :top) ? 2 : 1
    reach = maximum(placements) do p
        dot(p.center - p.anchor, outward) + widths(p.bbox)[component] / 2
    end
    return Float32(max(0.0, ceil(reach)))
end

function Makie.initialize_block!(axis::GeoAxis)

    ticklabel_mode(axis.xticklabelplacement[])
    ticklabel_mode(axis.yticklabelplacement[])

    # Set up transformations first, so that the scene can be set up
    # and linked to those.
    transform_obs = Observable{Any}(identity; ignore_equal_values=true)
    transform_inv_obs = Observable{Any}(identity; ignore_equal_values=true)
    transform_ticks_obs = Observable{Any}(identity; ignore_equal_values=true)
    transform_ticks_inv_obs = Observable{Any}(identity; ignore_equal_values=true)
    setfield!(axis, :transform_func, transform_obs)
    setfield!(axis, :inv_transform_func, transform_inv_obs)

    # Set up the axis for the Scene, mostly using Makie's existing functionality
    scene = axis_setup!(axis)

    # Shorthand for what you see below - ONLY ACCESSIBLE WITHIN THIS FUNCTION!!
    Obs(x) = Observable(x; ignore_equal_values=true)

    # Keep the transformations up to date.
    onany(scene, axis.dest, axis.source; update=true) do tp, sp
        # First we perform the transformation for the axis,
        trans = create_transform(tp, sp)
        transform_obs[] = trans
        transform_inv_obs[] = Makie.inverse_transform(trans)
        # and next for the ticks - this assumes an input CRS in
        # PROJ-string format, which is not necessarily the case, but suffices for now.
        # What this should do, is check using Proj whether the input CRS is equivalent
        # to EPSG 4326, which is actually quite doable - especially using a cache of some kind.
        # What this is actually doing, is creating a transformation that takes the input CRS
        # and transforms it to the WGS84 CRS, which is how we display the ticks.
        # If you wanted ticks in the input CRS, you'd have to wait until a generic `NonlinearAxis`
        # is implemented, which would then not have any special treatment for geographic stuff.
        if sp == "+proj=longlat +datum=WGS84" || sp == "+proj=latlong +datum=WGS84 +type=crs" || sp == GeoFormatTypes.EPSG(4326)
            transform_ticks_obs[] = trans
            transform_ticks_inv_obs[] = transform_inv_obs[]
        else
            transform_ticks_obs[] = create_transform(tp, "+proj=longlat +datum=WGS84")
            transform_ticks_inv_obs[] = create_transform("+proj=longlat +datum=WGS84", tp)
        end
    end


    lonticks_line_obs = Obs(Point2d[])
    latticks_line_obs = Obs(Point2d[])

    # The complete tick vectors behind the graticules, so that a user formatter
    # sees all of them and not just the ones reaching a boundary.  Read
    # non-reactively below: anything changing them also notifies `spines_obs`.
    xtickvalues_obs = Observable(Float64[])
    ytickvalues_obs = Observable(Float64[])

    spines_obs = Obs(Spines())
    finallimits = map(identity, scene, axis.finallimits; ignore_equal_values=true)
    vp_unchanged = map(identity, scene, scene.viewport; ignore_equal_values=true)
    # This is kind of the main redrawing loop for the axis.  This should really be
    # factored out into a sync and async function, so that zooming is fluid, but
    # we can figure that out later.
    # What this does is first calculate limits and ticks, then create spines and
    # project them.  Those are stored in Observables which are used to produce
    # lineplots later on that form the grid.
    # TODO: implement a minor grid.
    onany(scene, axis.xticks, axis.yticks,
        transform_ticks_obs, finallimits, vp_unchanged;
        update=true) do user_xticks, user_yticks, trans, fl, vp

        lon_transformed = Point2d[]
        lat_transformed = Point2d[]
        limit_rect = Makie.to_value(axis.finallimits)
        trans_inverse = Makie.to_value(transform_ticks_inv_obs)

        # Fall back to the inverse-projected bounding box only where nothing of
        # the view is inside the projection and there is nothing to trace anyway.
        extent = source_extent(trans, trans_inverse, limit_rect)
        if isnothing(extent)
            limits_t = Makie.apply_transform(trans_inverse, limit_rect)
            extent = (Makie.xlimits(limits_t), Makie.ylimits(limits_t))
        end
        xlims, ylims = extent

        xtickvalues = collect(Float64,
            user_xticks isa Makie.Automatic ? geoticks(-180, 180, xlims...) :
                Makie.get_tickvalues(user_xticks, xlims...))
        ytickvalues = collect(Float64,
            user_yticks isa Makie.Automatic ? geoticks(-90, 90, ylims...) :
                Makie.get_tickvalues(user_yticks, ylims...))

        spines = spines_obs[]
        foreach(empty!, (spines.left, spines.right, spines.bottom, spines.top))
        # Tick values select graticules; they must not also truncate them.  Trace
        # each one across the whole inverse-transformed view and let
        # `valid_line_in_limits` clip it in projected space.
        for lon in xtickvalues
            project_tick_points!(lon_transformed, trans, trans_inverse, ylims, lon, 1, limit_rect,
                                 spines.bottom, spines.top)
        end
        for lat in ytickvalues
            project_tick_points!(lat_transformed, trans, trans_inverse, xlims, lat, 2, limit_rect,
                                 spines.left, spines.right)
        end

        lonticks_line_obs[] = lon_transformed
        latticks_line_obs[] = lat_transformed
        xtickvalues_obs[] = xtickvalues
        ytickvalues_obs[] = ytickvalues
        notify(spines_obs)
        return
    end
    # These are the grid plots from earlier.
    longridplot = lines!(scene, lonticks_line_obs; color=axis.xgridcolor, linewidth=axis.xgridwidth,
        visible=axis.xgridvisible, linestyle=axis.xgridstyle, transparency=true, inspectable=false)
    translate!(longridplot, 0, 0, 100)
    latgridplot = lines!(scene, latticks_line_obs; color=axis.ygridcolor, linewidth=axis.ygridwidth,
        visible=axis.ygridvisible, linestyle=axis.ygridstyle, transparency=true, inspectable=false)
    translate!(latgridplot, 0, 0, 100)

    # Project boundary anchors and their directions into pixel space, where
    # glyph dimensions and padding have a stable meaning.
    cam = scene.camera
    pixel_spines = Obs(Spines())
    onany(scene, spines_obs, cam.projectionview, vp_unchanged) do spines, pv, area
        poffset = minimum(area)
        project_px(p) = to_ndim(Point2d, Makie.project(cam, :data, :pixel, p), 0.0f0) .+ poffset
        function project_vector(anchor, vector)
            isfinite(vector) || return Point2d(NaN)
            return project_px(anchor + vector) - project_px(anchor)
        end
        function project_p(p)
            return (
                input = p.input,
                projected = project_px(p.projected),
                dir = project_vector(p.projected, p.dir),
                intersect_dir = project_vector(p.projected, p.intersect_dir),
            )
        end

        # Source-space low/high naming does not survive projection: wrapping, an
        # oblique pole, or a reversed axis can put the low endpoint on the
        # visually high side.  Reclassify and sort in pixel space, which also
        # makes "along the side" mean the same here and in
        # `ticklabel_candidates`.
        middle = Point2d(minimum(area) .+ widths(area) ./ 2)
        function split_sides(anchors, component)
            low, high = SpinePoint[], SpinePoint[]
            for p in anchors
                push!(is_high_side(p, component, middle) ? high : low, p)
            end
            tangential = component == 1 ? 2 : 1
            by = p -> p.projected[tangential]
            return sort!(low; by), sort!(high; by)
        end

        left, right = split_sides(
            vcat(project_p.(spines.left), project_p.(spines.right)), 1)
        bottom, top = split_sides(
            vcat(project_p.(spines.bottom), project_p.(spines.top)), 2)
        pixel_spines[] = Spines(top, bottom, left, right)
        return
    end

    xticklabelplot = text!(axis.blockscene, Point2d[];
        text=Any[], space=:pixel, align=(:center, :center),
        rotation=axis.xticklabelrotation,
        font=axis.xticklabelfont, color=axis.xticklabelcolor,
        fontsize=axis.xticklabelsize, visible=axis.xticklabelsvisible,
    )

    yticklabelplot = text!(axis.blockscene, Point2d[];
        text=Any[], space=:pixel, align=(:center, :center),
        rotation=axis.yticklabelrotation,
        font=axis.yticklabelfont, color=axis.yticklabelcolor,
        fontsize=axis.yticklabelsize, visible=axis.yticklabelsvisible,
    )

    fonts = theme(axis.blockscene, :fonts)
    # Protrusions come from the placements below, so that the space reserved is
    # the space the labels need.  Reserving it resizes the scene, which moves the
    # labels, which changes what they need; `reserved` only ever grows within a
    # layout pass so that loop terminates.  See `ticklabel_protrusion`.
    x_protrusion = Obs(0.0f0)
    y_protrusion = Obs(0.0f0)
    reserved = Ref((0.0f0, 0.0f0))
    reserved_for = Ref{Any}(nothing)
    onany(
        scene, pixel_spines, axis.xaxisposition, axis.yaxisposition,
        axis.xtickformat, axis.ytickformat,
        axis.xticklabelfont, axis.yticklabelfont,
        axis.xticklabelsize, axis.yticklabelsize,
        axis.xticklabelpad, axis.yticklabelpad,
        axis.xticklabelrotation, axis.yticklabelrotation,
        axis.xticklabelplacement, axis.yticklabelplacement,
        axis.xticklabelsvisible, axis.yticklabelsvisible,
    ) do spines, xside, yside, xformat, yformat, xfont, yfont,
            xsize, ysize, xpad, ypad, xrotation, yrotation, xmode, ymode,
            xvisible, yvisible
        xside in (:bottom, :top) || throw(ArgumentError(
            "xaxisposition must be :bottom or :top, got $xside"))
        yside in (:left, :right) || throw(ArgumentError(
            "yaxisposition must be :left or :right, got $yside"))
        ticklabel_mode(xmode)
        ticklabel_mode(ymode)

        xvalues, yvalues = xtickvalues_obs[], ytickvalues_obs[]
        # Suppress anchors shared by a meridian and a parallel, on both axes:
        # otherwise whichever axis is resolved first keeps its label.
        xcorners = Point2d[p.projected for p in vcat(spines.left, spines.right)]
        ycorners = Point2d[p.projected for p in vcat(spines.bottom, spines.top)]
        corner_atol = TICKLABEL_COLLAPSE * norm(widths(scene.viewport[]))

        xpositions, xlabels, xplacements, xreach = ticklabel_candidates(
            getproperty(spines, xside), xvalues, ticklabel_strings(xformat, xvalues),
            1, xside, Makie.to_font(fonts, xfont), xsize, fonts, xpad, xrotation, xmode;
            corner_anchors = xcorners, corner_atol,
        )
        ypositions, ylabels, yplacements, yreach = ticklabel_candidates(
            getproperty(spines, yside), yvalues, ticklabel_strings(yformat, yvalues),
            2, yside, Makie.to_font(fonts, yfont), ysize, fonts, ypad, yrotation, ymode;
            corner_anchors = ycorners, corner_atol,
            # Hidden longitude labels occupy no space, so they must not evict
            # latitude labels either.
            occupied = xvisible ? Rect2d[p.bbox for p in xplacements] : Rect2d[],
        )

        # Keep positions and text lengths synchronized through Makie's compute
        # graph when ticks or limits change interactively.
        Makie.update!(xticklabelplot; arg1=xpositions, text=xlabels)
        Makie.update!(yticklabelplot; arg1=ypositions, text=ylabels)
        # Never reserve so much that the axis itself disappears.  The suggested
        # box already has the current reservation taken out of it, so add that
        # back: a cap that shrank as we reserved would be part of the loop.
        room = widths(axis.layoutobservables.suggestedbbox[])
        outer = (room[1] + 2 * y_protrusion[], room[2] + 2 * x_protrusion[])
        cap = (0.35f0 * outer[2], 0.35f0 * outer[1])
        request = (
            xvisible ? min(xreach, cap[1]) : 0.0f0,
            yvisible ? min(yreach, cap[2]) : 0.0f0,
        )
        # Everything the labels depend on except the layout itself.  While it
        # holds still only growth propagates, which is what converges; when it
        # changes the reservation starts over.  The cap is applied either way, so
        # that shrinking the figure gives the space back.
        settling = (
            xvalues, yvalues, xside, yside, xformat, yformat, xfont, yfont,
            xsize, ysize, xpad, ypad, xrotation, yrotation, xmode, ymode,
            xvisible, yvisible, axis.finallimits[],
        )
        if !isequal(reserved_for[], settling)
            reserved_for[] = settling
            reserved[] = request
        else
            reserved[] = min.(max.(reserved[], request), cap)
        end
        x_protrusion[] = reserved[][1]
        y_protrusion[] = reserved[][2]
        return
    end

    elements = Dict{Symbol,Any}()
    setfield!(axis, :elements, elements)
    elements[:xgrid] = longridplot
    elements[:ygrid] = latgridplot
    elements[:xticklabels] = xticklabelplot
    elements[:yticklabels] = yticklabelplot

    subtitlepos = lift(axis.blockscene, scene.viewport, axis.titlegap, axis.titlealign, axis.xaxisposition;
        ignore_equal_values=true) do a,
    titlegap, align, xaxisposition
        xaxisprotrusion = 0f0
        align_factor = Makie.halign2num(align, "Horizontal title align $align not supported.")
        x = a.origin[1] + align_factor * a.widths[1]

        yoffset = Makie.top(a) + titlegap + (xaxisposition === (:top) ? xaxisprotrusion : 0.0f0)

        return Point2d(x, yoffset)
    end

    titlealignnode = lift(axis.blockscene, axis.titlealign; ignore_equal_values=true) do align
        (align, :bottom)
    end

    subtitlet = text!(
        axis.blockscene, subtitlepos,
        text=axis.subtitle,
        visible=axis.subtitlevisible,
        fontsize=axis.subtitlesize,
        align=titlealignnode,
        font=axis.subtitlefont,
        color=axis.subtitlecolor,
        lineheight=axis.subtitlelineheight,
        markerspace=:data,
        inspectable=false)

    titlepos = lift(Makie.calculate_title_position, axis.blockscene, scene.viewport, axis.titlegap, axis.subtitlegap,
        axis.titlealign, axis.xaxisposition, Observable(0f0), axis.subtitlelineheight, axis, subtitlet; ignore_equal_values=true)

    titlet = text!(
        axis.blockscene, titlepos,
        text=axis.title,
        visible=axis.titlevisible,
        fontsize=axis.titlesize,
        align=titlealignnode,
        font=axis.titlefont,
        color=axis.titlecolor,
        lineheight=axis.titlelineheight,
        markerspace=:data,
        inspectable=false)

    xaxis = (; protrusion=x_protrusion)
    yaxis = (; protrusion=y_protrusion)
    map!(compute_protrusions, axis.blockscene, axis.layoutobservables.protrusions, axis.title, axis.titlesize,
        axis.titlegap, axis.titlevisible,
        xaxis.protrusion, 
        yaxis.protrusion,
        axis.subtitle, axis.subtitlevisible, axis.subtitlesize, axis.subtitlegap,
        axis.titlelineheight, axis.subtitlelineheight, subtitlet, titlet)

    fl = axis.finallimits[]
    notify(axis.limits)
    if fl == axis.finallimits[]
        notify(axis.finallimits)
    end

    return axis
end

# TODO, this just pads all protrusions
# We'll need to figure out which protrusion actually contains any labels
# To correctly calculate the protrusions
function compute_protrusions(title, titlesize, titlegap, titlevisible,
    xaxisprotrusion, yaxisprotrusion,
    subtitle, subtitlevisible, subtitlesize, subtitlegap, titlelineheight, subtitlelineheight,
    subtitlet, titlet)

    local left::Float32, right::Float32, bottom::Float32, top::Float32 = 0.0f0, 0.0f0, 0.0f0, 0.0f0

    bottom = xaxisprotrusion
    top = xaxisprotrusion

    titleheight = Makie.boundingbox(titlet, :data).widths[2] + titlegap
    subtitleheight = Makie.boundingbox(subtitlet, :data).widths[2] + subtitlegap

    titlespace = if !titlevisible || Makie.iswhitespace(title)
        0.0f0
    else
        titleheight
    end
    subtitlespace = if !subtitlevisible || Makie.iswhitespace(subtitle)
        0.0f0
    else
        subtitleheight
    end

    top += titlespace + subtitlespace

    left = yaxisprotrusion
    right = yaxisprotrusion

    return GridLayoutBase.RectSides{Float32}(left, right, bottom, top)
end

# This is where we override the stuff to make it our stuff.
function Makie.plot!(axis::GeoAxis, plot::Makie.AbstractPlot)
    # deal with setting the transform_func correctly
    source = pop!(plot.kw, :source, axis.source)
    transformfunc = lift(create_transform, axis.dest, source)

    if !Makie.not_in_data_space(plot)
        trans = Makie.Transformation(transformfunc; get(plot.kw, :transformation, Attributes())...)
        plot.kw[:transformation] = trans
    end

    # remove the reset_limits kwarg if there is one, this determines whether to automatically reset limits
    # on plot insertion
    reset_limits = to_value(pop!(plot.kw, :reset_limits, true))
    
    # actually plot
    Makie.plot!(axis.scene, plot)

    # reset limits ONLY IF the user has not said otherwise
    if reset_limits
        # some area-like plots basically always look better if they cover the whole plot area.
        # adjust the limit margins in those cases automatically.
        Makie.needs_tight_limits(plot) && Makie.tightlimits!(axis)

        if Makie.is_open_or_any_parent(axis.scene)
            Makie.reset_limits!(axis)
        end
    end

    return plot
end


# This function only exists to get around the attribute name check,
# since source and dest are not listed as common attributes.
# All crs handling is done in `plot!(ax::GeoAxis, plot)`.
function _create_plot!(F, attributes::Dict, ax::GeoAxis, args...)
    source = pop!(attributes, :source, nothing)
    dest = pop!(attributes, :dest, nothing)
    plot = Plot{Makie.default_plot_func(F, args)}(args, attributes)
    isnothing(source) || (plot.kw[:source] = source)
    isnothing(dest) || (plot.kw[:dest] = dest)
    Makie.plot!(ax, plot)
    return plot
end


# ## Makie generic axis/block API

# this is generally false, but I want to deviate from that here.
Makie.needs_tight_limits(axis::GeoAxis, ::Surface) = true

Makie.get_scene(ga::GeoAxis) = ga.scene
