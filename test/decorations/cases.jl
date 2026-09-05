# cases.jl -- the named axis cases the decorations are judged on: the twelve
# research baselines, the two issue reproductions, and the first thirty
# projections of examples/most_projections.jl.

struct DecorationCase
    name::String
    dest::String
    limits::Any            # `nothing` or ((lon0, lon1), (lat0, lat1))
    attrs::NamedTuple      # extra GeoAxis attributes
    figure::NamedTuple     # extra Figure keywords (`fontsize`, …)
    setup::Any             # `nothing`, or `(fig, ax) -> …` run after the axis is built and its limits set
end
DecorationCase(name, dest, limits, attrs = (;); figure = (;), setup = nothing) =
    DecorationCase(name, dest, limits, attrs, figure, setup)

const BASELINE_CASES = DecorationCase[
    DecorationCase("eqearth", "+proj=eqearth", nothing),
    DecorationCase("robin150", "+proj=robin +lon_0=150", nothing),
    DecorationCase("merc_reg", "+proj=merc", ((-10, 30), (35, 60))),
    DecorationCase("ortho", "+proj=ortho +lon_0=-20 +lat_0=30", nothing),
    DecorationCase("laea_polar", "+proj=laea +lat_0=90 +lon_0=0", ((-180, 180), (60, 90))),
    DecorationCase("laea_polar_nolimits", "+proj=laea +lat_0=90 +lon_0=0", nothing),
    DecorationCase("moll", "+proj=moll", nothing),
    DecorationCase("ob_tran", "+proj=ob_tran +o_proj=eqc +o_lat_p=35 +o_lon_p=0 +lon_0=20", nothing),
    DecorationCase("zoom3", "+proj=merc", ((10, 12), (45, 47))),
    DecorationCase("stere_polar", "+proj=stere +lat_0=90 +lat_ts=70", ((-180, 180), (50, 90))),
    DecorationCase("lcc", "+proj=lcc +lon_0=-96 +lat_1=33 +lat_2=45", ((-125, -65), (23, 52))),
    DecorationCase("igh", "+proj=igh", nothing),
]

const ISSUE_CASES = DecorationCase[
    DecorationCase("issue_234", "+proj=eqearth", ((0, 3), (0, 3))),
    DecorationCase("issue_388", "+proj=tmerc +lon_0=15", ((-5, 35), (55, 73))),
]

const MOST_PROJECTION_CASES = DecorationCase[
    DecorationCase("most_" * replace(split(dest)[1][7:end], r"[^a-z0-9_]" => "_"), dest, nothing)
    for dest in MOST_PROJECTIONS
]

# Attribute variants: the axis positions on a rectangular frame, and the
# interior-label column moved to another carrier meridian.
const VARIANT_CASES = DecorationCase[
    DecorationCase("merc_reg_top", "+proj=merc", ((-10, 30), (35, 60)), (; xaxisposition = :top)),
    DecorationCase("merc_reg_right", "+proj=merc", ((-10, 30), (35, 60)), (; yaxisposition = :right)),
    DecorationCase("merc_reg_both", "+proj=merc", ((-10, 30), (35, 60)), (; xaxisposition = :both, yaxisposition = :both)),
    DecorationCase("laea_polar_c90", "+proj=laea +lat_0=90 +lon_0=0", nothing, (; carriermeridian = 90)),
]

# The fancy frame on a rectangle, a limb and a pseudocylindrical outline.
const FANCY_CASES = DecorationCase[
    DecorationCase("merc_reg_fancy", "+proj=merc", ((-10, 30), (35, 60)), (; framestyle = :fancy)),
    DecorationCase("ortho_fancy", "+proj=ortho +lon_0=-20 +lat_0=30", nothing, (; framestyle = :fancy)),
    DecorationCase("robin150_fancy", "+proj=robin +lon_0=150", nothing, (; framestyle = :fancy)),
]

# The layout: titles, subtitles and axis labels on the sides the positions
# name, the lcc title collision from the stage-1 log, and #281's request for
# exact protrusions.
const LAYOUT_CASES = DecorationCase[
    DecorationCase("lcc_title", "+proj=lcc +lon_0=-96 +lat_1=33 +lat_2=45", ((-125, -65), (23, 52)),
        (; title = "Lambert conformal conic", subtitle = "standard parallels 33°N and 45°N", xlabel = "Longitude", ylabel = "Latitude")),
    DecorationCase("issue_281", "+proj=eqearth", nothing, (; title = "issue 281", xlabel = "tight_ticklabel_spacing!")),
    DecorationCase("merc_reg_labels", "+proj=merc", ((-10, 30), (35, 60)),
        (; xlabel = "Longitude", ylabel = "Latitude", subtitle = "axis labels")),
    DecorationCase("merc_reg_labels_topright", "+proj=merc", ((-10, 30), (35, 60)),
        (; xaxisposition = :top, yaxisposition = :right, xlabel = "Longitude", ylabel = "Latitude", title = "labels on top and right")),
]

# Minor graticule and minor ticks: the paired minor step on a rectangle, a
# limb and a fancy frame; #215's webmerc with every minor attribute set; and
# IntervalsBetween on user majors.
const MINOR_ATTRS = (; xminorgridvisible = true, yminorgridvisible = true, xminorticksvisible = true, yminorticksvisible = true)
const MINOR_CASES = DecorationCase[
    DecorationCase("merc_reg_minor", "+proj=merc", ((-10, 30), (35, 60)), MINOR_ATTRS),
    DecorationCase("ortho_minor", "+proj=ortho +lon_0=-20 +lat_0=30", nothing, MINOR_ATTRS),
    DecorationCase("merc_reg_fancy_minor", "+proj=merc", ((-10, 30), (35, 60)), (; framestyle = :fancy, MINOR_ATTRS...)),
    DecorationCase("issue_215", "+proj=webmerc", ((-30, 60), (-40, 70)),
        (; xminorgridvisible = true, yminorgridvisible = true, xminorticksvisible = true, yminorticksvisible = true,
           xminorgridcolor = (:red, 0.3), yminorgridcolor = (:blue, 0.3), xminorgridwidth = 2.0, yminorgridstyle = :dash,
           xminorticksize = 8.0, yminorticksize = 8.0, xminortickcolor = :red, yminortickcolor = :blue, xminortickwidth = 2.0)),
    DecorationCase("merc_reg_intervals", "+proj=merc", ((-10, 30), (35, 60)),
        (; xticks = -10:10:30, yticks = 35:5:60, xminorticks = IntervalsBetween(5), yminorticks = IntervalsBetween(2), MINOR_ATTRS...)),
]

# The mask outside the frame: lcc_title without it shows the coastlines of
# the Phase 7 render running out to the viewport, over the tick labels.
const MASK_CASES = DecorationCase[
    DecorationCase("lcc_title_nomask", "+proj=lcc +lon_0=-96 +lat_1=33 +lat_2=45", ((-125, -65), (23, 52)),
        (; title = "Lambert conformal conic", subtitle = "standard parallels 33°N and 45°N", xlabel = "Longitude", ylabel = "Latitude",
           maskoutside = false)),
]

# Every tick issue as a case that reproduces its report.  #234 (issue_234),
# #388 (issue_388) and #215 (issue_215) are above; #281, #349 and #268 are in
# the layout cases and builders.  Each floor below would fail on the master
# behaviour the report describes.
const CLOSURE_CASES = DecorationCase[
    # #317: the docs world map, latitude labels on the curved bulge and
    # longitude labels cut by the outline
    DecorationCase("issue_317", "+proj=eqearth", nothing),
    # #190: an orthographic world map with the report's title and axis labels;
    # the tick labels sat inside the disc and only `xlabelpadding` moved them
    DecorationCase("issue_190", "+proj=ortho", nothing,
        (; title = "Ground Trace", titlegap = 16, xlabel = "Longitude [°]", ylabel = "Latitude [°]", xticklabelsize = 20, yticklabelsize = 20)),
    # #350: `yticklabelalign` was ignored (hard-coded centre), so the degree
    # signs of a latitude column never lined up
    DecorationCase("issue_350", "+proj=merc", ((-10, 30), (0, 60)), (; yticklabelalign = (:right, :center))),
    # #231: `ylims!(0, 90)` on a conic; the graticule and its labels ran on to 60°S
    DecorationCase("issue_231", "+proj=leac +lat_1=45 +ellps=sphere", ((-180, 180), (0, 90))),
    # #157: a south-up map by `scale!(ax.scene, 1, -1, 1)`; the ticks ignored the model transform
    DecorationCase("issue_157", "+proj=eqearth", nothing; setup = (fig, ax) -> scale!(ax.scene, 1, -1, 1)),
    # #339: an Axis beside a GeoAxis; the spine and grid colours differed
    DecorationCase("issue_339", "+proj=merc", ((-10, 30), (35, 60)); setup = (fig, ax) -> Axis(fig[1, 2])),
    # #150: empty ticks segfaulted
    DecorationCase("issue_150", "+proj=eqearth", nothing, (; xticks = Float64[], yticks = Float64[])),
    # #134: a 20° × 10° eqc region lost its latitude labels (later thinned to every other degree)
    DecorationCase("issue_134", "+proj=eqc", ((-150, -130), (-25, -15))),
    # #155: a rectangle zoom emptied the labels and a reset did not bring them back
    DecorationCase("issue_155", "+proj=eqearth", nothing;
        setup = (fig, ax) -> ax.interactions[:rectanglezoom][2].callback(zoom_rect(ax))),
    # #273: the figure's `fontsize` reaches every text the axis draws
    DecorationCase("issue_273", "+proj=eqearth", nothing, (; title = "fontsize 24", xlabel = "Longitude", ylabel = "Latitude");
        figure = (; fontsize = 24)),
    # #338: the graticule is drawn behind the plots, as on Axis
    DecorationCase("issue_338", "+proj=merc", ((-10, 30), (35, 60));
        setup = (fig, ax) -> scatter!(ax, [0.0, 10.0, 20.0], [40.0, 45.0, 50.0]; markersize = 30, color = :orange)),
]

"The dest-space rectangle a rectangle zoom onto the middle of the view hands the axis (#155)."
zoom_rect(ax) = (r = ax.finallimits[]; Rect2d(minimum(r) .+ 0.3 .* widths(r), 0.4 .* widths(r)))

const DECORATION_CASES = vcat(BASELINE_CASES, ISSUE_CASES, VARIANT_CASES, FANCY_CASES, LAYOUT_CASES, MINOR_CASES, MASK_CASES,
    CLOSURE_CASES, MOST_PROJECTION_CASES)

decoration_case(cases::Vector{DecorationCase}, name::AbstractString) = cases[findfirst(c -> c.name == name, cases)]

"A figure and a GeoAxis for the case, with coastlines (cut at the seams of its projection) plotted, and its `setup` run."
function build_case(c::DecorationCase; size = (600, 400), coastlines::Bool = true, attrs...)
    fig = Figure(; size, c.figure...)
    kw = c.limits === nothing ? (;) : (; limits = c.limits)
    ax = GeoAxis(fig[1, 1]; dest = c.dest, title = c.name, kw..., c.attrs..., attrs...)
    coastlines && lines!(ax, GeoMakie.coastlines(ax))
    Makie.update_state_before_display!(fig)
    # the setup is last and not followed by another `update_state_before_display!`,
    # which would reset the limits a zoom setup writes
    c.setup === nothing || c.setup(fig, ax)
    return fig, ax
end

# Figures with several blocks, for the layout predicates.

"The attributes a GeoAxis and an Axis must share for their protrusions to agree."
const PARITY_ATTRS = (; title = "Title", subtitle = "Subtitle", xlabel = "Longitude", ylabel = "Latitude",
    xticksize = 6.0, yticksize = 6.0, xticklabelpad = 5.0, yticklabelpad = 5.0)

"A GeoAxis on merc_reg beside an Axis with the same title, labels, tick strings and tick geometry."
function build_axis_parity(; size = (900, 420))
    fig = Figure(; size)
    ga = GeoAxis(fig[1, 1]; dest = "+proj=merc", limits = ((-10, 30), (35, 60)), PARITY_ATTRS...)
    lines!(ga, GeoMakie.coastlines(ga))
    Makie.update_state_before_display!(fig)
    d = GeoMakie.decorations(ga)
    lon = d.pixels.strings[:lon]; lat = d.pixels.strings[:lat]
    ax = Axis(fig[1, 2]; limits = (0, 1, 0, 1), xticks = (range(0, 1, length(lon)), lon), yticks = (range(0, 1, length(lat)), lat),
        PARITY_ATTRS...)
    Makie.update_state_before_display!(fig)
    return fig, ga, ax
end

"Issue 349: three lon/lat axes in a row, the y decorations hidden on the second and third."
function build_issue349(; size = (1200, 440))
    fig = Figure(; size)
    axes = GeoAxis[]
    for i in 1:3
        ax = GeoAxis(fig[1, i]; dest = "+proj=longlat +datum=WGS84", limits = ((-19, 55), (-38, 42)), title = "panel $i")
        lines!(ax, GeoMakie.coastlines(ax))
        i > 1 && hideydecorations!(ax; grid = false)
        push!(axes, ax)
    end
    Makie.update_state_before_display!(fig)
    return fig, axes
end

"Issue 268: a 2 x 2 grid of GeoAxes with lon/lat limits and no titles."
function build_issue268(; size = (800, 600))
    fig = Figure(; size)
    axes = [GeoAxis(fig[i, j]; limits = (-30, 55, -50, 80)) for i in 1:2, j in 1:2]
    foreach(ax -> lines!(ax, GeoMakie.coastlines(ax)), axes)
    Makie.update_state_before_display!(fig)
    return fig, vec(axes)
end

"The strings drawn on the frame for one family, in drawing order."
drawn_labels(d, family::Symbol) = d.pixels.strings[family]

"The interior labels drawn for one family."
interior_drawn(d, family::Symbol) = [l for l in d.labels[d.pixels.kept] if GeoMakie.isinterior(l) && l.exit.family == family]

"""
Every drawn graticule line of `family` has exactly one interior label, all on
one carrier (`carrier` when given).
"""
function interior_once(d, family::Symbol, carrier = nothing)
    lines = Set(l.value for l in d.graticule if l.family == family)
    ls = interior_drawn(d, family)
    vals = [l.exit.value for l in ls]
    carriers = unique(l.carrier for l in ls)
    return Set(vals) == lines && length(vals) == length(lines) && length(carriers) == 1 &&
        (carrier === nothing || carriers[1] == carrier)
end

# Floors: what a case must show at 600 x 400 with the default finder.  Each
# entry maps a case name to a function of the decorations returning a vector
# of (description, pass) pairs.
const SHORT_DECIMAL = r"^\d+(\.\d{1,3})?°[NSEW]?$"
const FLOORS = Dict{String, Function}(
    "robin150" => d -> [
        ("shows 0°", "0°" in drawn_labels(d, :lon)),
        ("shows 180°", "180°" in drawn_labels(d, :lon)),
    ],
    # the bottom (pole) edge carries every longitude in the tick set, without a drop
    "eqearth" => d -> [
        ("every longitude tick is drawn", Set(d.xtickvalues.values) == Set(l.exit.value for l in d.labels[d.pixels.kept] if l.exit.family == :lon)),
        ("bottom edge runs 180° … 180°", all(s -> s in drawn_labels(d, :lon), ("180°", "90°W", "0°", "90°E"))),
        ("no collision drop", !any(s -> s.reason == :collision, d.suppressed)),
    ],
    "ortho" => d -> [
        ("labels on the limb", length(d.pixels.kept) >= 10),
        ("both families on the limb", "0°" in drawn_labels(d, :lon) && "45°N" in drawn_labels(d, :lat)),
    ],
    "moll" => d -> [
        ("nothing drawn at the pole points", isempty(drawn_labels(d, :lon))),
        ("pole exits are reported convergent", count(s -> s.reason == :convergent && s.family == :lon, d.suppressed) >= 3),
        ("every meridian is labelled once on one carrier parallel", interior_once(d, :lon)),
        ("no interior latitude labels", isempty(interior_drawn(d, :lat))),
    ],
    # closed parallels: one interior label each, down the carrier meridian
    "laea_polar_nolimits" => d -> [
        ("every parallel is labelled once on the central meridian", interior_once(d, :lat, 0.0)),
        ("no interior longitude labels", isempty(interior_drawn(d, :lon))),
    ],
    # the 80°N circle is 35 px across at this size: the 27 px of arc between
    # two 45° meridians cannot hold "80°N" along the line, so it is reported
    "stere_polar" => d -> [
        ("50°N, 60°N and 70°N are labelled once on the central meridian, on their own circles",
            Set(l.text for l in interior_drawn(d, :lat)) == Set(["50°N", "60°N", "70°N"]) &&
            all(l -> l.carrier == 0.0, interior_drawn(d, :lat))),
        ("80°N is reported as crossed", [(s.value, s.reason) for s in d.suppressed if s.kind == :interior] == [(80.0, :crossed)]),
        ("no interior longitude labels", isempty(interior_drawn(d, :lon))),
    ],
    "laea_polar_c90" => d -> [
        ("the column moves to the 90°E meridian", interior_once(d, :lat, 90.0)),
        ("nothing is reported", !any(s -> s.kind == :interior, d.suppressed)),
    ],
    "merc_reg" => d -> [
        ("no interior labels", isempty(interior_drawn(d, :lon)) && isempty(interior_drawn(d, :lat))),
    ],
    # the coastline limits stop a degree short of the poles, so the viewport
    # cuts the meridians where they bunch towards the corners: the bottom exits
    # converge, the top ones are the other axis position's, and the meridians
    # are labelled along themselves instead
    "most_adams_hemi" => d -> [
        ("nothing drawn for longitudes at the frame", isempty([l for l in d.labels[d.pixels.kept] if l.exit.family == :lon && !GeoMakie.isinterior(l)])),
        ("bottom exits are reported convergent", all(s -> s.reason in (:convergent, :family, :noexit), filter(s -> s.family == :lon && s.kind == :frame, d.suppressed)) &&
            count(s -> s.family == :lon && s.reason == :convergent, d.suppressed) == 7),
        ("the seven meridians are labelled once each along themselves", interior_once(d, :lon) && length(interior_drawn(d, :lon)) == 7),
        ("no collision drop", !any(s -> s.reason == :collision, d.suppressed)),
    ],
    # a 0..3° view: every whole degree is a tick with both endpoints, at the
    # step each direction's room allows (the taller direction may go to 0.5°)
    "issue_234" => d -> [
        ("x values are exactly 0,1,2,3", d.xtickvalues.values == [0.0, 1.0, 2.0, 3.0]),
        ("y values are a:s:b with s dividing 1", d.ytickvalues.values == collect(0.0:d.ytickvalues.values[2]:3.0) && isinteger(1 / d.ytickvalues.values[2])),
        ("x labels", Set(drawn_labels(d, :lon)) == Set(["0°", "1°E", "2°E", "3°E"])),
        ("y labels", issubset(["0°", "1°N", "2°N", "3°N"], drawn_labels(d, :lat)) && length(drawn_labels(d, :lat)) == length(d.ytickvalues.values)),
    ],
    "issue_388" => d -> [
        ("zero meridian prints 0°", "0°" in drawn_labels(d, :lon)),
        ("no label reads 0.0°", !any(s -> occursin("0.0", s), drawn_labels(d, :lon))),
    ],
    "zoom3" => d -> [
        ("lon labels are short decimals", all(s -> occursin(SHORT_DECIMAL, s), drawn_labels(d, :lon))),
        ("lat labels are short decimals", all(s -> occursin(SHORT_DECIMAL, s), drawn_labels(d, :lat))),
        ("some label carries a decimal", any(s -> occursin('.', s), vcat(drawn_labels(d, :lon), drawn_labels(d, :lat)))),
    ],
    # ---- issue closure ----------------------------------------------------------
    "issue_317" => d -> [
        ("no label box touches the map body or the frame", isempty(nothing_inside("issue_317", d))),
        ("latitude labels are drawn", length(drawn_labels(d, :lat)) >= 4),
        ("longitude labels are drawn", length(drawn_labels(d, :lon)) >= 4),
        ("every latitude label sits outside the outline on the outward normal", isempty(placement_on_normal("issue_317", d))),
    ],
    "issue_190" => (d, ax) -> [
        ("no label box touches the disc", isempty(nothing_inside("issue_190", d))),
        ("latitude labels are on the limb", length(drawn_labels(d, :lat)) >= 3),
        # the meridians of an equatorial view all meet at the pole points on the
        # limb, so they are reported convergent and labelled along themselves
        # inside (the ±90° ones lie on the limb itself and are reported instead)
        ("meridians are labelled inside or reported, not piled at the poles",
            count(s -> s.family == :lon && s.reason == :convergent, d.suppressed) >= 2 &&
            "0°" in [l.text for l in interior_drawn(d, :lon)] &&
            all(v -> any(l -> l.exit.value == v, interior_drawn(d, :lon)) || any(s -> s.family == :lon && s.value == v && s.kind == :interior, d.suppressed),
                (l.value for l in d.graticule if l.family == :lon))),
        ("the labels clear the title and the axis labels", isempty(layout_no_collision("issue_190", [ax]))),
        ("the axis labels are drawn", ax.elements[:xlabel].visible[] && ax.elements[:ylabel].visible[] && d.axislabels.lon.extent > 0),
    ],
    "issue_350" => d -> [
        ("the user alignment reaches every latitude label",
            all(l -> l.align == (:right, :center) && !l.auto_align, [l for l in d.labels[d.pixels.kept] if l.exit.family == :lat])),
        ("the labels' right edges line up", let xs = [maximum(c[1] for c in GeoMakie.corners(d.pixels.boxes[k]))
                for (k, i) in enumerate(d.pixels.kept) if d.labels[i].exit.family == :lat && !GeoMakie.isinterior(d.labels[i])]
            length(xs) >= 3 && maximum(xs) - minimum(xs) <= 0.5
        end),
        ("labels of different widths are drawn", length(unique(length.(drawn_labels(d, :lat)))) >= 2),
    ],
    "issue_231" => d -> [
        ("the frame lies within the limits", isempty(frame_within_domain_and_limits("issue_231", d))),
        ("the equator is a :limit edge of the frame", :limit in GeoMakie.edge_tags(d.frame)),
        ("no graticule line lies south of the equator", all(l -> l.family != :lat || l.value >= 0, d.graticule) &&
            all(p -> p[2] >= -1e-6, (xyz_lat(d, p) for l in d.graticule for pc in l.pieces for p in pc))),
        ("no latitude label south of the equator", all(l -> l.exit.family != :lat || l.exit.value >= 0, d.labels[d.pixels.kept])),
        ("latitude labels are drawn", length(drawn_labels(d, :lat)) + length(interior_drawn(d, :lat)) >= 3),
    ],
    # the decision for #157: the scene's model transformation is part of the
    # plane the decorations are computed in (levels 2 and 3 of the graph), so
    # a south-up map labels its flipped edges and reserves its space on the
    # sides the labels are drawn on
    "issue_157" => d -> [
        ("the model reaches the decorations", d.model[2, 2] == -1 && d.transform isa GeoMakie.PlaneTransform),
        ("the same labels as right way up", Set(drawn_labels(d, :lat)) == Set(["45°S", "0°", "45°N"]) && "0°" in drawn_labels(d, :lon)),
        ("south is up: 45°S is drawn above 45°N", label_y(d, :lat, "45°S") > label_y(d, :lat, "0°") > label_y(d, :lat, "45°N")),
        ("no label box touches the map body", isempty(nothing_inside("issue_157", d))),
    ],
    "issue_339" => (d, ax) -> let other = only(filter(b -> b isa Axis, ax.parent.content))
        [
            ("the spine colour is the Axis's", ax.spinecolor[] == other.leftspinecolor[]),
            ("the spine width is the Axis's", ax.spinewidth[] == other.spinewidth[]),
            ("the grid colour is the Axis's", ax.xgridcolor[] == other.xgridcolor[] && ax.ygridcolor[] == other.ygridcolor[]),
            ("the grid width is the Axis's", ax.xgridwidth[] == other.xgridwidth[]),
            ("the spine plot draws in that colour", ax.elements[:spine].color[] == Makie.to_color(other.leftspinecolor[])),
        ]
    end,
    "issue_150" => d -> [
        ("no ticks, no graticule, no labels, no error", isempty(d.xtickvalues.values) && isempty(d.ytickvalues.values) &&
            isempty(d.graticule) && isempty(d.labels)),
        ("nothing is reserved for labels", d.bound.left == 0 && d.bound.bottom == 0),
    ],
    "issue_134" => d -> [
        ("latitude labels are drawn", length(drawn_labels(d, :lat)) >= 3),
        ("every latitude tick is drawn", Set(d.ytickvalues.values) == Set(l.exit.value for l in d.labels[d.pixels.kept] if l.exit.family == :lat)),
        ("every longitude tick is drawn", Set(d.xtickvalues.values) == Set(l.exit.value for l in d.labels[d.pixels.kept] if l.exit.family == :lon)),
        ("the ticks are whole degrees at a fine step", all(isinteger, d.ytickvalues.values) && length(d.ytickvalues.values) >= 5),
    ],
    "issue_155" => (d, ax) -> [
        ("the zoom took", d.finallimits == d.targetlimits && all(widths(d.finallimits) .< 0.5 .* widths(ax.graph[:view_bbox][]))),
        ("labels survive a rectangle zoom", length(drawn_labels(d, :lon)) >= 2 && length(drawn_labels(d, :lat)) >= 2),
        ("the labels are the zoomed extent's", all(l -> GeoMakie.lat_range(d.extent)[1] - 1e-6 <= l.exit.value <= GeoMakie.lat_range(d.extent)[2] + 1e-6,
            [l for l in d.labels[d.pixels.kept] if l.exit.family == :lat])),
    ],
    "issue_273" => (d, ax) -> [
        ("every size attribute inherits the figure's fontsize", all(==(24), (ax.titlesize[], ax.xlabelsize[], ax.ylabelsize[], ax.xticklabelsize[], ax.yticklabelsize[]))),
        ("the drawn text uses it", ax.elements[:xticklabels].fontsize[] == 24 && ax.elements[:xlabel].fontsize[] == 24 && ax.elements[:title].fontsize[] == 24),
        ("interior labels follow at 0.8×", d.interiorlabelsize.lon ≈ 0.8 * 24 && ax.elements[:xinteriorlabels].fontsize[] ≈ 0.8 * 24),
        ("the glyph boxes are measured at that size", all(l -> l.half == GeoMakie.text_half_extents(l.text, Makie.to_font(ax.graph[:fonts][], :regular), 24.0),
            filter(!GeoMakie.isinterior, d.labels))),
    ],
    "issue_338" => (d, ax) -> let sc = only(filter(p -> p isa Scatter, ax.scene.plots))
        [
            ("the graticule is behind the plot", isempty(grid_behind("issue_338", ax, sc))),
            ("the z order matches Axis: grid, plot, spine", Makie.zvalue2d(ax.elements[:xgrid]) < Makie.zvalue2d(sc) < Makie.zvalue2d(ax.elements[:spine])),
        ]
    end,
)

"The latitude of a world-space graticule point of `d` (through the inverse projection)."
xyz_lat(d, p) = Makie.apply_transform(Makie.inverse_transform(d.transform), Point2d(p))

"The pixel y of the first drawn frame label of `family` reading `text`."
function label_y(d, family, text)
    for (k, i) in enumerate(d.pixels.kept)
        l = d.labels[i]
        l.text == text && l.exit.family == family && !GeoMakie.isinterior(l) && return d.pixels.boxes[k].centre[2]
    end
    return NaN
end

"Run a floor: floors take the decorations, or the decorations and the axis."
floor_results(floor, d, ax) = hasmethod(floor, Tuple{Any, Any}) ? floor(d, ax) : floor(d)
