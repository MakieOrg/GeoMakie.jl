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
        "The smallest angle in degrees at which a graticule may meet the boundary and still be labelled. GMT's `MAP_ANNOT_MIN_ANGLE`; zero labels every crossing."
        ticklabelminangle::Float64 = 20f0
        "The smallest gap in pixels between two tick labels. Labels closer than this are dropped, the outermost first."
        ticklabelmingap::Float64 = 2f0
        "The logging level tick labels dropped for crowding or grazing incidence are reported at: `:debug` or `:info`."
        ticklabelreport::Symbol = :debug
        "The latitude a polar cap begins at, where the map closes around a pole. Meridians stop there, except one every 90 degrees, and a parallel is drawn to close them. `nothing` draws every meridian to the pole. GMT's `MAP_POLAR_CAP`."
        polarcap::Union{Nothing,Float64} = 85.0
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
inside `rect`, as `(lines, lines_transformed, intersections)`.

`lines` holds each component's source-space vertices, `lines_transformed` their
projected counterparts, and `intersections` the rectangle edges its two ends
were clipped against, `nothing` for an end that was already inside.

Non-finite samples and discontinuities break the line into components, and each
segment is clipped separately so that a segment crossing the rectangle between
two outside endpoints is still drawn.
"""
function valid_line_in_limits(trans, trans_rev, rect, point_start, point_stop, n = 100)
    # Odd samples are the segment endpoints, even samples their midpoints, which
    # the continuity test below needs.  One pass projects both.
    m = 2n - 1
    # A graticule is traced at a constant coordinate, and `LinRange(c, c, m)` is
    # not exactly `c` at every index: its two interpolation weights need not add
    # up to one.  The last bits that leaves in a parallel's latitude are half a
    # metre of projected northing at the pole line of a Robinson map, enough to
    # walk the line out of a viewport whose limits are the map and back, breaking
    # it into pieces at each step.
    samples_along(a, b) = a == b ? fill(a, m) : collect(LinRange(a, b, m))
    xrange = samples_along(point_start[1], point_stop[1])
    yrange = samples_along(point_start[2], point_stop[2])
    sampled = [Point2d(xrange[i], yrange[i]) for i in 1:m]
    projected = [Point2d(Makie.apply_transform(trans, p)) for p in sampled]

    # Floor the sagitta test at a fraction of the viewport.  Purely relative, it
    # splits continuous geometry near a projection singularity, where curvature
    # outruns the chord; a real discontinuity jumps a visible distance.
    continuity_floor = 1.0e-3 * norm(widths(rect))

    lines = Vector{Point2d}[]
    lines_t = Vector{Point2d}[]
    intersections = Vector{Union{Line{2,Float64},Nothing}}[]

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

        # Consecutive clipped segments share an exact transformed sample.
        # Otherwise an out-of-bounds gap separates two components.
        if current > 0 && lines_t[current][end] == clipped_start_t
            push!(lines[current], clipped_stop)
            push!(lines_t[current], clipped_stop_t)
            intersections[current][2] = stop_side
        else
            push!(lines, Point2d[clipped_start, clipped_stop])
            push!(lines_t, Point2d[clipped_start_t, clipped_stop_t])
            push!(intersections, Union{Line{2,Float64},Nothing}[start_side, stop_side])
            current = length(lines)
        end
    end
    return lines, lines_t, intersections
end

"""
    map_membership(trans, trans_inverse, tol)

A closure taking a projected point to its source coordinates, or to `nothing`
where that point is not on the map.

PROJ answers outside a projection with a coordinate that is either non-finite or
one that does not project back: everything past the pole line of a Robinson map
inverts to infinity, and a longitude past the seam comes back wrapped onto the
far side of the map.  Round-tripping recognises both, and has to know nothing
about the projection to do it.  `tol` is how far a point may move on the way
there and back and still count as being on the map.
"""
function map_membership(trans, trans_inverse, tol)
    return function (p)
        q = Point2d(Makie.apply_transform(trans_inverse, p))
        all(isfinite, q) || return nothing
        back = Point2d(Makie.apply_transform(trans, q))
        (all(isfinite, back) && norm(back - Point2d(p)) <= tol) || return nothing
        return q
    end
end

"""
Round-trip slack, as a fraction of the projected view's diagonal.  A point on
the map returns to within rounding of itself; one off it returns a visible
fraction of the view away, if at all.

Relative to the view and never a distance in projected units: those run from
radians to metres depending on the projection, and a fixed slack in them is
either everything or nothing.
"""
const ROUNDTRIP_TOLERANCE = 1.0e-6

roundtrip_tolerance(rect) = ROUNDTRIP_TOLERANCE * norm(widths(rect))

"""
    drawn_predicate(trans, trans_inverse, rect)

A closure reporting whether a projected point is drawn: on the map, and inside
the view `rect`.
"""
function drawn_predicate(trans, trans_inverse, rect)
    on_map = map_membership(trans, trans_inverse, roundtrip_tolerance(rect))
    mini, maxi = extrema(rect)
    return p -> all(mini .<= p .<= maxi) && !isnothing(on_map(p))
end

"""
Directions sampled around a graticule endpoint when asking whether the map ends
there.  Fine enough that no projection's outline slips between two of them, and
coarse enough to cost a fraction of tracing the graticule that produced the
endpoint.
"""
const OUTLINE_SAMPLES = 16

"""
Bisection steps refining each end of the ring's arc of drawing.  Eight place
each end within a thousandth of a radian, so the direction they give does not
step from one ring sample to the next as the map moves.
"""
const OUTLINE_BISECTIONS = 8

"""
How far the ring is thrown around the endpoint, as a fraction of the projected
view's diagonal.  Far enough out to be nowhere near
[`ROUNDTRIP_TOLERANCE`](@ref), close enough in that the outline is straight
across it.
"""
const OUTLINE_RADIUS = 2.0e-3

"""Ring shrinks tried where the first radius finds no map at all."""
const OUTLINE_SHRINKS = 4

"""
    outline_normal(drawn, point, radius; n = OUTLINE_SAMPLES)

The projected direction out of the drawn region at the graticule endpoint
`point`, or a non-finite direction where the drawing does not end there.

`drawn` reports whether a projected point is drawn -- on the map, and inside the
view -- and a ring of them around `point` says which kind of endpoint this is.
An endpoint on the outline has drawing on one side of it and nothing on the
other, whether what ends there is the limb of an azimuthal projection, the pole
line of a pseudocylindrical one, the seam of an interrupted one, or the edge of
the view.  An endpoint where the graticule merely ran out of the traced range,
such as the pole of an oblique orthographic, has drawing all the way round; it
gets no direction and so no tick label, which would otherwise sit in the middle
of the map against nothing.

Asking about the drawing rather than about the graticule means this does not
need to know why the trace stopped, that it finds an outline no graticule
follows, and that the side the label goes on is known rather than guessed from a
graticule that may be running along the boundary it ends on.  The widest arc of
drawing around the ring is the inside, its chord is the outline, and its ends are
bisected out of the ring so that the direction does not jump from one sample to
the next as the map moves.

Where the first ring finds nothing drawn at all -- the drawing is a sliver at
this scale -- the radius shrinks and the ring is thrown again.
"""
function outline_normal(drawn, point, radius; n = OUTLINE_SAMPLES)
    step = 2pi / n
    at(r, angle) = Point2d(point[1] + r * cos(angle), point[2] + r * sin(angle))
    inside = falses(n)
    for _ in 1:OUTLINE_SHRINKS
        inside .= (k -> drawn(at(radius, (k - 1) * step))).(1:n)
        if !any(inside)
            radius /= 4
            continue
        end
        all(inside) && return Point2d(NaN)

        # The widest run of drawing around the ring, walked from a sample the
        # drawing starts at so that runs are contiguous rather than wrapping.
        origin = findfirst(k -> inside[k] && !inside[mod1(k - 1, n)], 1:n)
        best_first, best_length, k = origin, 0, 1
        while k <= n
            index = mod1(origin + k - 1, n)
            if !inside[index]
                k += 1
                continue
            end
            len = 1
            while k + len <= n && inside[mod1(origin + k + len - 1, n)]
                len += 1
            end
            len > best_length && ((best_first, best_length) = (index, len))
            k += len
        end

        function crossing(mapped, empty)
            for _ in 1:OUTLINE_BISECTIONS
                middle = (mapped + empty) / 2
                drawn(at(radius, middle)) ? (mapped = middle) : (empty = middle)
            end
            return (mapped + empty) / 2
        end
        low = (best_first - 1) * step
        high = low + (best_length - 1) * step
        first_end, last_end = crossing(low, low - step), crossing(high, high + step)
        chord = at(radius, last_end) - at(radius, first_end)
        normal = Point2d(-chord[2], chord[1])
        # Away from the middle of the arc, which is the deepest the ring gets
        # into the drawing.
        return dot(normal, at(radius, (first_end + last_end) / 2) - Point2d(point)) > 0 ?
            -normal : normal
    end
    return Point2d(NaN)
end

function add_to_lines!(result, outline, valid_line, line_transformed, intersections, coordinate, dim,
                       spine_start, spine_end)
    append!(result, line_transformed)
    push!(result, Point2d(NaN))

    # Restore the exact tick coordinate the graticule was traced at.  Inverting a
    # clipped endpoint through PROJ only recovers it to floating-point accuracy
    # -- latitude zero comes back as -8.39e-16 -- and a label reports that value.
    anchor_input(p) = dim == 1 ? Point2d(coordinate, p[2]) : Point2d(p[1], coordinate)
    # A clipped end lies on a viewport edge, which is the boundary there, and the
    # graticule's own direction says which side of it is out.  An unclipped one
    # has to be asked about: the graticule may have reached the edge of the map,
    # or only the end of the traced range, in the middle of it.  The answer also
    # says which side is out, which is worth more than the graticule there --
    # that can be running along the very boundary it ends on.
    function frame(line, at, inward)
        isnothing(line) || return (Point2d(line[1] .- line[2]), normalize(at .- inward))
        outward = outline(at)
        isfinite(outward) || return (Point2d(NaN), Point2d(NaN))
        return (Point2d(outward[2], -outward[1]), outward)
    end
    i_start, i_end = intersections

    # An end the drawing does not stop at is no anchor, and is left out entirely
    # rather than pushed with a direction nothing can use: anchors also suppress
    # the orthogonal axis where the two share a corner, and an end in the middle
    # of the map should not take another label with it.
    function anchor!(spine, clipped, source, at, inward)
        isnothing(spine) && return
        boundary, outward = frame(clipped, at, inward)
        isfinite(boundary) && !iszero(boundary) || return
        push!(spine, (
            input = anchor_input(source),
            projected = at,
            dir = outward,
            intersect_dir = boundary,
        ))
        return
    end

    anchor!(spine_start, i_start, valid_line[1], line_transformed[1], line_transformed[2])
    anchor!(spine_end, i_end, valid_line[end], line_transformed[end], line_transformed[end - 1])
    return
end

"""
The gap left between the two ends of a graticule that goes right round the
world, in degrees.  Traced right up to the cut, both ends would land on it,
where they are one point and the segment between them runs back across the whole
map.  A millionth of a degree is a ten-thousandth of a pixel on a world map.
"""
const CUT_MARGIN = 1.0e-6

"""
How far short of a pole the map is asked about, in degrees.

Far enough in to be a graticule point and not the singularity itself -- PROJ's
orthographic inverts everything within a millionth of a degree of a pole to
infinity -- and near enough to answer for it: a thousandth of a degree is a
hundred metres, a hundred-thousandth of a pixel on a world map.
"""
const POLE_PROBE = 1.0e-3

"""Longitudes tried when looking for the map's cut."""
const CUT_SAMPLES = 24

"""Bisection steps narrowing it down; forty reach double precision."""
const CUT_BISECTIONS = 40

"""
    longitude_cut(trans, trans_inverse, longitude, latitude; n = CUT_SAMPLES)

The longitude east of `longitude` that the map is cut at, measured along the
parallel at `latitude`.

PROJ wraps a longitude more than half a turn from the central meridian back
round, so a parallel's projection jumps there: the cut is the map's eastern and
western edges, which are one line on the globe and two on the page.  A graticule
traced right round the world has to start and stop there, or it stops short of
one edge by however far the trace is misaligned -- a Robinson map with
`+lon_0=150` viewed through limits of `-180` to `180` is three degrees out, and
every parallel then ends in open map and is left unlabelled.

The cut cannot be found by asking PROJ where a longitude went, because its
inverse wraps every longitude into `[-180, 180]` whether it crossed the cut or
not.  It shows up only as the jump, which is what the search here looks for: the
widest step around the parallel, narrowed by keeping whichever half of it still
holds the jump.  A projection continuous in longitude, such as a polar
azimuthal, has no jump and no cut, and the arbitrary longitude this returns for
one is as good as any other: its parallels are closed circles, which come back to
where they started wherever that is.
"""
function longitude_cut(trans, trans_inverse, longitude, latitude; n = CUT_SAMPLES)
    at(l) = Point2d(Makie.apply_transform(trans, Point2d(l, latitude)))
    step = 360.0 / n
    # One turn of samples, the last of which is the first come right round again.
    points = [at(longitude + k * step) for k in 0:n]
    gap(a, b) = all(isfinite, a) && all(isfinite, b) ? norm(b - a) : -Inf
    steps = [gap(points[k], points[k + 1]) for k in 1:n]
    widest = argmax(steps)
    isfinite(steps[widest]) || return longitude + 180.0

    low, high = longitude + (widest - 1) * step, longitude + widest * step
    at_low, at_high = points[widest], points[widest + 1]
    for _ in 1:CUT_BISECTIONS
        middle = (low + high) / 2
        at_middle = at(middle)
        all(isfinite, at_middle) || break
        if gap(at_low, at_middle) >= gap(at_middle, at_high)
            high, at_high = middle, at_middle
        else
            low, at_low = middle, at_middle
        end
    end
    return high
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
that wraps right round is recognised separately and laid against the map's cut,
since it has no longitude extremes to find.

`n` is the sampling density per side.  The interior is sampled, not just the
boundary: the pole of a polar view is in the middle of it, and so is the highest
latitude the view reaches.  A pole is still only one point, small enough for a
grid to step over, so each of the two is asked about by name as well.
"""
function source_extent(trans, trans_inverse, rect; n = 65)
    mini, maxi = extrema(rect)
    span = maxi .- mini
    inverse = map_membership(trans, trans_inverse, roundtrip_tolerance(rect))

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

    # A pole is one point, and a grid of samples can miss it even with the whole
    # world in view: an oblique projection puts the geographic poles in the
    # middle of the map, where nothing marks them out.  Asking about them
    # directly is cheap, and a graticule traced to a degree short of one stops in
    # open map, where it gets no tick label.
    #
    # The pole is asked about on the graticule just short of itself as well as at
    # itself.  On most projections the pole is a point of the map's own edge,
    # where the inverse is ill-conditioned and can answer with a coordinate that
    # does not project back; rejecting it there would stop every meridian short
    # of a pole that is plainly drawn.
    function drawn_pole(lat)
        project(q) = Point2d(Makie.apply_transform(trans, q))
        p = project(Point2d(reference, lat))
        (all(isfinite, p) && all(mini .<= p .<= maxi)) || return false
        return !isnothing(inverse(p)) ||
            !isnothing(inverse(project(pole_probe_point(reference, lat))))
    end
    drawn_pole(90.0) && (high = Point2d(high[1], 90.0))
    drawn_pole(-90.0) && (low = Point2d(low[1], -90.0))

    # A view that wraps right round has no longitude extremes to find: every row
    # crosses the branch cut somewhere else, so their union lands on whatever
    # turn the unwrapping happened to pick, and the sampling stops a fraction of
    # a degree short either side.  A polar view reports -268 to 90.  A whole turn
    # is what the graticule needs, laid against the map's own cut so that it ends
    # on the map's edges rather than somewhere in the middle of it.
    if all(slices)
        cut = longitude_cut(trans, trans_inverse, reference, (low[2] + high[2]) / 2)
        low = Point2d(cut - 360.0 + CUT_MARGIN, low[2])
        high = Point2d(cut - CUT_MARGIN, high[2])
    elseif high[1] - low[1] > 360.0
        # Tracing more than one turn redraws the same graticule over itself.
        middle = (low[1] + high[1]) / 2
        low = Point2d(middle - 180.0, low[2])
        high = Point2d(middle + 180.0, high[2])
    end
    return ((low[1], high[1]), (low[2], high[2]))
end

function project_tick_points!(result, trans, trans_inverse, drawn, radius, range, coordinate,
                              dim, limit_rect, spine_start, spine_end)
    # dim == 1 traces a meridian at constant longitude, dim == 2 a parallel.
    point_fun(tick) = dim === 1 ? Point2d(coordinate, tick) : Point2d(tick, coordinate)

    # What is drawn is the map clipped to the view, and a tick label belongs
    # outside whichever of the two ends the graticule it labels.
    outline(p_t) = outline_normal(drawn, p_t, radius)

    lines, lines_transformed, intersections = valid_line_in_limits(
        trans, trans_inverse, limit_rect, point_fun(range[1]), point_fun(range[end]))
    # Every component offers both of its ends and `add_to_lines!` keeps the ones
    # the drawing really stops at.  Which component holds a graticule's boundary
    # ends cannot be told from the trace: a parallel of an oblique orthographic
    # is traced from the middle of the map, round the back of the globe, and back
    # to where it started, so it is the inner ends of its two components that
    # reach the limb and the outer ones that stop in open map.
    for i in eachindex(lines)
        length(lines[i]) >= 2 || continue
        add_to_lines!(result, outline, lines[i], lines_transformed[i], intersections[i],
                      coordinate, dim, spine_start, spine_end)
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

"""A side that lost no tick labels."""
const NO_TICKLABELS_DROPPED = (crowding = 0, grazing = 0)

"""
One sentence of the suppression report: which axes lost how many labels to one
reason, and the attribute that reverses it.  A named reason reads as a choice
the axis made; a silent drop reads as a bug in the projection.
"""
function ticklabel_suppression_sentence(counted, wording, attribute, setting)
    return string(
        join(("$count $name" for (name, count) in counted), " and "),
        " annotation", sum(last, counted) == 1 ? "" : "s",
        " skipped due to ", wording,
        "; controlled by `", attribute, "`, currently ", setting,
    )
end

"""
    ticklabel_suppression_message(dropped; mingap, minangle)

One line accounting for every tick label dropped, naming the attribute that
controls each reason and its current value, or `nothing` where none were dropped.

`dropped` pairs the name of each axis with its counts, as
[`ticklabel_candidates`](@ref) returns them:

```julia-repl
julia> ticklabel_suppression_message(
           ("longitude" => (crowding = 2, grazing = 0),
            "latitude" => (crowding = 1, grazing = 0)); mingap = 2.0, minangle = 20.0)
"2 longitude and 1 latitude annotations skipped due to crowding; controlled by `ticklabelmingap`, currently 2.0 px."
```
"""
function ticklabel_suppression_message(dropped; mingap, minangle)
    any(pair -> last(pair).crowding > 0 || last(pair).grazing > 0, dropped) || return nothing
    sentences = String[]
    crowded = [(name, counts.crowding) for (name, counts) in dropped if counts.crowding > 0]
    isempty(crowded) || push!(sentences, ticklabel_suppression_sentence(
        crowded, "crowding", :ticklabelmingap, "$mingap px"))
    grazed = [(name, counts.grazing) for (name, counts) in dropped if counts.grazing > 0]
    isempty(grazed) || push!(sentences, ticklabel_suppression_sentence(
        grazed, "grazing incidence", :ticklabelminangle, "$minangle degrees"))
    return join(sentences, ". ") * "."
end

"""
    report_ticklabel_suppression!(reported, message, level)

Report `message` at logging `level`, `:debug` or `:info`, unless it is the one
`reported` already holds: placement runs on every redraw and the same report
each time is noise rather than information.
"""
function report_ticklabel_suppression!(reported, message, level)
    level in (:debug, :info) || throw(ArgumentError(
        "ticklabelreport must be :debug or :info, got $(repr(level))"))
    message == reported[] && return
    reported[] = message
    isnothing(message) && return
    level === :info ? (@info message) : (@debug message)
    return
end

"""
    ticklabel_candidates(samples, tickvalues, labels, dim, side, font, fontsize, fonts,
                         pad, rotation, mode; corner_anchors, occupied, collision_gap,
                         min_angle)

Place one side's tick labels and drop the ones that collide or graze.

`samples` are that side's projected endpoints, each carrying its exact tick value
in component `dim`, which indexes into `tickvalues`/`labels`.  Those cover the
whole tick vector rather than the visible subset, so that a user formatter sees
the same input however many graticules are on screen.

Returns `(; positions, labels, placements, protrusion, dropped)`, the first
three ordered by tick value.  `dropped` counts the labels this side lost, by
reason, for [`ticklabel_suppression_message`](@ref) to report.
"""
function ticklabel_candidates(
        samples, tickvalues, labels, dim, side, font, fontsize, fonts, pad, rotation, mode;
        corner_anchors = Point2d[], corner_atol = 0.0, occupied = Rect2{Float64}[],
        collision_gap = 2.0, min_angle = 0.0,
    )
    isempty(samples) && return (;
        positions = Point2d[], labels = Any[], placements = NamedTuple[],
        protrusion = 0.0f0, dropped = NO_TICKLABELS_DROPPED,
    )

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
    placed = Set{Int}()
    grazed = Set{Int}()
    grazed_placements = NamedTuple[]
    corner_fallback = nothing
    for i in priority
        sample = samples[i]
        isfinite(sample.input) || continue
        tick = findfirst(==(sample.input[dim]), tickvalues)
        isnothing(tick) && continue
        # A graticule can reach one side more than once: an equator clipped by
        # each edge of a polar view in turn, or a parallel arriving at a limb in
        # two components.  The label belongs at one of those, the most central.
        tick in placed && continue
        if grazes_boundary(sample, min_angle)
            # Still placed for the protrusion measure below: grazing reads
            # pixel-space directions, which the reservation itself moves.
            if !(tick in grazed)
                push!(grazed, tick)
                placement = place_ticklabel(
                    sample, side, label_extents(labels[tick], font, fontsize, fonts), pad;
                    mode, rotation)
                isnothing(placement) || push!(grazed_placements, placement)
            end
            continue
        end

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
        push!(placed, tick)
    end
    if isempty(placements) && !isnothing(corner_fallback)
        push!(placements, corner_fallback[1])
        push!(placement_labels, corner_fallback[2])
        push!(placement_values, corner_fallback[3])
    end
    # Reserve space for every candidate, grazed ones included, not only the ones
    # surviving the filters.  Which labels are dropped depends on the size of the
    # scene, and this number decides that size; feeding the filtered set back
    # would let the layout chase one label in and out of the frame forever.
    protrusion = ticklabel_protrusion(vcat(placements, grazed_placements), side)

    accepted = Int[]
    boxes = copy(occupied)
    for (i, placement) in enumerate(placements)
        any(box -> bbox_gap(placement.bbox, box) < collision_gap, boxes) && continue
        push!(accepted, i)
        push!(boxes, placement.bbox)
    end

    order = accepted[sortperm(placement_values[accepted])]
    return (;
        positions = Point2d[placements[i].center for i in order],
        labels = Any[placement_labels[i] for i in order],
        placements = NamedTuple[placements[i] for i in order],
        protrusion = protrusion,
        dropped = (
            crowding = length(placements) - length(accepted),
            # A tick grazing one end of its graticule and reaching the boundary
            # squarely at the other is labelled there, and was not dropped.
            grazing = count(!in(placed), grazed),
        ),
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
    # Derived rather than `axis.dest` itself: the transform observables above
    # already carry a destination change here, and this one rarely moves with it.
    latitude_limit_obs = map(graticule_latitude_limit, scene, axis.dest; ignore_equal_values=true)
    # This is kind of the main redrawing loop for the axis.  This should really be
    # factored out into a sync and async function, so that zooming is fluid, but
    # we can figure that out later.
    # What this does is first calculate limits and ticks, then create spines and
    # project them.  Those are stored in Observables which are used to produce
    # lineplots later on that form the grid.
    # TODO: implement a minor grid.
    onany(scene, axis.xticks, axis.yticks,
        transform_ticks_obs, finallimits, vp_unchanged,
        axis.xticklabelsize, axis.yticklabelsize, latitude_limit_obs, axis.polarcap;
        update=true) do user_xticks, user_yticks, trans, fl, vp,
            xlabelsize, ylabelsize, latitude_limit, polarcap

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

        # An interval per direction, chosen from the room a label needs against
        # the room the axis has.  The minors wait on a minor grid; anything finer
        # than `LADDER_DEGREE_FLOOR` waits on a formatter, and `ladder_major`
        # asks `graticule_tickvalues` for its fallback tick finder instead.
        interval = graticule_interval(
            (xlims[2] - xlims[1], ylims[2] - ylims[1]), widths(vp), (xlabelsize, ylabelsize))
        xtickvalues = collect(Float64,
            user_xticks isa Makie.Automatic ?
                graticule_tickvalues(xlims..., ladder_major(interval.x)) :
                Makie.get_tickvalues(user_xticks, xlims...))
        ytickvalues = collect(Float64,
            user_yticks isa Makie.Automatic ?
                limit_graticule_latitudes(
                    graticule_tickvalues(ylims..., ladder_major(interval.y)),
                    latitude_limit, ylims) :
                Makie.get_tickvalues(user_yticks, ylims...))

        drawn = drawn_predicate(trans, trans_inverse, limit_rect)
        radius = OUTLINE_RADIUS * norm(widths(limit_rect))
        # Poles the map closes around, where the meridians would otherwise fan
        # into a rosette in the last few degrees.
        poles = isnothing(polarcap) ? NO_INTERIOR_POLES :
            interior_poles(trans, drawn, radius, (xlims[1] + xlims[2]) / 2)
        capped_ylims = polar_cap_range(ylims, poles, polarcap)

        spines = spines_obs[]
        foreach(empty!, (spines.left, spines.right, spines.bottom, spines.top))
        # Tick values select graticules; they must not also truncate them.  Trace
        # each one across the whole inverse-transformed view and let
        # `valid_line_in_limits` clip it in projected space.
        for lon in xtickvalues
            project_tick_points!(lon_transformed, trans, trans_inverse, drawn, radius,
                                 capped_ylims, lon, 1, limit_rect, spines.bottom, spines.top)
        end
        # Cap meridians are generated, not filtered from the ticks: the cap
        # promises one every `POLAR_CAP_MERIDIAN_INTERVAL` degrees whatever
        # interval the axis chose.  Unlabelled, like the cap parallel below.
        for range in polar_cap_segments(ylims, poles, polarcap),
                lon in interval_multiples(xlims[1], xlims[2], POLAR_CAP_MERIDIAN_INTERVAL)
            project_tick_points!(lon_transformed, trans, trans_inverse, drawn, radius,
                                 range, lon, 1, limit_rect, nothing, nothing)
        end
        for lat in ytickvalues
            project_tick_points!(lat_transformed, trans, trans_inverse, drawn, radius,
                                 xlims, lat, 2, limit_rect, spines.left, spines.right)
        end
        # The parallel closing a cap is a gridline and not a tick: it is drawn
        # wherever the cap falls, which is not a value the tick finder chose, and
        # labelling it would put a latitude on the axis that no other line shares.
        for lat in polar_cap_parallels(ylims, poles, polarcap)
            project_tick_points!(lat_transformed, trans, trans_inverse, drawn, radius,
                                 xlims, lat, 2, limit_rect, nothing, nothing)
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
    # The last suppression report made, so that a redraw does not repeat it.
    reported = Ref{Union{Nothing,String}}(nothing)
    onany(
        scene, pixel_spines, axis.xaxisposition, axis.yaxisposition,
        axis.xtickformat, axis.ytickformat,
        axis.xticklabelfont, axis.yticklabelfont,
        axis.xticklabelsize, axis.yticklabelsize,
        axis.xticklabelpad, axis.yticklabelpad,
        axis.xticklabelrotation, axis.yticklabelrotation,
        axis.xticklabelplacement, axis.yticklabelplacement,
        axis.xticklabelsvisible, axis.yticklabelsvisible,
        axis.ticklabelminangle, axis.ticklabelmingap, axis.ticklabelreport,
    ) do spines, xside, yside, xformat, yformat, xfont, yfont,
            xsize, ysize, xpad, ypad, xrotation, yrotation, xmode, ymode,
            xvisible, yvisible, minangle, mingap, reportlevel
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

        min_angle = deg2rad(minangle)
        # Automatic ticks are labelled on the turn they are read on, selected on
        # the turn they were traced on; a user's tick values are the user's, and
        # the formatter sees them untouched.
        xlabelvalues = axis.xticks[] isa Makie.Automatic ? wrap_longitudes(xvalues) : xvalues
        xcand = ticklabel_candidates(
            getproperty(spines, xside), xvalues,
            ticklabel_strings(xformat, xlabelvalues),
            1, xside, Makie.to_font(fonts, xfont), xsize, fonts, xpad, xrotation, xmode;
            corner_anchors = xcorners, corner_atol, collision_gap = mingap, min_angle,
        )
        ycand = ticklabel_candidates(
            getproperty(spines, yside), yvalues, ticklabel_strings(yformat, yvalues),
            2, yside, Makie.to_font(fonts, yfont), ysize, fonts, ypad, yrotation, ymode;
            corner_anchors = ycorners, corner_atol, collision_gap = mingap, min_angle,
            # Hidden longitude labels occupy no space, so they must not evict
            # latitude labels either.
            occupied = xvisible ? Rect2d[p.bbox for p in xcand.placements] : Rect2d[],
        )
        report_ticklabel_suppression!(
            reported,
            ticklabel_suppression_message(
                ("longitude" => xcand.dropped, "latitude" => ycand.dropped);
                mingap, minangle),
            reportlevel)

        # Keep positions and text lengths synchronized through Makie's compute
        # graph when ticks or limits change interactively.
        Makie.update!(xticklabelplot; arg1=xcand.positions, text=xcand.labels)
        Makie.update!(yticklabelplot; arg1=ycand.positions, text=ycand.labels)
        # Never reserve so much that the axis itself disappears.  The suggested
        # box already has the current reservation taken out of it, so add that
        # back: a cap that shrank as we reserved would be part of the loop.
        room = widths(axis.layoutobservables.suggestedbbox[])
        outer = (room[1] + 2 * y_protrusion[], room[2] + 2 * x_protrusion[])
        cap = (0.35f0 * outer[2], 0.35f0 * outer[1])
        request = (
            xvisible ? min(xcand.protrusion, cap[1]) : 0.0f0,
            yvisible ? min(ycand.protrusion, cap[2]) : 0.0f0,
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
