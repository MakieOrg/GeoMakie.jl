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

"No drawn label's glyph box reaches into the map body, and nothing is drawn that was suppressed."
function nothing_inside(name, d)
    out = Violation[]
    px = d.pixels
    for (k, b) in enumerate(px.boxes)
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
