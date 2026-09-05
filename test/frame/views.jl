# views.jl -- the view battery the frame is scored on: 9 cases x {full, zoom,
# limits} + polar for stere_n and ortho = 29 views.  A view is a region on the
# sphere and a dest-space rect.

struct FrameView
    case::Case
    region::GM.SphereRegion
    rect::Rect2d
    label::String
    kind::Symbol
end
Base.show(io::IO, v::FrameView) = print(io, "FrameView(", v.label, ")")

const FULL_PAD = 0.05
const ZOOM_ORIGIN = 0.45
const ZOOM_SIZE = 0.50
const POLAR_CASES = (:stere_n, :ortho)

widen(r::Rect2d, f) = Rect2d(minimum(r) .- f .* widths(r), widths(r) .* (1 + 2f))
subrect(r::Rect2d, ox, oy, wx, wy) = Rect2d(minimum(r) .+ Vec2d(ox, oy) .* widths(r), Vec2d(wx, wy) .* widths(r))

"The projected extent of a region: its rim's bbox, or a lon/lat grid when rimless."
function region_extent(region, t)
    rl = GM.project_rim(region, t)
    rl.bbox === nothing || return rl.bbox
    return GM._rimless_bbox(region, t, GM.FULL_LONLAT)
end

const _CASE_REGION = Dict{Symbol, GM.SphereRegion}()
case_region(c::Case) = get!(() -> GM.analytic_region(GM.identify(c.t)), _CASE_REGION, c.name)

function build_views(cases = CASES)
    out = FrameView[]
    for c in cases
        boundary = case_region(c)
        ext = region_extent(boundary, c.t)
        wide = widen(ext, FULL_PAD)
        push!(out, FrameView(c, boundary, wide, "$(c.name)_full", :full))
        push!(out, FrameView(c, boundary, subrect(ext, ZOOM_ORIGIN, ZOOM_ORIGIN, ZOOM_SIZE, ZOOM_SIZE), "$(c.name)_zoom", :zoom))
        push!(out, FrameView(c, GM.Intersection(boundary, GM.Quadrangle((20, 80), (30, 70))), wide, "$(c.name)_limits", :limits))
        if c.name in POLAR_CASES
            push!(out, FrameView(c, GM.Intersection(boundary, GM.Quadrangle((-180, 180), (60, 90))), wide, "$(c.name)_polar", :polar))
        end
    end
    return out
end

const VIEWS = build_views()
view_by_label(s::AbstractString) = VIEWS[findfirst(v -> v.label == s, VIEWS)]
view_scale(v::FrameView) = maximum(widths(region_extent(case_region(v.case), v.case.t)))
