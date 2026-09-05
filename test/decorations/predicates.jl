# predicates.jl -- structural checks on an axis' decorations.  Each returns a
# vector of `Violation`s; an empty vector is a pass.

struct Violation
    case::String
    check::Symbol
    detail::String
end
Base.show(io::IO, v::Violation) = print(io, v.case, " / ", v.check, ": ", v.detail)

"Every loop of the frame has at least three finite points."
function frame_closed(name, fr::GM.Frame)
    out = Violation[]
    for (k, lp) in enumerate(fr.loops)
        length(lp) >= 3 || push!(out, Violation(name, :frame_closed, "loop $k has $(length(lp)) points"))
        all(p -> all(isfinite, p), lp) || push!(out, Violation(name, :frame_closed, "loop $k has non-finite points"))
        length(fr.tags[k]) == length(lp) || push!(out, Violation(name, :frame_closed, "loop $k tags/points mismatch"))
    end
    all(t -> t in GM.FRAME_TAGS, GM.edge_tags(fr)) || push!(out, Violation(name, :frame_closed, "unknown tag"))
    return out
end

"""
Every frame point lies within the axis limits (to a thousandth of the extent),
and the midpoint of every non-viewport edge, nudged a hair to the map side,
inverse-projects into the view region.
"""
function frame_within_domain_and_limits(name, d)
    out = Violation[]
    fr = d.frame
    rect = d.finallimits
    scale = maximum(widths(rect))
    tol = 1e-3 * scale
    x0, y0 = minimum(rect); x1, y1 = maximum(rect)
    for lp in fr.loops, p in lp
        (x0 - tol <= p[1] <= x1 + tol && y0 - tol <= p[2] <= y1 + tol) ||
            (push!(out, Violation(name, :within_limits, "point $p outside $rect")); break)
    end
    inv = try
        Makie.inverse_transform(d.transform)
    catch
        nothing
    end
    inv === nothing && return out
    bad = 0; scored = 0
    for e in GM.edges(fr)
        e[3] in (:viewport, :cut) && continue
        mid = Point2d(0.5 .* (e[1] .+ e[2]))
        dir = e[2] .- e[1]
        n = hypot(dir[1], dir[2])
        n < 1e-300 && continue
        inward = Vec2d(-dir[2], dir[1]) ./ n
        q = Point2d(mid .+ (1e-3 * scale) .* inward)
        ll = try
            Makie.apply_transform(inv, q)
        catch
            continue
        end
        (isfinite(ll[1]) && isfinite(ll[2])) || continue
        scored += 1
        contains(d.view, GM.lonlat_to_xyz(ll[1], ll[2])) || (bad += 1)
    end
    scored > 0 && bad / scored > 0.12 && push!(out, Violation(name, :within_domain, "$bad of $scored edges have the map on the wrong side"))
    return out
end

"Counts of every tag in the frame."
tag_counts(fr::GM.Frame) = Dict(t => count(==(t), GM.edge_tags(fr)) for t in GM.FRAME_TAGS)

# ---- Phase 3: ticks, graticule and labels ------------------------------------

"""
Every ladder tick value is an exact multiple of a ladder step (no `0.0013°`),
lies within the visible extent, and its label is the formatter's string for
that exact value (never a number read off geometry).
"""
function exact_values(name, d)
    out = Violation[]
    for (family, ts, finder) in ((:lon, d.xtickvalues, d.xticks), (:lat, d.ytickvalues, d.yticks))
        finder isa GM.LadderTicks || continue
        lo, hi = family === :lon ? GM.lon_range(d.extent) : GM.lat_range(d.extent)
        for v in ts.values
            v == round(v; digits = 9) ||
                push!(out, Violation(name, :exact_values, "$family value $v is not a clean decimal"))
            any(s -> abs(v / s - round(v / s)) < 1e-9, finder.ladder) ||
                push!(out, Violation(name, :exact_values, "$family value $v is not a ladder multiple"))
            inside = family === :lon && d.extent.full_turn ? (-180 < v <= 180) :
                family === :lon ? GM._lon_in_range(v, lo, hi) : (lo - 1e-9 <= v <= hi + 1e-9)
            inside || push!(out, Violation(name, :exact_values, "$family value $v outside extent $((lo, hi))"))
        end
        expected = GM.format_tickvalues(Makie.automatic, finder, family, ts.values, nothing)
        for l in d.labels
            l.exit.family == family || continue
            i = findfirst(==(l.exit.value), ts.values)
            i === nothing && (push!(out, Violation(name, :exact_values, "label $(l.text) has no tick value")); continue)
            l.text == expected[i] ||
                push!(out, Violation(name, :exact_values, "label $(l.text) for $(ts.values[i]) should read $(expected[i])"))
        end
    end
    return out
end

"No drawn frame label's glyph box reaches into the map body, and nothing is drawn that was suppressed."
function nothing_inside(name, d)
    out = Violation[]
    px = d.pixels
    for (k, b) in enumerate(px.boxes)
        GM.isinterior(d.labels[px.kept[k]]) && continue
        GM.box_inside_map(b, px.frame) &&
            push!(out, Violation(name, :nothing_inside, "label $(px.strings) box $k at $(b.centre) is inside the map"))
    end
    length(px.kept) == length(px.boxes) ||
        push!(out, Violation(name, :nothing_inside, "kept/boxes mismatch"))
    isempty(intersect(px.kept, [s.index for s in px.suppressed])) ||
        push!(out, Violation(name, :nothing_inside, "a suppressed label was drawn"))
    return out
end

"""
Every drawn label's box centre lies on its exit's outward normal, past the
tick and the pad, and the normal points away from the map (the middle of the
exit's frame edge, nudged against the normal, is inside the frame).
"""
function placement_on_normal(name, d)
    out = Violation[]
    px = d.pixels
    for (k, i) in enumerate(px.kept)
        l = d.labels[i]
        GM.isinterior(l) && continue
        b = px.boxes[k]; e = px.exits[k]; n = px.normals[k]
        lp = px.frame[l.exit.loop]
        ea = lp[l.exit.edge]; eb = lp[mod1(l.exit.edge + 1, length(lp))]
        mid = Point2d(0.5 .* (ea .+ eb))
        nudge = min(2.0, 0.3 * norm(eb - ea))
        abs(norm(n) - 1) < 1e-9 || (push!(out, Violation(name, :placement_on_normal, "normal $n is not unit")); continue)
        v = b.centre - e
        along = v[1] * n[1] + v[2] * n[2]
        across = abs(-v[1] * n[2] + v[2] * n[1])
        across < 1e-6 || push!(out, Violation(name, :placement_on_normal, "$(l.text): centre is $across px off the normal"))
        along >= l.offset - 1e-6 || push!(out, Violation(name, :placement_on_normal, "$(l.text): box starts inside the pad"))
        abs(along - (l.offset + GM.half_extent(b, n))) < 1e-6 ||
            push!(out, Violation(name, :placement_on_normal, "$(l.text): box is not flush with the pad"))
        (nudge < 1e-6 || GM.inside_loops(px.frame, mid - nudge * n)) ||
            push!(out, Violation(name, :placement_on_normal, "$(l.text): normal at $e does not point away from the map"))
    end
    return out
end

"""
Every graticule piece lies within the limits rectangle, and the middle of
every piece inverse-projects into the view region.
"""
function graticule_within_frame(name, d)
    out = Violation[]
    rect = d.finallimits
    scale = maximum(widths(rect)); tol = 1e-3 * scale
    x0, y0 = minimum(rect); x1, y1 = maximum(rect)
    inv = try
        Makie.inverse_transform(d.transform)
    catch
        nothing
    end
    bad = 0; scored = 0
    for line in d.graticule, pc in line.pieces
        for p in pc
            (isfinite(p[1]) && isfinite(p[2])) || (push!(out, Violation(name, :graticule_within_frame, "non-finite point on $(line.family) $(line.value)")); break)
            (x0 - tol <= p[1] <= x1 + tol && y0 - tol <= p[2] <= y1 + tol) ||
                (push!(out, Violation(name, :graticule_within_frame, "$(line.family) $(line.value) leaves the limits at $p")); break)
        end
        inv === nothing && continue
        m = length(pc) ÷ 2
        m >= 1 || continue
        q = Point2d(0.5 .* (pc[m] .+ pc[m + 1]))
        ll = try
            Makie.apply_transform(inv, q)
        catch
            continue
        end
        (isfinite(ll[1]) && isfinite(ll[2])) || continue
        scored += 1
        contains(d.view, GM.lonlat_to_xyz(ll[1], ll[2])) || (bad += 1)
    end
    scored > 0 && bad / scored > 0.1 &&
        push!(out, Violation(name, :graticule_within_frame, "$bad of $scored pieces have their middle outside the view"))
    return out
end

"Building the same case twice gives the same tick values, label strings and pixel positions."
function determinism(c::DecorationCase; kw...)
    out = Violation[]
    fig1, ax1 = build_case(c; kw...)
    fig2, ax2 = build_case(c; kw...)
    d1 = GM.decorations(ax1); d2 = GM.decorations(ax2)
    d1.xtickvalues.values == d2.xtickvalues.values || push!(out, Violation(c.name, :determinism, "x tick values differ"))
    d1.ytickvalues.values == d2.ytickvalues.values || push!(out, Violation(c.name, :determinism, "y tick values differ"))
    [l.text for l in d1.labels] == [l.text for l in d2.labels] || push!(out, Violation(c.name, :determinism, "label strings differ"))
    d1.pixels.positions == d2.pixels.positions || push!(out, Violation(c.name, :determinism, "label positions differ"))
    d1.pixels.stubs == d2.pixels.stubs || push!(out, Violation(c.name, :determinism, "tick stubs differ"))
    return out
end

"Every Phase 3 predicate on one built case."
function phase3_violations(name, d)
    return vcat(exact_values(name, d), nothing_inside(name, d), placement_on_normal(name, d), graticule_within_frame(name, d))
end

# ---- Phase 4: family rule and crowding ---------------------------------------

"The drawn labels: `(label, box, exit px, normal px)` per kept index."
drawn(d) = [(d.labels[i], d.pixels.boxes[k], d.pixels.exits[k], d.pixels.normals[k]) for (k, i) in enumerate(d.pixels.kept)]

"""
On a straight `:viewport` edge every drawn label is of the family that edge
admits (longitudes on horizontal edges, latitudes on vertical ones), on a side
the axis positions name.
"""
function family_rule(name, d)
    out = Violation[]
    for (l, _, _, _) in drawn(d)
        e = l.exit
        e.tag === :viewport || continue
        side = GM.edge_side(e.normal)
        horizontal = side === :bottom || side === :top
        want = horizontal ? :lon : :lat
        e.family === want ||
            push!(out, Violation(name, :family_rule, "$(l.text) ($(e.family)) on the $side viewport edge"))
        pos = horizontal ? d.xaxisposition : d.yaxisposition
        (pos === :both || pos === side) ||
            push!(out, Violation(name, :family_rule, "$(l.text) on the $side edge, axis position $pos"))
    end
    return out
end

"""
No two drawn labels beside each other, pushed out the same way, print the same
text for different families (`0°` for the equator next to `0°` for the prime
meridian).  Labels on normals more than 45° apart sit on different sides of a
corner, where position tells the family, as on an `Axis`.
"""
function no_ambiguity(name, d)
    out = Violation[]
    ls = drawn(d)
    for i in eachindex(ls), j in (i + 1):length(ls)
        a, b = ls[i], ls[j]
        a[1].text == b[1].text || continue
        a[1].exit.family == b[1].exit.family && continue
        a[4] ⋅ b[4] > cosd(45) || continue
        reach = 2 * max(maximum(a[2].half), maximum(b[2].half))
        norm(a[3] - b[3]) < reach &&
            push!(out, Violation(name, :no_ambiguity, "$(a[1].text) drawn for both families at $(a[3])"))
    end
    return out
end

"No two drawn glyph boxes intersect."
function no_overlap(name, d)
    out = Violation[]
    bx = d.pixels.boxes
    for i in eachindex(bx), j in (i + 1):length(bx)
        GM.collides(bx[i], bx[j]) &&
            push!(out, Violation(name, :no_overlap, "$(d.labels[d.pixels.kept[i]].text) and $(d.labels[d.pixels.kept[j]].text) overlap"))
    end
    return out
end

"""
With a ladder finder no label of a family is dropped for colliding with
another label of the same family: the finder's interval prevents it.  Two
families sharing a curved edge may still meet; those drops are resolved by
priority and reported.
"""
function crowding_zero_with_default_finder(name, d)
    out = Violation[]
    for s in d.suppressed
        s.reason === :collision || continue
        finder = s.family === :lon ? d.xticks : d.yticks
        finder isa GM.LadderTicks || continue
        h = d.labels[s.hit].exit
        h.family === s.family || continue
        push!(out, Violation(name, :crowding, "$(s.family) $(s.value) dropped against $(s.family) $(h.value)"))
    end
    return out
end

"Every tick value is drawn or in the suppression report."
function every_absent_tick_reported(name, d)
    out = Violation[]
    shown = Set((l.exit.family, l.exit.value) for (l, _, _, _) in drawn(d))
    reported = Set((s.family, s.value) for s in d.suppressed)
    for (family, ts) in ((:lon, d.xtickvalues), (:lat, d.ytickvalues)), v in ts.values
        ((family, v) in shown || (family, v) in reported) ||
            push!(out, Violation(name, :every_absent_tick_reported, "$family $v is neither drawn nor reported"))
    end
    return out
end

"Every Phase 4 predicate on one built case."
function phase4_violations(name, d)
    return vcat(family_rule(name, d), no_ambiguity(name, d), no_overlap(name, d),
        crowding_zero_with_default_finder(name, d), every_absent_tick_reported(name, d))
end

# ---- Phase 5: interior labels -------------------------------------------------

"The pixel pieces of every graticule line as `(family, value, piece)`, in the order `pixels` stores them."
function graticule_pieces_px(d)
    out = Tuple{Symbol, Float64, Vector{Point2d}}[]
    for family in (:lon, :lat)
        k = 0
        for l in d.graticule
            l.family == family || continue
            for _ in l.pieces
                k += 1
                push!(out, (family, l.value, d.pixels.graticule[family][k]))
            end
        end
    end
    return out
end

"The pixel pieces of one graticule line."
own_pieces_px(pieces, family, value) = [pc for (pf, pv, pc) in pieces if (pf, pv) == (family, value)]

"Distance from `q` to the nearest segment of the polylines."
function polylines_distance(pieces, q)
    best = Inf
    for pc in pieces, i in 1:(length(pc) - 1)
        best = min(best, GM._seg_dist(q, pc[i], pc[i + 1]))
    end
    return best
end

"The direction of the segment of the polylines nearest to `q`."
function polylines_direction(pieces, q)
    best = Inf; dir = Vec2d(1, 0)
    for pc in pieces, i in 1:(length(pc) - 1)
        d = GM._seg_dist(q, pc[i], pc[i + 1])
        d < best || continue
        e = pc[i + 1] - pc[i]
        n = norm(e)
        n > 0 && (best = d; dir = Vec2d(e / n))
    end
    return dir
end

"""
Every drawn interior label belongs to a line with no frame candidate (unless
interior labels are forced on), hangs from the crossing of its line with its
carrier, sits on its own line (the line passes through its box, or touches
the box shifted off the line by `INTERIOR_SHIFT_GAP` of the pad) turned along
it (or at the fixed `interiorlabelrotation`), lies wholly on the map, clears
its crossing and the carrier by the pad, and crosses no other graticule line.
"""
function interior_labels(name, d)
    out = Violation[]
    px = d.pixels
    framed = Set((l.exit.family, l.exit.value) for l in d.labels if !GM.isinterior(l))
    pieces = graticule_pieces_px(d)
    extent = maximum(widths(d.finallimits))
    for (k, i) in enumerate(px.kept)
        l = d.labels[i]
        GM.isinterior(l) || continue
        b = px.boxes[k]
        fam, v = l.exit.family, l.exit.value
        (d.interiorlabels === :all || !((fam, v) in framed)) ||
            push!(out, Violation(name, :interior_labels, "$(l.text) has a frame candidate"))
        isfinite(l.carrier) || push!(out, Violation(name, :interior_labels, "$(l.text) has no carrier"))
        # the anchor is the projection of the crossing of the line with its carrier
        lon, lat = fam === :lon ? (v, l.carrier) : (l.carrier, v)
        p = Makie.apply_transform(d.transform, Point2d(lon, lat))
        (all(isfinite, p) && norm(p - l.anchor) <= 1e-6 * extent) ||
            push!(out, Violation(name, :interior_labels, "$(l.text) anchor $(l.anchor) is not at ($lon, $lat) = $p on its carrier $(l.carrier)"))
        # on its own line, turned along it
        own = own_pieces_px(pieces, fam, v)
        slack = GM.INTERIOR_SHIFT_GAP * l.offset + 0.01
        any(pc -> GM.polyline_crosses_box(GM.inflate(b, slack), pc, GM._aabb(pc)), own) ||
            push!(out, Violation(name, :interior_labels, "$(l.text) box at $(b.centre) is not on its line ($(polylines_distance(own, b.centre)) px away)"))
        if d.interiorlabelrotation isa Makie.Automatic
            dir = polylines_direction(own, b.centre)
            axis = Vec2d(cos(b.θ), sin(b.θ))
            abs(axis ⋅ dir) >= cosd(3) ||
                push!(out, Violation(name, :interior_labels, "$(l.text) is turned $(rad2deg(b.θ))°, its line runs at $(rad2deg(atan(dir[2], dir[1])))°"))
            -pi / 2 < b.θ <= pi / 2 || push!(out, Violation(name, :interior_labels, "$(l.text) is not upright ($(rad2deg(b.θ))°)"))
        else
            b.θ == float(d.interiorlabelrotation) || push!(out, Violation(name, :interior_labels, "$(l.text) ignores the fixed rotation"))
        end
        GM.box_within_loops(b, px.frame) || push!(out, Violation(name, :interior_labels, "$(l.text) box is not wholly on the map"))
        other = fam === :lon ? :lat : :lon
        for (pf, pv, pc) in pieces
            (pf, pv) == (fam, v) && continue
            GM.polyline_crosses_box(b, pc, GM._aabb(pc)) &&
                (push!(out, Violation(name, :interior_labels, "$(l.text) box crosses $pf $pv")); break)
            (pf, pv) == (other, l.carrier) || continue
            GM.polyline_crosses_box(GM.inflate(b, l.offset - 0.01), pc, GM._aabb(pc)) &&
                (push!(out, Violation(name, :interior_labels, "$(l.text) box is within the pad of its carrier")); break)
        end
        # the box clears the crossing by the pad
        q = GM._to_local(b, px.exits[k])
        dist = norm(max.(abs.(q) .- b.half, 0.0))
        dist >= l.offset - 0.01 ||
            push!(out, Violation(name, :interior_labels, "$(l.text) box sits $(dist) px from its crossing, within the pad $(l.offset)"))
    end
    return out
end

"Every Phase 5 predicate on one built case."
phase5_violations(name, d) = interior_labels(name, d)

# ---- Phase 6: the fancy band and the grid's z-order -----------------------------

"""
On a `:fancy` frame every tick exit (`band_exits`) is a band boundary (within
a pixel), every boundary is at an exit or a run corner (except the one a
single-run loop may add to keep two colours alternating around an odd count),
consecutive bands of one run never share a colour (nor the closing pair of a
single-run loop), every run corner of the frame has a corner cell outside
the map, and every corner touches exactly two runs.  A `:plain` frame has no
bands.
"""
function frame_band(name, d)
    out = Violation[]
    b = d.bands
    if d.framestyle !== :fancy
        (isempty(b.polygons) && isempty(b.cells)) || push!(out, Violation(name, :frame_band, "a plain frame has $(length(b.polygons)) bands"))
        return out
    end
    m = GM.PixelMap(d.projectionview, d.viewport)
    marks = [m(e.p) for e in GM.band_exits(d.exits, d.finallimits, d.ticklabelminangle)]
    allb = reduce(vcat, b.boundaries; init = Point2d[])
    length(b.polygons) == length(allb) == length(b.colors) == length(b.loop) == length(b.run) ||
        push!(out, Violation(name, :frame_band, "$(length(b.polygons)) bands for $(length(allb)) boundaries"))
    length(b.cells) == length(b.corners) == length(b.cell_loop) ||
        push!(out, Violation(name, :frame_band, "$(length(b.cells)) cells for $(length(b.corners)) corners"))
    near(p, pts) = minimum(norm(p - q) for q in pts; init = Inf) <= 1.0 + 1e-6
    for p in marks
        near(p, allb) || push!(out, Violation(name, :frame_band, "exit at $p is not a band boundary"))
    end
    for (k, pts) in enumerate(b.boundaries)
        corners = b.corners[b.cell_loop .== k]
        want = [m(d.frame.loops[k][j]) for j in GM.run_corners([m(p) for p in d.frame.loops[k]], d.frame.tags[k], d.frame.source[k])]
        (length(corners) == length(want) && all(c -> minimum(norm(c - w) for w in want; init = Inf) <= 1e-6, corners)) ||
            push!(out, Violation(name, :frame_band, "loop $k has corners $corners, its runs meet at $want"))
        for (i, q) in enumerate(pts)
            i == b.extra[k] && continue
            (near(q, marks) || near(q, corners)) ||
                push!(out, Violation(name, :frame_band, "boundary $i of loop $k at $q is not at an exit or a corner"))
        end
        idx = findall(==(k), b.loop)
        n = length(idx)
        for a in 1:n
            c = mod1(a + 1, n)
            (n >= 2 && b.run[idx[a]] == b.run[idx[c]] && b.colors[idx[a]] == b.colors[idx[c]]) &&
                push!(out, Violation(name, :frame_band, "bands $a and $c of loop $k share a colour"))
        end
        isempty(corners) || length(unique(b.run[idx])) == length(corners) ||
            push!(out, Violation(name, :frame_band, "loop $k has $(length(corners)) corners but $(length(unique(b.run[idx]))) runs"))
        # every corner starts exactly one band, and the band ending there is of another run
        for c in corners
            starts = findall(q -> norm(q - c) <= 1e-6, pts)
            length(starts) == 1 || (push!(out, Violation(name, :frame_band, "corner $c starts $(length(starts)) bands")); continue)
            a = starts[1]; prev = mod1(a - 1, n)
            b.run[idx[a]] != b.run[idx[prev]] || push!(out, Violation(name, :frame_band, "corner $c lies inside run $(b.run[idx[a]])"))
        end
    end
    for (i, poly) in enumerate(b.polygons)
        (length(poly) >= 4 && all(p -> all(isfinite, p), poly)) ||
            push!(out, Violation(name, :frame_band, "band $i is degenerate"))
    end
    for (i, cell) in enumerate(b.cells)
        (length(cell) >= 3 && all(p -> all(isfinite, p), cell)) ||
            (push!(out, Violation(name, :frame_band, "corner cell $i is degenerate")); continue)
        cell[1] == b.corners[i] || push!(out, Violation(name, :frame_band, "corner cell $i does not start at its corner"))
        GM.inside_loops(d.pixels.frame, sum(cell) / length(cell)) &&
            push!(out, Violation(name, :frame_band, "corner cell $i lies on the map"))
    end
    return out
end

"The graticule is drawn behind `plot` when `gridbehind` is set, in front of it otherwise."
function grid_behind(name, ax, plot)
    out = Violation[]
    z = Makie.zvalue2d(plot)
    for k in (:xgrid, :ygrid)
        zg = Makie.zvalue2d(ax.elements[k])
        ok = ax.gridbehind[] ? zg < z : zg > z
        ok || push!(out, Violation(name, :grid_behind, "$k at z = $zg, plot at z = $z, gridbehind = $(ax.gridbehind[])"))
    end
    return out
end

"Every Phase 6 predicate on one built case."
phase6_violations(name, d) = frame_band(name, d)

# ---- Phase 7: the layout ----------------------------------------------------------

"The drawn text of a block-scene text plot as an axis-aligned box in pixels, or `nothing` when it is blank or hidden."
function text_box(plot, label = first(plot.text[]))
    plot.visible[] || return nothing
    Makie.iswhitespace(label) && return nothing
    bb = Makie.boundingbox(plot, :data)
    w = widths(bb)
    (all(isfinite, w) && w[1] > 0 && w[2] > 0) || return nothing
    o = minimum(bb)
    return GM.OBox(Point2d(o[1] + w[1] / 2, o[2] + w[2] / 2), Vec2d(w[1] / 2, w[2] / 2), 0.0)
end

"A rectangle as an axis-aligned box."
rect_box(r) = (w = widths(r); o = minimum(r); GM.OBox(Point2d(o[1] + w[1] / 2, o[2] + w[2] / 2), Vec2d(w[1] / 2, w[2] / 2), 0.0))

"The axis' title, subtitle and axis labels as `(name, box)` pairs, drawn ones only."
function layout_text_boxes(ax)
    out = Tuple{Symbol, GM.OBox}[]
    for k in (:title, :subtitle, :xlabel, :ylabel)
        b = text_box(ax.elements[k], getproperty(ax, k)[])
        b === nothing || push!(out, (k, b))
    end
    return out
end

"""
No drawn tick label box touches the title, subtitle or axis labels of any
axis in `axes`, the map viewport of another axis, or another axis' tick
labels and layout text.
"""
function layout_no_collision(name, axes::Vector{GeoAxis})
    out = Violation[]
    boxes = [(i, k, b) for (i, ax) in enumerate(axes) for (k, b) in enumerate(GM.decorations(ax).pixels.boxes)]
    texts = [(i, k, b) for (i, ax) in enumerate(axes) for (k, b) in layout_text_boxes(ax)]
    text_of(i, k) = GM.decorations(axes[i]).labels[GM.decorations(axes[i]).pixels.kept[k]].text
    for (i, k, b) in boxes
        for (j, t, tb) in texts
            GM.collides(b, tb) && push!(out, Violation(name, :layout_no_collision, "axis $i label $(text_of(i, k)) touches axis $j $t"))
        end
        for (j, other) in enumerate(axes)
            j == i && continue
            GM.collides(b, rect_box(other.scene.viewport[])) &&
                push!(out, Violation(name, :layout_no_collision, "axis $i label $(text_of(i, k)) lies over axis $j"))
        end
        for (j, m, ob) in boxes
            (j == i || (j, m) <= (i, k)) && continue
            GM.collides(b, ob) &&
                push!(out, Violation(name, :layout_no_collision, "axis $i label $(text_of(i, k)) touches axis $j label $(text_of(j, m))"))
        end
    end
    # the subtitle sits flush under the title (`subtitlegap = 0`, as on `Axis`), so
    # texts collide only when they overlap
    for (i, s, sb) in texts, (j, t, tb) in texts
        (i, s) < (j, t) || continue
        GM.collides(sb, tb; gap = -1e-3) && push!(out, Violation(name, :layout_no_collision, "axis $i $s touches axis $j $t"))
    end
    return out
end

"How far a box reaches past `side` of the rectangle `vp`."
function overhang(b::GM.OBox, vp, side::Symbol)
    x0, y0 = minimum(vp); x1, y1 = maximum(vp)
    cs = GM.corners(b)
    side === :left && return maximum(x0 - c[1] for c in cs)
    side === :right && return maximum(c[1] - x1 for c in cs)
    side === :bottom && return maximum(y0 - c[2] for c in cs)
    return maximum(c[2] - y1 for c in cs)
end

"""
The outermost extent of every drawn decoration per side: the tick reach
(labels, stubs, band, each counting toward the sides its normal faces), the
axis labels on their sides, and the title and subtitle on top.
"""
function drawn_extent(ax)
    d = GM.decorations(ax)
    vp = d.viewport
    m = GM.measured_reach(d.pixels, d.labels, ax.graph[:band_polygons][], vp;
                          visible = (; lon = ax.xticklabelsvisible[], lat = ax.yticklabelsvisible[]))
    ext = Dict(:left => Float64(m.left), :right => Float64(m.right), :bottom => Float64(m.bottom), :top => Float64(m.top))
    sides = Dict(:title => :top, :subtitle => :top, :xlabel => d.axislabels.lon.side, :ylabel => d.axislabels.lat.side)
    for (k, b) in layout_text_boxes(ax)
        s = sides[k]
        ext[s] = max(ext[s], overhang(b, vp, s))
    end
    return GM.GridLayoutBase.RectSides{Float32}(ext[:left], ext[:right], ext[:bottom], ext[:top])
end

"""
The layout reserved at least the outermost drawn extent on every side and no
more than the dest-space bound (plus axis labels and title); after
`tight_ticklabel_spacing!` (`tight = true`) reserved and drawn agree to `tol`.
"""
function layout_protrusions(name, ax; tight::Bool = false, tol = 0.5)
    out = Violation[]
    d = GM.decorations(ax)
    reserved = ax.layoutobservables.protrusions[]
    drawn = drawn_extent(ax)
    bound = GM.with_title(GM.reach_sides(d.bound, nothing, (d.axislabels.lon, d.axislabels.lat)), d.titlespace, d.subtitlespace)
    reserved == d.protrusions || push!(out, Violation(name, :layout_protrusions, "the layout holds $reserved, the graph says $(d.protrusions)"))
    for side in (:left, :right, :bottom, :top)
        r = GM.side_value(reserved, side); e = GM.side_value(drawn, side); b = GM.side_value(bound, side)
        r >= e - 1e-3 || push!(out, Violation(name, :layout_protrusions, "$side reserves $r for a drawn extent of $e"))
        r <= b + 1e-3 || push!(out, Violation(name, :layout_protrusions, "$side reserves $r beyond the bound $b"))
        tight && abs(r - e) > tol && push!(out, Violation(name, :layout_protrusions, "$side reserves $r after tightening, drawn $e"))
    end
    return out
end

"The `Axis` plot that draws `k` (`:title`, `:subtitle`, `:xlabel`, `:ylabel`); the subtitle is found by its text."
function axis_text_plot(ax::Axis, k::Symbol)
    k === :title && return ax.elements[:title]
    k === :xlabel && return ax.xaxis.elements[:labeltext]
    k === :ylabel && return ax.yaxis.elements[:labeltext]
    i = findfirst(p -> p isa Makie.Text && first(p.text[]) == ax.subtitle[], ax.blockscene.plots)
    return ax.blockscene.plots[i]
end

"""
A `GeoAxis` and an `Axis` with the same title, subtitle, axis labels, tick
label strings and tick geometry on a rectangular frame report the same
protrusions within a pixel.
"""
function axis_parity(name)
    out = Violation[]
    fig, ga, ax = build_axis_parity()
    pg = ga.layoutobservables.protrusions[]; pa = ax.layoutobservables.protrusions[]
    for side in (:left, :right, :bottom, :top)
        g = GM.side_value(pg, side); a = GM.side_value(pa, side)
        abs(g - a) <= 1.0 || push!(out, Violation(name, :axis_parity, "$side: GeoAxis $g, Axis $a"))
    end
    # the title, subtitle and axis labels sit at the same heights and offsets;
    # `Axis` draws its axis labels a spine width further out than it reserves
    # (`labelgap` counts the spine, `calculate_protrusion` does not), which the
    # GeoAxis does not copy, so that width is allowed for
    spine = ax.spinewidth[]
    for k in (:title, :subtitle, :xlabel)
        bg = text_box(ga.elements[k], getproperty(ga, k)[]); ba = text_box(axis_text_plot(ax, k), getproperty(ax, k)[])
        (bg === nothing || ba === nothing) && continue
        ya = ba.centre[2] + (k === :xlabel ? spine : 0.0)
        abs(bg.centre[2] - ya) <= 1.0 || push!(out, Violation(name, :axis_parity, "$k sits at $(bg.centre[2]) on the GeoAxis, $(ba.centre[2]) on the Axis"))
    end
    bg = text_box(ga.elements[:ylabel], ga.ylabel[]); ba = text_box(axis_text_plot(ax, :ylabel), ax.ylabel[])
    if bg !== nothing && ba !== nothing
        og = minimum(ga.scene.viewport[])[1] - bg.centre[1]; oa = minimum(ax.scene.viewport[])[1] - ba.centre[1] - spine
        abs(og - oa) <= 1.0 || push!(out, Violation(name, :axis_parity, "ylabel sits $og left of the GeoAxis, $oa left of the Axis"))
    end
    return out
end

"Every Phase 7 predicate on one built axis."
phase7_violations(name, ax; tight::Bool = false) = vcat(layout_no_collision(name, [ax]), layout_protrusions(name, ax; tight))
