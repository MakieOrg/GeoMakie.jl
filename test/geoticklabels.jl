using LinearAlgebra

# These adapters intentionally isolate the tests from the representation of a
# placement result and from Makie's Text plot internals.  The implementation
# contract under test is `_geo_ticklabel_placement`; if its result field names
# change, only `_placement_*` should need updating.
_placement_position(p::Point2) = Point2d(p)
_placement_position(p) = Point2d(
    hasproperty(p, :center) ? getproperty(p, :center) : getproperty(p, :position)
)

function _placement_normal(p, fallback)
    hasproperty(p, :normal) ? Vec2d(getproperty(p, :normal)) : normalize(Vec2d(fallback))
end

function _place(samples, i, outward, side, half_extents, pad; mode = :axis, kwargs...)
    return GeoMakie._geo_ticklabel_placement(
        Point2d.(samples), i, Vec2d(outward), side, Vec2d(half_extents), pad;
        mode, kwargs...,
    )
end

# Integration assumptions: `elements[:xticklabels]` and `[:yticklabels]` name
# the matching Text plots, while `:xgrid` and `:ygrid` expose NaN-separated
# projected point vectors as their first argument.  Adapt only these accessors
# if the integration chooses a different diagnostic representation.
_label_positions(plot) = Point2d.(plot[1][])
_label_strings(plot) = string.(plot.text[])

function _line_components(plot)
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

function _realize_geoaxis(; size = (720, 440), kwargs...)
    fig = Figure(; size)
    ax = GeoAxis(fig[1, 1]; kwargs...)
    resize_to_layout!(fig)
    Makie.update_state_before_display!(fig)
    return fig, ax
end

function _assert_finite_labels(ax)
    for key in (:xticklabels, :yticklabels)
        positions = _label_positions(ax.elements[key])
        @test all(isfinite, positions)
        @test length(positions) == length(_label_strings(ax.elements[key]))
    end
end

function _assert_no_duplicate_positions(positions; atol = 1e-6)
    for i in eachindex(positions), j in (i + 1):length(positions)
        @test norm(positions[i] - positions[j]) > atol
    end
end

@testset "GeoAxis tick-label placement modes" begin
    fig, ax = _realize_geoaxis(; dest = "+proj=robin")
    @test ax.xticklabelplacement[] === :axis
    @test ax.yticklabelplacement[] === :axis

    fig, ax = _realize_geoaxis(
        ; dest = "+proj=ob_tran +o_proj=eqc +o_lat_p=35 +o_lon_p=0 +lon_0=20",
        xticklabelplacement = :normal,
        yticklabelplacement = :normal,
    )
    @test ax.xticklabelplacement[] === :normal
    @test ax.yticklabelplacement[] === :normal
    _assert_finite_labels(ax)

    @test_throws ArgumentError GeoAxis(Figure()[1, 1]; xticklabelplacement = :tangent)
    @test_throws ArgumentError GeoAxis(Figure()[1, 1]; yticklabelplacement = :tangent)
end

@testset "Pixel-space placement oracle" begin
    pad = 7.0
    half_extents = Vec2d(11, 4)

    # Longitude labels on a Robinson-like horizontal polar boundary move only
    # vertically in :axis mode.  Clearance is measured from the glyph's support
    # point, not from its center.
    bottom = Point2d[(-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0)]
    p = _place(bottom, 3, (0, -1), :bottom, half_extents, pad; mode = :axis)
    @test p !== nothing
    center = _placement_position(p)
    normal = _placement_normal(p, (0, -1))
    anchor = bottom[3]
    @test center[1] ≈ anchor[1] atol = 1e-10
    @test dot(center - anchor, normal) -
          GeoMakie._geo_ticklabel_glyph_support(half_extents, normal) ≈ pad atol = 1e-8

    # Latitude labels move only horizontally in :axis mode, avoiding the
    # distracting vertical drift seen on sloping projection envelopes.
    left = Point2d[(0, -2), (0, -1), (0, 0), (0, 1), (0, 2)]
    p = _place(left, 3, (-1, 0), :left, half_extents, pad; mode = :axis)
    @test p !== nothing
    center = _placement_position(p)
    normal = _placement_normal(p, (-1, 0))
    anchor = left[3]
    @test center[2] ≈ anchor[2] atol = 1e-10
    @test dot(center - anchor, normal) -
          GeoMakie._geo_ticklabel_glyph_support(half_extents, normal) ≈ pad atol = 1e-8

    # Full-normal mode is the opt-in for oblique axes: the center displacement
    # is parallel to the sampled boundary normal, with the same glyph clearance.
    diagonal = Point2d[(-2, -2), (-1, -1), (0, 0), (1, 1), (2, 2)]
    outward = normalize(Vec2d(1, -1))
    p = _place(diagonal, 3, outward, :bottom, half_extents, pad; mode = :normal)
    @test p !== nothing
    center = _placement_position(p)
    normal = _placement_normal(p, outward)
    displacement = center - diagonal[3]
    @test abs(displacement[1] * normal[2] - displacement[2] * normal[1]) < 1e-10
    @test dot(displacement, normal) -
          GeoMakie._geo_ticklabel_glyph_support(half_extents, normal) ≈ pad atol = 1e-8
end

@testset "Clipped graticule components" begin
    rect = Rect2d(-1, -1, 2, 2)

    # A segment whose sampled endpoints are both outside still crosses the
    # viewport and must yield one genuine component, not a fake entry component.
    lines, transformed, intersections = GeoMakie.valid_line_in_limits(
        identity, identity, rect, Point2d(-2, 0), Point2d(2, 0), 2,
    )
    @test length(lines) == length(transformed) == length(intersections) == 1
    @test first(only(transformed)) ≈ Point2d(-1, 0)
    @test last(only(transformed)) ≈ Point2d(1, 0)
    @test all(p -> p in rect, only(transformed))

    # Regression for outside -> inside -> outside.  The old state machine made
    # a two-point entry component followed by the actual component.
    lines, transformed, intersections = GeoMakie.valid_line_in_limits(
        identity, identity, rect, Point2d(-2, 0.25), Point2d(2, 0.25), 9,
    )
    @test length(lines) == length(transformed) == length(intersections) == 1
    component = only(transformed)
    @test first(component) ≈ Point2d(-1, 0.25)
    @test last(component) ≈ Point2d(1, 0.25)
    @test all(p -> p in rect, component)
    @test all(!iszero, norm.(diff(component)))
end

@testset "Regional ticks do not define graticule endpoints" begin
    _, ax = _realize_geoaxis(
        ; dest = "+proj=merc",
        limits = ((-100, -20), (-40, 50)),
        xticks = [-80, -60, -40],       # deliberately omit both x limits
        yticks = [-20, 0, 20],          # deliberately omit both y limits
        xtickformat = xs -> string.(xs),
        ytickformat = xs -> string.(xs),
    )
    limit_rect = ax.finallimits[]
    xcomponents = _line_components(ax.elements[:xgrid])
    ycomponents = _line_components(ax.elements[:ygrid])

    @test length(xcomponents) == 3
    @test length(ycomponents) == 3
    @test all(c -> isapprox(minimum(p[2] for p in c), minimum(limit_rect)[2]; atol=1e-6), xcomponents)
    @test all(c -> isapprox(maximum(p[2] for p in c), maximum(limit_rect)[2]; atol=1e-6), xcomponents)
    @test all(c -> isapprox(minimum(p[1] for p in c), minimum(limit_rect)[1]; atol=1e-6), ycomponents)
    @test all(c -> isapprox(maximum(p[1] for p in c), maximum(limit_rect)[1]; atol=1e-6), ycomponents)
    _assert_finite_labels(ax)
end

@testset "Pole, corner, and collapsed-anchor suppression" begin
    # Pole handling must be symmetric.  Neither +/-90 degree latitude label is
    # useful when it coincides with the longitude boundary corner/pole.
    _, ax = _realize_geoaxis(
        ; dest = "+proj=robin",
        xticks = [-180, -120, -60, 0, 60, 120, 180],
        yticks = [-90, -60, -30, 0, 30, 60, 90],
        xtickformat = xs -> string.(xs),
        ytickformat = xs -> string.(xs),
    )
    ylabels = _label_strings(ax.elements[:yticklabels])
    @test !("-90" in ylabels)
    @test !("90" in ylabels)

    # Mollweide meridians collapse at each pole.  Retaining multiple labels at
    # the same anchor is never valid, even if their strings differ.
    _, ax = _realize_geoaxis(
        ; dest = "+proj=moll",
        xticks = collect(-150:30:150),
        yticks = [-60, -30, 0, 30, 60],
        xtickformat = xs -> string.(xs),
        ytickformat = xs -> string.(xs),
    )
    xpos = _label_positions(ax.elements[:xticklabels])
    _assert_no_duplicate_positions(xpos)
    @test length(xpos) <= 1
end

@testset "Projection and extent smoke matrix" begin
    cases = [
        # global pseudo-cylindrical
        ("+proj=robin", nothing, :axis),
        # the intended full-normal opt-in for oblique EQC
        ("+proj=ob_tran +o_proj=eqc +o_lat_p=35 +o_lon_p=0 +lon_0=20", nothing, :normal),
        # regional cylindrical
        ("+proj=merc", ((-125, -55), (5, 65)), :axis),
        # shifted central meridian
        ("+proj=robin +lon_0=150", nothing, :axis),
        # elliptical projection with polar collapse
        ("+proj=moll", ((-150, 80), (-70, 70)), :axis),
    ]

    for (dest, limits, mode) in cases
        kwargs = isnothing(limits) ? (;) : (; limits)
        _, ax = _realize_geoaxis(
            ; dest, kwargs...,
            xticks = [-120, -60, 0, 60, 120],
            yticks = [-60, -30, 0, 30, 60],
            xticklabelplacement = mode,
            yticklabelplacement = mode,
        )
        _assert_finite_labels(ax)
        _assert_no_duplicate_positions(_label_positions(ax.elements[:xticklabels]))
        _assert_no_duplicate_positions(_label_positions(ax.elements[:yticklabels]))
    end
end
