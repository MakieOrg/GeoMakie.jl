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
