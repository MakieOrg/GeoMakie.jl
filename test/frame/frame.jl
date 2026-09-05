# Score the frame on every view.  On failure a PNG of the frame lands in
# test_images/frame/<label>.png.

const NORMAL_EPS_FRAC = 1e-3
const NORMAL_SAMPLE_MAX = 64
const VIEWPORT_ON_FRAC = 1e-6
const BBOX_TOL_FRAC = 0.01
const NORMAL_FLOOR = 0.88

xmin(r::Rect2d) = minimum(r)[1]; ymin(r::Rect2d) = minimum(r)[2]
xmax(r::Rect2d) = maximum(r)[1]; ymax(r::Rect2d) = maximum(r)[2]
in_rect(p, r::Rect2d; tol = 0.0) = xmin(r) - tol <= p[1] <= xmax(r) + tol && ymin(r) - tol <= p[2] <= ymax(r) + tol
function dist_to_rect_boundary(p, r::Rect2d)
    in_rect(p, r) && return min(p[1] - xmin(r), xmax(r) - p[1], p[2] - ymin(r), ymax(r) - p[2])
    return hypot(max(xmin(r) - p[1], 0.0, p[1] - xmax(r)), max(ymin(r) - p[2], 0.0, p[2] - ymax(r)))
end
function rect_inward_normal(p, r::Rect2d)
    d = (p[1] - xmin(r), xmax(r) - p[1], p[2] - ymin(r), ymax(r) - p[2])
    return (Vec2d(1, 0), Vec2d(-1, 0), Vec2d(0, 1), Vec2d(0, -1))[argmin(d)]
end
_norm2(v) = (n = hypot(v[1], v[2]); n < 1e-300 ? Vec2d(0, 0) : Vec2d(v[1] / n, v[2] / n))
rot90(v) = Vec2d(-v[2], v[1])

"Ground truth for a dest-space point being on the visible map: inside the rect and inverse-projecting into the view region."
function frame_inside(v::FrameView, p)
    in_rect(p, v.rect) || return false
    w = inverse_xyz(v.case.t, p)
    all(isfinite, w) || return false
    return contains(v.region, w)
end

function score_view(v::FrameView)
    cp = CountedProj(v.case.t)
    scale = view_scale(v)
    (fr, bbox), ncalls = count_proj_calls(() -> GM.frame(v.region, cp, v.rect))
    es = GM.edges(fr)
    eps = NORMAL_EPS_FRAC * scale
    # loops close and are traversed with the map on the left
    closed = all(lp -> length(lp) >= 3 && all(p -> all(isfinite, p), lp), fr.loops)
    areas = [GM._signed_area(lp) for lp in fr.loops]
    ccw = isempty(areas) ? NaN : sum(areas) > 0
    # normals: interior on the left, checked against the inverse projection
    good = 0; tot = 0
    scored = [e for e in es if !(e[3] in (:cut, :viewport))]
    step = max(1, cld(length(scored), NORMAL_SAMPLE_MAX))
    for e in scored[1:step:end]
        mid = Point2d(0.5 .* (e[1] .+ e[2]))
        d = _norm2(rot90(Vec2d(e[2] .- e[1])))
        tot += 1
        good += frame_inside(v, Point2d(mid .+ eps .* d)) && !frame_inside(v, Point2d(mid .- eps .* d))
    end
    normal_ok = tot == 0 ? NaN : good / tot
    vp = [e for e in es if e[3] == :viewport]
    vgood = 0
    for e in vp
        mid = Point2d(0.5 .* (e[1] .+ e[2]))
        dist_to_rect_boundary(mid, v.rect) <= VIEWPORT_ON_FRAC * scale || continue
        d = rect_inward_normal(mid, v.rect)
        vgood += frame_inside(v, Point2d(mid .+ eps .* d))
    end
    viewport_ok = isempty(vp) ? NaN : vgood / length(vp)
    ref = GM.rim_bbox(v.region, v.case.t)
    bbox_err = (ref === nothing || bbox === nothing) ? NaN :
        maximum(abs.((xmin(bbox) - xmin(ref), xmax(bbox) - xmax(ref), ymin(bbox) - ymin(ref), ymax(bbox) - ymax(ref)))) / scale
    inside_rect = all(p -> in_rect(p, v.rect; tol = 1e-6 * scale), Iterators.flatten(fr.loops))
    tags_ok = all(e -> e[3] in GM.FRAME_TAGS, es)
    return (; fr, bbox, ncalls, closed, ccw, normal_ok, viewport_ok, bbox_err, inside_rect, tags_ok,
        n_edges = length(es), n_loops = GM.nloops(fr))
end

const FRAME_PLOT_DIR = joinpath(@__DIR__, "..", "..", "test_images", "frame")

function plot_frame(fr, v::FrameView, path)
    isdefined(@__MODULE__, :CairoMakie) || return false
    colors = Dict(:limb => :dodgerblue, :limit => :green, :cut => :red, :pole => :purple, :viewport => :gray)
    fig = Figure(size = (800, 600))
    ax = Axis(fig[1, 1]; title = v.label, aspect = DataAspect())
    for e in GM.edges(fr)
        lines!(ax, [e[1], e[2]]; color = colors[e[3]], linewidth = 2)
    end
    r = v.rect
    lines!(ax, [Point2d(xmin(r), ymin(r)), Point2d(xmax(r), ymin(r)), Point2d(xmax(r), ymax(r)), Point2d(xmin(r), ymax(r)), Point2d(xmin(r), ymin(r))];
        color = :black, linestyle = :dash)
    mkpath(dirname(path))
    save(path, fig)
    return true
end

@testset "$(v.label)" for v in VIEWS
    open0 = GM.CHAIN_OPEN[]
    s = score_view(v)
    ok = s.closed && (isnan(s.ccw) || s.ccw) && s.tags_ok && s.inside_rect &&
        (isnan(s.normal_ok) || s.normal_ok >= NORMAL_FLOOR) &&
        (isnan(s.viewport_ok) || s.viewport_ok >= 0.9) &&
        (isnan(s.bbox_err) || s.bbox_err <= BBOX_TOL_FRAC) && GM.CHAIN_OPEN[] == open0
    ok || plot_frame(s.fr, v, joinpath(FRAME_PLOT_DIR, "$(v.label).png"))
    @test s.closed
    @test isnan(s.ccw) || s.ccw
    @test s.tags_ok
    @test s.inside_rect
    @test isnan(s.normal_ok) || s.normal_ok >= NORMAL_FLOOR
    @test isnan(s.viewport_ok) || s.viewport_ok >= 0.9
    @test isnan(s.bbox_err) || s.bbox_err <= BBOX_TOL_FRAC
    @test GM.CHAIN_OPEN[] == open0
    @test s.ncalls > 0
    @test s.n_edges > 0
end
