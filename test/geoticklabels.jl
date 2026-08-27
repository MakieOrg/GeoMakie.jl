using LinearAlgebra

# Assertions about a realized figure: everything here is read back off the drawn
# result.  Label counts are asserted per case so that an axis that stops being
# labelled fails instead of passing vacuously.

function realize_geoaxis(; size = (720, 440), kwargs...)
    fig = Figure(; size)
    ax = GeoAxis(fig[1, 1]; kwargs...)
    resize_to_layout!(fig)
    Makie.update_state_before_display!(fig)
    return fig, ax
end

label_positions(plot) = Point2d.(plot[1][])
label_strings(plot) = string.(plot.text[])

ticklabel_font(ax, which) = Makie.to_font(
    Makie.theme(ax.blockscene, :fonts), getproperty(ax, Symbol(which, :ticklabelfont))[])

function label_boxes(ax, which)
    plot = ax.elements[Symbol(which, :ticklabels)]
    font = ticklabel_font(ax, which)
    fontsize = getproperty(ax, Symbol(which, :ticklabelsize))[]
    fonts = Makie.theme(ax.blockscene, :fonts)
    rotation = getproperty(ax, Symbol(which, :ticklabelrotation))[]
    return map(zip(label_positions(plot), plot.text[])) do (center, label)
        GeoMakie.glyph_bbox(
            center, GeoMakie.label_extents(label, font, fontsize, fonts); rotation)
    end
end

"""Labels exist, are finite, are paired with their text, and are distinct."""
function assert_labels(ax; min_count = 1, min_x = min_count, min_y = min_count)
    for (which, least) in ((:x, min_x), (:y, min_y))
        plot = ax.elements[Symbol(which, :ticklabels)]
        positions = label_positions(plot)
        @test length(positions) >= least
        @test length(positions) == length(label_strings(plot))
        @test all(isfinite, positions)
        for i in eachindex(positions), j in (i + 1):length(positions)
            @test norm(positions[i] - positions[j]) > 1
        end
    end
end

parse_labels(plot) = [parse(Float64, chop(s)) for s in label_strings(plot)]

"""A source-space point in the pixel space the tick labels are placed in."""
function pixel_point(ax, lonlat)
    projected = Point2d(Makie.apply_transform(Makie.transform_func(ax), Point2d(lonlat)))
    return Point2d(Makie.project(ax.scene.camera, :data, :pixel, projected)) .+
        minimum(ax.scene.viewport[])
end

function line_components(plot)
    components = Vector{Point2d}[]
    component = Point2d[]
    for p in Point2d.(plot[1][])
        if isfinite(p)
            push!(component, p)
        elseif !isempty(component)
            push!(components, component)
            component = Point2d[]
        end
    end
    isempty(component) || push!(components, component)
    return components
end

spine_point(; projected, dir = Point2d(NaN), intersect_dir = Point2d(NaN), input = Point2d(0)) =
    (input = Point2d(input), projected = Point2d(projected),
     dir = Point2d(dir), intersect_dir = Point2d(intersect_dir))

# Rectangle edges as `clip_segment_to_rect` builds them, so that a test can name
# the side a segment was clipped against.
const UNIT_RECT = Rect2d(-1, -1, 2, 2)
const RECT_BOTTOM = Line(Point2d(-1, -1), Point2d(1, -1))
const RECT_RIGHT = Line(Point2d(1, -1), Point2d(1, 1))
const RECT_TOP = Line(Point2d(1, 1), Point2d(-1, 1))
const RECT_LEFT = Line(Point2d(-1, 1), Point2d(-1, -1))

@testset "Segment clipping" begin
    inside = GeoMakie.clip_segment_to_rect(UNIT_RECT, Point2d(-0.5, 0), Point2d(0.5, 0))
    @test inside[1] == Point2d(-0.5, 0) && inside[2] == Point2d(0.5, 0)
    @test isnothing(inside[3]) && isnothing(inside[4])
    @test inside[5] == 0.0 && inside[6] == 1.0

    # Both endpoints outside, but the segment crosses: testing endpoint
    # membership would drop this one entirely.
    crossing = GeoMakie.clip_segment_to_rect(UNIT_RECT, Point2d(-2, 0.25), Point2d(2, 0.25))
    @test crossing[1] ≈ Point2d(-1, 0.25)
    @test crossing[2] ≈ Point2d(1, 0.25)
    @test crossing[3] == RECT_LEFT && crossing[4] == RECT_RIGHT
    @test crossing[5] ≈ 0.25 && crossing[6] ≈ 0.75

    @test isnothing(GeoMakie.clip_segment_to_rect(UNIT_RECT, Point2d(-3, 0), Point2d(-2, 0)))
    # Parallel to an edge and outside it: the `iszero(p)` branch.
    @test isnothing(GeoMakie.clip_segment_to_rect(UNIT_RECT, Point2d(-3, 2), Point2d(3, 2)))
    @test isnothing(GeoMakie.clip_segment_to_rect(UNIT_RECT, Point2d(0, 5), Point2d(0, 3)))

    corner = GeoMakie.clip_segment_to_rect(UNIT_RECT, Point2d(-2, -2), Point2d(0, 0))
    @test corner[1] ≈ Point2d(-1, -1)
    @test corner[2] == Point2d(0, 0)

    # A segment that only touches the rectangle, and a zero-length one, clip to a
    # single point.  `valid_line_in_limits` must not make a component of either.
    touching = GeoMakie.clip_segment_to_rect(UNIT_RECT, Point2d(-3, 0), Point2d(-1, 0))
    @test touching[1] == touching[2] == Point2d(-1, 0)
    @test isempty(first(GeoMakie.valid_line_in_limits(
        identity, identity, UNIT_RECT, Point2d(-3, 0), Point2d(-1, 0), 2)))

    degenerate = GeoMakie.clip_segment_to_rect(UNIT_RECT, Point2d(0, 0), Point2d(0, 0))
    @test degenerate[1] == degenerate[2] == Point2d(0, 0)
    @test isempty(first(GeoMakie.valid_line_in_limits(
        identity, identity, UNIT_RECT, Point2d(0, 0), Point2d(0, 0), 2)))
end

@testset "Clipped graticule components" begin
    # A segment whose sampled endpoints are both outside still crosses the
    # viewport and must yield one genuine component, not a fake entry component.
    lines, transformed, intersections = GeoMakie.valid_line_in_limits(
        identity, identity, UNIT_RECT, Point2d(-2, 0), Point2d(2, 0), 2)
    @test length(lines) == length(transformed) == length(intersections) == 1
    @test first(only(transformed)) ≈ Point2d(-1, 0)
    @test last(only(transformed)) ≈ Point2d(1, 0)
    @test all(p -> p in UNIT_RECT, only(transformed))

    # Regression for outside -> inside -> outside.  An earlier state machine
    # made a two-point entry component followed by the actual one.
    lines, transformed, intersections = GeoMakie.valid_line_in_limits(
        identity, identity, UNIT_RECT, Point2d(-2, 0.25), Point2d(2, 0.25), 9)
    @test length(lines) == length(transformed) == 1
    component = only(transformed)
    @test first(component) ≈ Point2d(-1, 0.25)
    @test last(component) ≈ Point2d(1, 0.25)
    @test all(p -> p in UNIT_RECT, component)
    @test all(!iszero, norm.(diff(component)))

    # A graticule traced along a viewport edge stays in one piece.  Its constant
    # coordinate has to be exactly constant for that: `LinRange(90, 90, 199)` is
    # not, because its two interpolation weights need not add up to one, and the
    # ulps that leaves lift the line off the edge and drop it back, breaking it
    # into pieces that each look as though the drawing ended there.
    @test any(!=(90.0), LinRange(90.0, 90.0, 199))
    world = Rect2d(-180, -90, 360, 180)
    for edge in (90.0, -90.0)
        lines, transformed, _ = GeoMakie.valid_line_in_limits(
            identity, identity, world, Point2d(-180, edge), Point2d(180, edge))
        @test length(lines) == 1
        @test all(p -> p[2] == edge, only(transformed))
    end

    # The continuity heuristic.  A transform with a jump in the middle must
    # split; a strongly curved but continuous one must not.  Passing `identity`
    # leaves the heuristic untested, because its sagitta is identically zero.
    jump = Makie.PointTrans{2}(p -> Point2d(p[1] + (p[1] > 0 ? 1.4 : 0.0), p[2]))
    unjump = Makie.PointTrans{2}(p -> Point2d(p[1] - (p[1] > 1.4 ? 1.4 : 0.0), p[2]))
    lines, _, _ = GeoMakie.valid_line_in_limits(
        jump, unjump, Rect2d(-2, -1, 4, 2), Point2d(-1, 0), Point2d(1, 0), 51)
    @test length(lines) == 2

    bend = Makie.PointTrans{2}(p -> Point2d(p[1], 0.9 * cos(p[1] * pi / 2)))
    unbend = Makie.PointTrans{2}(p -> Point2d(p[1], 0.0))
    lines, _, _ = GeoMakie.valid_line_in_limits(
        bend, unbend, Rect2d(-2, -2, 4, 4), Point2d(-1, 0), Point2d(1, 0), 51)
    @test length(lines) == 1
end

@testset "Glyph geometry" begin
    half_extents = Vec2d(11, 4)
    for rotation in (0.0, 0.3, -1.1, pi / 2)
        xaxis, yaxis = GeoMakie.rotated_axes(rotation)
        corners = [s1 * half_extents[1] * xaxis + s2 * half_extents[2] * yaxis
                   for s1 in (-1, 1), s2 in (-1, 1)]
        for angle in range(0, 2pi; length = 17)
            direction = Vec2d(cos(angle), sin(angle))
            @test GeoMakie.glyph_support(half_extents, direction; rotation) ≈
                maximum(c -> dot(c, direction), corners)
        end
        box = GeoMakie.glyph_bbox(Point2d(3, -2), half_extents; rotation)
        @test all(c -> Point2d(3, -2) + c in box, corners)
    end

    a = Rect2d(0, 0, 10, 10)
    @test GeoMakie.bbox_gap(a, Rect2d(5, 5, 10, 10)) == 0      # overlapping
    @test GeoMakie.bbox_gap(a, Rect2d(13, 0, 4, 10)) ≈ 3       # separated in x
    @test GeoMakie.bbox_gap(a, Rect2d(13, 14, 4, 4)) ≈ 5       # separated diagonally
end

@testset "Pixel-space placement" begin
    pad = 7.0
    half_extents = Vec2d(11, 4)

    # A horizontal boundary: longitude labels move straight down and clear the
    # anchor by exactly `pad`, measured from the glyph's support point.
    flat = spine_point(projected = (30, 10), dir = (0, -1), intersect_dir = (-1, 0))
    p = GeoMakie.place_ticklabel(flat, :bottom, half_extents, pad)
    @test p.mode === :axis
    @test p.normal ≈ Vec2d(0, -1)
    @test p.center[1] ≈ 30                       # no tangential drift
    @test p.center[2] ≈ 10 - (pad + half_extents[2])

    # A vertical boundary: latitude labels move straight left, again with no
    # drift along the side.
    side = spine_point(projected = (30, 10), dir = (-1, 0), intersect_dir = (0, 1))
    p = GeoMakie.place_ticklabel(side, :left, half_extents, pad)
    @test p.mode === :axis
    @test p.center[2] ≈ 10
    @test p.center[1] ≈ 30 - (pad + half_extents[1])

    # `:normal` mode follows the boundary normal, whatever the side asks for.
    slope = spine_point(projected = (0, 0), dir = normalize(Point2d(1, -1)),
                        intersect_dir = (-1, -1))
    p = GeoMakie.place_ticklabel(slope, :bottom, half_extents, pad; mode = :normal)
    @test p.mode === :normal
    @test p.normal ≈ normalize(Vec2d(1, -1))
    displacement = p.center - p.anchor
    @test abs(displacement[1] * p.normal[2] - displacement[2] * p.normal[1]) < 1e-10
    @test dot(displacement, p.normal) -
          GeoMakie.glyph_support(half_extents, p.normal) ≈ pad

    # Both modes leave exactly `pad` between glyph and anchor, at any incidence,
    # measured along the direction the label was moved.
    for angle in range(0.05, pi - 0.05; length = 25), mode in (:axis, :normal)
        normal = Vec2d(cos(angle), -sin(angle))
        sample = spine_point(projected = (0, 0), dir = Point2d(normal),
                             intersect_dir = Point2d(-normal[2], normal[1]))
        p = GeoMakie.place_ticklabel(sample, :bottom, half_extents, pad; mode)
        @test p.normal ≈ normal
        @test dot(p.center - p.anchor, p.direction) -
              GeoMakie.glyph_support(half_extents, p.direction) ≈ pad
    end

    # The gap a reader sees is the one along the axis, and it does not grow as
    # the boundary tilts away.  Measuring the clearance along the normal used to
    # inflate it by 1/cos of the incidence, stepping the labels of a curved limb
    # further out the further they were from the widest point.
    for angle in range(0.0, acos(0.5) - 1e-6; length = 12)
        normal = Vec2d(-cos(angle), sin(angle))
        sample = spine_point(projected = (0, 0), dir = Point2d(normal),
                             intersect_dir = Point2d(-normal[2], normal[1]))
        p = GeoMakie.place_ticklabel(sample, :left, half_extents, pad)
        @test p.mode === :axis
        @test p.center[2] ≈ 0 atol = 1e-9         # no drift along the side
        @test p.center[1] ≈ -(pad + half_extents[1])
    end

    # A boundary too steep for its axis rotates onto the normal instead of being
    # dropped, and the shift stays finite as the incidence goes to zero.
    steep = spine_point(projected = (0, 0), dir = normalize(Point2d(1, -0.05)),
                        intersect_dir = (0.05, 1))
    p = GeoMakie.place_ticklabel(steep, :bottom, half_extents, pad)
    @test p !== nothing
    @test p.mode === :normal
    @test isfinite(p.shift)

    # An outward direction pointing back into the axis still places a label.
    inward = spine_point(projected = (0, 0), dir = Point2d(0, 1), intersect_dir = (1, 0))
    p = GeoMakie.place_ticklabel(inward, :bottom, half_extents, pad)
    @test p !== nothing
    @test p.center[2] > 0

    # The shift is continuous across `min_axis_dot`; a jump there would reach the
    # protrusion and stop the layout settling.
    function shift_at(dot_value)
        normal = Vec2d(sqrt(1 - dot_value^2), -dot_value)
        sample = spine_point(projected = (0, 0), dir = Point2d(normal),
                             intersect_dir = Point2d(-normal[2], normal[1]))
        return GeoMakie.place_ticklabel(sample, :bottom, half_extents, pad).shift
    end
    @test shift_at(0.5 + 1e-9) ≈ shift_at(0.5 - 1e-9) atol = 1e-6

    # A degenerate boundary direction places nothing.  It means the endpoint is
    # not on a boundary at all: an azimuthal pole is in the middle of the map.
    pole = spine_point(projected = (0, 0), dir = Point2d(0, -1), intersect_dir = (0, 0))
    @test isnothing(GeoMakie.outward_frame(pole))
    @test isnothing(GeoMakie.place_ticklabel(pole, :bottom, half_extents, pad))
    @test isnothing(GeoMakie.place_ticklabel(
        spine_point(projected = (NaN, 0), intersect_dir = (1, 0)), :bottom, half_extents, pad))
end

@testset "Tick value cleanup" begin
    @test GeoMakie.snap_tickvalues(-180:30:180) == collect(-180.0:30.0:180.0)
    @test GeoMakie.snap_tickvalues(-180:22.5:180) == collect(-180.0:22.5:180.0)
    @test GeoMakie.snap_tickvalues([-122.30000000000001, -122.2, -122.1]) ==
        [-122.3, -122.2, -122.1]
    @test GeoMakie.snap_tickvalues([1.0]) == [1.0]
    @test GeoMakie.snap_tickvalues(Float64[]) == Float64[]
end

@testset "Label measurement" begin
    fonts = Makie.theme(:fonts)
    font = Makie.to_font(fonts, :regular)
    plain = GeoMakie.label_extents("-120ᵒ", font, 16.0, fonts)
    @test 2 .* plain ≈ Vec2d(widths(Makie.text_bb("-120ᵒ", font, 16.0))[1:2])

    # Rich text must be laid out, not flattened: `string(rich("10", …))` measures
    # the wrong glyphs at the wrong size.
    superscripted = GeoMakie.label_extents(rich("10", superscript("7")), font, 16.0, fonts)
    flattened = Vec2d(widths(Makie.text_bb("107", font, 16.0))[1:2]) ./ 2
    @test superscripted[1] < flattened[1]
    @test all(>(0), GeoMakie.label_extents(L"10^{7}", font, 16.0, fonts))
end

@testset "Placement modes are validated" begin
    _, ax = realize_geoaxis(; dest = "+proj=robin", limits = ((-180, 180), (-90, 90)))
    @test ax.xticklabelplacement[] === :axis
    @test ax.yticklabelplacement[] === :axis

    _, ax = realize_geoaxis(
        ; dest = "+proj=ob_tran +o_proj=eqc +o_lat_p=35 +o_lon_p=0 +lon_0=20",
        limits = ((-180, 180), (-90, 90)),
        xticklabelplacement = :normal, yticklabelplacement = :normal)
    @test ax.xticklabelplacement[] === :normal
    @test ax.yticklabelplacement[] === :normal

    @test_throws ArgumentError GeoAxis(Figure()[1, 1]; xticklabelplacement = :tangent)
    @test_throws ArgumentError GeoAxis(Figure()[1, 1]; yticklabelplacement = :tangent)
end

@testset "Every requested tick is labelled" begin
    xticks = [-120.0, -60.0, 0.0, 60.0, 120.0]
    yticks = [-40.0, -20.0, 0.0, 20.0, 40.0]
    for dest in ("+proj=merc", "+proj=eqearth")
        _, ax = realize_geoaxis(; dest, limits = ((-160, 160), (-60, 60)), xticks, yticks)
        @test parse_labels(ax.elements[:xticklabels]) == xticks
        @test parse_labels(ax.elements[:yticklabels]) == yticks
    end
end

@testset "Labels report their tick value" begin
    # Fractional ticks must survive formatting; rounding to three significant
    # digits used to collapse a zoomed range onto a single label.
    _, ax = realize_geoaxis(; dest = "+proj=merc", limits = ((-90, 90), (-45, 45)),
        xticks = collect(-67.5:22.5:67.5), yticks = [-22.5, 0.0, 22.5])
    @test parse_labels(ax.elements[:xticklabels]) == collect(-67.5:22.5:67.5)
    @test parse_labels(ax.elements[:yticklabels]) == [-22.5, 0.0, 22.5]

    # This range used to come out as several labels all reading "-122".
    _, ax = realize_geoaxis(; dest = "+proj=merc", limits = ((-122.6, -122.2), (37.6, 37.9)))
    @test length(label_strings(ax.elements[:xticklabels])) >= 3
    @test allunique(label_strings(ax.elements[:xticklabels]))
    for value in parse_labels(ax.elements[:xticklabels])
        @test -122.6 <= value <= -122.2
    end

    # A tick at latitude zero comes back from the inverse projection as
    # -8.39e-16 unless the traced coordinate is carried through.
    _, ax = realize_geoaxis(; dest = "+proj=merc", limits = ((-10, 10), (-5, 5)),
        yticks = [-2.0, 0.0, 2.0])
    @test "0ᵒ" in label_strings(ax.elements[:yticklabels])
end

@testset "Labels sit outside the frame, in order, without overlapping" begin
    _, ax = realize_geoaxis(; dest = "+proj=merc", limits = ((-180, 180), (-70, 70)),
        xticks = [-120.0, -60.0, 0.0, 60.0, 120.0], yticks = [-40.0, -20.0, 0.0, 20.0, 40.0])
    viewport = ax.scene.viewport[]
    xboxes = label_boxes(ax, :x)
    yboxes = label_boxes(ax, :y)
    @test !isempty(xboxes) && !isempty(yboxes)
    # A rectangular projection fills its viewport, so no tick label belongs
    # inside it.
    @test all(b -> maximum(b)[2] <= minimum(viewport)[2] + 1, xboxes)
    @test all(b -> maximum(b)[1] <= minimum(viewport)[1] + 1, yboxes)

    boxes = vcat(xboxes, yboxes)
    for i in eachindex(boxes), j in (i + 1):length(boxes)
        @test GeoMakie.bbox_gap(boxes[i], boxes[j]) >= 2
    end

    # Labels run along their side in tick order, and do not wander across it.
    xpositions = label_positions(ax.elements[:xticklabels])
    ypositions = label_positions(ax.elements[:yticklabels])
    @test issorted(getindex.(xpositions, 1))
    @test issorted(getindex.(ypositions, 2))
    # No drift across the side: longitude labels share a baseline and latitude
    # labels a right edge.  Measured on the boxes, since label widths differ.
    @test allequal(round.(minimum.(xboxes) .|> b -> b[2]; digits = 6))
    @test allequal(round.(maximum.(yboxes) .|> b -> b[1]; digits = 6))
end

@testset "Padding moves the labels" begin
    ticks = (xticks = [-120.0, 0.0, 120.0], yticks = [-40.0, 0.0, 40.0])
    _, tight = realize_geoaxis(; dest = "+proj=merc", limits = ((-180, 180), (-70, 70)),
        ticks..., xticklabelpad = 5.0, yticklabelpad = 5.0)
    _, loose = realize_geoaxis(; dest = "+proj=merc", limits = ((-180, 180), (-70, 70)),
        ticks..., xticklabelpad = 25.0, yticklabelpad = 25.0)
    @test label_strings(tight.elements[:xticklabels]) ==
        label_strings(loose.elements[:xticklabels])
    protrusion(ax) = ax.layoutobservables.protrusions[]
    @test protrusion(loose).bottom ≈ protrusion(tight).bottom + 20 atol = 1
    @test protrusion(loose).left ≈ protrusion(tight).left + 20 atol = 1
end

@testset "Protrusions cover the labels" begin
    _, ax = realize_geoaxis(; dest = "+proj=merc", limits = ((-180, 180), (-70, 70)),
        xticks = [-120.0, 0.0, 120.0], yticks = [-40.0, 0.0, 40.0], xticklabelpad = 5.0)
    protrusions = ax.layoutobservables.protrusions[]
    @test protrusions.bottom > 0 && protrusions.left > 0
    @test protrusions.bottom >= maximum(b -> widths(b)[2], label_boxes(ax, :x))
    @test protrusions.left >= maximum(b -> widths(b)[1], label_boxes(ax, :y))
end

@testset "Labels survive a large font" begin
    # A fixed pixel budget for the shift used to delete most of an axis as soon
    # as the labels grew.
    small = last(realize_geoaxis(; dest = "+proj=merc", limits = ((-180, 180), (-70, 70)),
        xticks = [-120.0, 0.0, 120.0], yticks = [-40.0, 0.0, 40.0],
        xticklabelsize = 12, yticklabelsize = 12))
    large = last(realize_geoaxis(; dest = "+proj=merc", limits = ((-180, 180), (-70, 70)),
        xticks = [-120.0, 0.0, 120.0], yticks = [-40.0, 0.0, 40.0],
        xticklabelsize = 30, yticklabelsize = 30))
    assert_labels(small; min_count = 3)
    assert_labels(large; min_count = 3)
    @test label_strings(small.elements[:xticklabels]) ==
        label_strings(large.elements[:xticklabels])
    @test label_strings(small.elements[:yticklabels]) ==
        label_strings(large.elements[:yticklabels])

    _, robin = realize_geoaxis(; dest = "+proj=robin", limits = ((-180, 180), (-90, 90)),
        xticks = collect(-180.0:60.0:180.0), yticks = collect(-90.0:30.0:90.0),
        xticklabelsize = 30, yticklabelsize = 30)
    assert_labels(robin; min_count = 3)
end

@testset "Hidden labels free their neighbours" begin
    counts = map((true, false)) do visible
        _, ax = realize_geoaxis(; dest = "+proj=merc", limits = ((-180, 180), (-70, 70)),
            xticks = collect(-180.0:60.0:180.0), yticks = collect(-60.0:30.0:60.0),
            xticklabelsvisible = visible)
        length(label_strings(ax.elements[:yticklabels]))
    end
    @test counts[1] == counts[2]
    @test counts[1] > 0
end

@testset "Graticules are not truncated by the requested limits" begin
    # Projecting the limit rectangle through PROJ widens the source range, so
    # tracing only the requested one leaves parallels ending mid-map.
    _, ax = realize_geoaxis(; dest = "+proj=moll", limits = ((-150, 80), (-70, 70)),
        xticks = [-120.0, -60.0, 0.0, 60.0], yticks = [-60.0, -30.0, 0.0, 30.0, 60.0])
    rect = ax.finallimits[]
    equator = argmin(c -> abs(sum(p[2] for p in c) / length(c)),
        line_components(ax.elements[:ygrid]))
    # In projected metres, of which the view is 34 million across in 660 pixels.
    @test minimum(p[1] for p in equator) ≈ minimum(rect)[1] atol = 1.0
    @test maximum(p[1] for p in equator) ≈ maximum(rect)[1] atol = 1.0
    assert_labels(ax)
end

@testset "Source extent of a shifted world map" begin
    # The view's own corners are past the ends of the pole line, and both of its
    # vertical edges are the one seam, so inverse-projecting the bounding box
    # reports a sliver near the central meridian instead of the whole world.
    # `trans` projects, `trans_inv` inverts, matching `project_tick_points!`.
    trans = GeoMakie.create_transform("+proj=robin +lon_0=150", "+proj=longlat +datum=WGS84")
    trans_inv = GeoMakie.create_transform("+proj=longlat +datum=WGS84", "+proj=robin +lon_0=150")
    δ = 1.0e-6
    rect = Makie.apply_transform(trans, Rect2d(-30 + δ, -90, 360 - 2δ, 180))

    naive = Makie.xlimits(Makie.apply_transform(trans_inv, rect))
    @test naive[2] - naive[1] < 359                  # the whole world, short of a turn
    # Both reported ends are interior points, tens of degrees from the seam.
    @test abs(Makie.apply_transform(trans, Point2d(naive[1], 0))[1]) < 0.5 * maximum(rect)[1]
    @test abs(Makie.apply_transform(trans, Point2d(naive[2], 0))[1]) < 0.5 * maximum(rect)[1]

    xlims, ylims = GeoMakie.source_extent(trans, trans_inv, rect)
    @test xlims[1] ≈ -30 atol = 1
    @test xlims[2] ≈ 330 atol = 1
    @test ylims[1] ≈ -90 atol = 1
    @test ylims[2] ≈ 90 atol = 1

    # A zoomed view keeps its own extent rather than being widened to a turn.
    # The projected bounding box is a little wider than the requested longitudes
    # -- Robinson's meridians converge, so the box's width is set at its lowest
    # latitude -- and the extent covers the box, not the request.
    zoomed = Makie.apply_transform(trans, Rect2d(100, 10, 40, 30))
    zx, zy = GeoMakie.source_extent(trans, trans_inv, zoomed)
    @test 90 < zx[1] <= 100
    @test 140 <= zx[2] < 150
    @test zy[1] ≈ 10 atol = 1
    @test zy[2] ≈ 40 atol = 1
end

@testset "A shifted world map labels its limb, not its middle" begin
    # The parallels used to be traced over a longitude range that stopped short
    # of the seam, leaving both of their endpoints -- and so both latitude
    # labels -- a few tens of degrees either side of the central meridian, drawn
    # over the map instead of beside it.
    δ = 1.0e-6
    _, ax = realize_geoaxis(; dest = "+proj=robin +lon_0=150",
        limits = ((-30 + δ, 330 - δ), (-90, 90)),
        xticks = collect(-30.0:30.0:300.0), yticks = collect(-90.0:30.0:90.0))
    boxes = label_boxes(ax, :y)
    values = parse_labels(ax.elements[:yticklabels])
    @test length(boxes) >= 5

    # The equator spans the full width of the view: its graticule reaches the
    # seam at both ends.
    rect = ax.finallimits[]
    equator = argmin(c -> abs(sum(p[2] for p in c) / length(c)),
        line_components(ax.elements[:ygrid]))
    # In projected metres, of which the view is 34 million across in 660 pixels.
    @test minimum(p[1] for p in equator) ≈ minimum(rect)[1] atol = 1.0
    @test maximum(p[1] for p in equator) ≈ maximum(rect)[1] atol = 1.0

    # Every label clears the western limb by the padding and no more.  The
    # anchors used to sit a few tens of degrees east of the central meridian, and
    # measuring the padding along the boundary normal used to push the labels
    # near the poles progressively further out: 5 pixels at the equator became
    # 19 at 60 degrees.
    limb_x(lat) = pixel_point(ax, (-30 + δ, lat))[1]
    for (box, value) in zip(boxes, values)
        @test limb_x(value) - maximum(box)[1] ≈ ax.yticklabelpad[] atol = 0.5
    end
end

@testset "Where the drawing ends" begin
    radius = 0.05
    probe(drawn, point) = GeoMakie.outline_normal(drawn, Point2d(point), radius)

    # A straight edge: the outward direction is the one with nothing beyond it,
    # whichever way round the drawing lies.
    for angle in range(0, 2pi; length = 17)[1:(end - 1)]
        outward = Vec2d(cos(angle), sin(angle))
        half_plane = p -> dot(Vec2d(p), outward) <= 0
        found = probe(half_plane, Point2d(0, 0))
        @test all(isfinite, found)
        @test normalize(Vec2d(found)) ≈ outward atol = 1e-3
    end

    # Nothing ends anywhere near a point with drawing all round it, however far
    # from the middle of it the point is.
    disc = p -> norm(Vec2d(p)) <= 1
    @test !all(isfinite, probe(disc, Point2d(0, 0)))
    @test !all(isfinite, probe(disc, Point2d(0.9, 0)))
    # ... but on the edge of that same drawing, the outward direction is radial.
    for angle in range(0, 2pi; length = 9)[1:(end - 1)]
        at = Point2d(cos(angle), sin(angle))
        found = probe(disc, at)
        @test all(isfinite, found)
        @test normalize(Vec2d(found)) ≈ Vec2d(at) atol = 1e-2
    end

    # Drawing far smaller than the ring is found by throwing a smaller one; the
    # first ring here lies entirely outside it.
    speck = p -> norm(Vec2d(p)) <= radius / 10
    at = Point2d(radius / 10, 0)
    @test !any(k -> speck(at + radius * Point2d(cospi(k / 8), sinpi(k / 8))), 0:15)
    found = probe(speck, at)
    @test all(isfinite, found)
    @test dot(normalize(Vec2d(found)), Vec2d(1, 0)) > 0.5

    # Nothing drawn at all, at any radius.
    @test !all(isfinite, probe(p -> false, Point2d(0, 0)))
end

@testset "A graticule that stops in open map is not labelled" begin
    # The visible half of an oblique orthographic reaches over the pole, so a
    # meridian on the far side is traced from the limb to the pole and stops
    # there, in the middle of the map.  Approximating the boundary with the
    # orthogonal graticule made that pole look like one, and the meridian was
    # labelled over Scandinavia.
    dest = "+proj=ortho +lat_0=30 +lon_0=20"
    _, ax = realize_geoaxis(; dest, limits = ((-180, 180), (-90, 90)),
        xticklabelplacement = :normal, yticklabelplacement = :normal)
    assert_labels(ax; min_count = 4)

    trans = GeoMakie.create_transform(dest, "+proj=longlat +datum=WGS84")
    inverse = GeoMakie.create_transform("+proj=longlat +datum=WGS84", dest)
    rect = ax.finallimits[]
    on_map = GeoMakie.map_membership(trans, inverse, GeoMakie.roundtrip_tolerance(rect))
    mini, maxi = extrema(rect)
    drawn(p) = all(mini .<= p .<= maxi) && !isnothing(on_map(p))
    # Three times the probe's own reach, so that a label merely up against the
    # limb still counts as outside it.
    reach = 3 * GeoMakie.OUTLINE_RADIUS * norm(widths(rect))
    camera = ax.scene.camera
    function in_data(pixel)
        return Point2d(Makie.project(
            camera, :pixel, :data, Point2d(pixel) .- minimum(ax.scene.viewport[])))
    end

    for which in (:x, :y)
        for position in label_positions(ax.elements[Symbol(which, :ticklabels)])
            at = in_data(position)
            @test !all(k -> drawn(at + reach * Point2d(cospi(k / 8), sinpi(k / 8))), 0:15)
        end
    end
end

@testset "Poles and corners" begin
    # A meridian and a parallel meeting at one pixel name the same place.
    _, ax = realize_geoaxis(; dest = "+proj=robin", limits = ((-180, 180), (-90, 90)),
        xticks = collect(-180.0:60.0:180.0), yticks = collect(-90.0:30.0:90.0))
    @test parse_labels(ax.elements[:xticklabels]) == collect(-120.0:60.0:120.0)
    @test parse_labels(ax.elements[:yticklabels]) == collect(-60.0:30.0:60.0)

    # Every Mollweide meridian ends at a pole; one central label survives rather
    # than the axis going blank.
    _, ax = realize_geoaxis(; dest = "+proj=moll", limits = ((-180, 180), (-90, 90)),
        xticks = collect(-150.0:30.0:150.0), yticks = collect(-60.0:30.0:60.0))
    assert_labels(ax)
end

@testset "Polar projections keep their meridian labels" begin
    for dest in ("+proj=stere +lat_0=90 +lon_0=0", "+proj=laea +lat_0=90 +lon_0=0")
        _, ax = realize_geoaxis(; dest, limits = ((-180, 180), (20, 90)),
            xticks = collect(-180.0:60.0:180.0), yticks = [30.0, 60.0])
        # Every meridian leaves through a viewport edge and is labelled there.
        @test length(label_strings(ax.elements[:xticklabels])) >= 3

        # Every parallel is a closed circle in the middle of the map, with no
        # endpoint on any edge to hang a label from.  Labelling these needs
        # radial placement, which the axis does not do.
        @test_broken !isempty(label_strings(ax.elements[:yticklabels]))
    end
end

@testset "Rich and LaTeX formatters" begin
    _, ax = realize_geoaxis(; dest = "+proj=merc", limits = ((-100, -20), (-40, 50)),
        xtickformat = vs -> [rich("10", superscript(string(Int(v)))) for v in vs],
        ytickformat = vs -> [L"%$(Int(v))^{\circ}" for v in vs])
    @test !isempty(ax.elements[:xticklabels].text[])
    @test all(l -> l isa Makie.RichText, ax.elements[:xticklabels].text[])
    @test !isempty(ax.elements[:yticklabels].text[])
    @test all(l -> l isa Makie.LaTeXString, ax.elements[:yticklabels].text[])
end

@testset "Projection and extent smoke matrix" begin
    # Five longitude ticks and five latitude ticks are requested throughout; the
    # counts are how many of them reach a boundary and survive collision.
    cases = [
        ("+proj=robin", ((-180, 180), (-90, 90)), :axis, 5, 5),
        # Every meridian of this oblique view meets the map's edge at the south
        # pole and nowhere else, two great circles crossing at one visible point,
        # so the two edges of the map carry one meridian label each.
        ("+proj=ob_tran +o_proj=eqc +o_lat_p=35 +o_lon_p=0 +lon_0=20", ((-180, 180), (-90, 90)), :normal, 2, 3),
        ("+proj=merc", ((-125, -55), (5, 65)), :axis, 2, 2),
        ("+proj=robin +lon_0=150", ((-180, 180), (-90, 90)), :axis, 5, 5),
        ("+proj=moll", ((-150, 80), (-70, 70)), :axis, 5, 5),
        # Every meridian of a full orthographic ends at a pole, both poles are on
        # the limb, and the labels pile onto those two points.  The bottom of the
        # axis keeps one of them.
        ("+proj=ortho", ((-180, 180), (-90, 90)), :normal, 1, 5),
        # A polar projection labels its meridians, but its parallels are closed
        # circles with no endpoint on an edge; only the clipped equator is left.
        ("+proj=laea +lat_0=90 +lon_0=0", ((-180, 180), (20, 90)), :normal, 3, 1),
    ]
    # The CI artifact step uploads `test_images/` from the repository root.
    images = joinpath(dirname(@__DIR__), "test_images")
    mkpath(images)
    for (dest, limits, mode, min_x, min_y) in cases
        fig, ax = realize_geoaxis(; dest, limits,
            xticks = collect(-120.0:60.0:120.0), yticks = collect(-60.0:30.0:60.0),
            xticklabelplacement = mode, yticklabelplacement = mode,
            title = "$dest ($mode)")
        assert_labels(ax; min_x, min_y)
        lines!(ax, GeoMakie.coastlines(); color = :gray50, linewidth = 0.5)
        name = replace(dest, r"[^A-Za-z0-9]" => "_")
        save(joinpath(images, "ticklabels_$(name)_$(mode).png"), fig)
    end

    # A full orthographic used to label no meridian at all: the boundary a
    # meridian ends on is the limb, which is not a graticule, and approximating
    # it with the parallel through the pole gave a direction of zero length.
    _, ortho = realize_geoaxis(; dest = "+proj=ortho", limits = ((-180, 180), (-90, 90)),
        xticks = collect(-120.0:60.0:120.0), xticklabelplacement = :normal)
    @test !isempty(label_strings(ortho.elements[:xticklabels]))
end
