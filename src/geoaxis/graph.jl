#=
# The decoration graph

Everything the axis derives from its projection lives in one ComputeGraph, so
each stage is computed once per change of its inputs and pulled on demand:

    transform   ← dest
    boundary    ← transform, outline, dest
    view        ← boundary, lonlat_limits
    rim_loops   ← view, transform          (the projected, unclipped rim)
    view_bbox   ← rim_loops                → targetlimits (bridged)
    frame       ← rim_loops, finallimits
    spine       ← frame                    → lines!(spine)

`lonlat_limits` is the user's lon/lat limit rectangle (the whole sphere by
default); `reset_limits!` writes it.
=#

const FULL_LONLAT = Rect2d(-180.0, -90.0, 360.0, 180.0)
const LONLAT_CRS = "+proj=longlat +datum=WGS84"

"Is this source CRS plain WGS84 lon/lat (so limits are already lon/lat)?"
is_lonlat_source(sp) = sp == LONLAT_CRS || sp == "+proj=latlong +datum=WGS84 +type=crs" ||
    sp == GeoFormatTypes.EPSG(4326) || sp == "EPSG:4326"

"Bounding box of a rimless view (a whole-sphere domain): the projected lon/lat rect, minus the far cap."
function _rimless_bbox(view::SphereRegion, t, lonlat::Rect2d)
    xs = Float64[]; ys = Float64[]
    x0, y0 = minimum(lonlat); x1, y1 = maximum(lonlat)
    n = 65
    for i in 0:n, j in 0:n
        lon = x0 + (x1 - x0) * i / n
        lat = y0 + (y1 - y0) * j / n
        p = lonlat_to_xyz(lon, lat)
        contains(view, p) || continue
        q = project_lonlat(t, lon, lat)
        _finite2(q) || continue
        push!(xs, q[1]); push!(ys, q[2])
    end
    isempty(xs) && return Rect2d(0.0, 0.0, 1.0, 1.0)
    return _bbox(xs, ys)
end

"""
    build_graph!(ax::GeoAxis) -> ComputeGraph

Create the axis' decoration graph, bridge `view_bbox` to `ax.targetlimits`, and
store it in `ax.graph`.
"""
function build_graph!(ax::GeoAxis)
    g = ComputePipeline.ComputeGraph()
    # node types are fixed by their first value, so inputs and regions that may
    # change type are boxed in abstractly-typed refs
    ComputePipeline.add_input!((k, v) -> Ref{Any}(v), g, :dest, ax.dest)
    ComputePipeline.add_input!((k, v) -> Ref{Any}(v), g, :source, ax.source)
    ComputePipeline.add_input!((k, v) -> Ref{Any}(v), g, :outline, ax.outline)
    ComputePipeline.add_input!(g, :lonlat_limits, FULL_LONLAT)
    ComputePipeline.add_input!(g, :finallimits, ax.finallimits)

    ComputePipeline.map!(g, [:dest], :transform) do dest
        create_transform(dest, LONLAT_CRS)
    end
    ComputePipeline.map!(g, [:transform, :outline, :dest], :boundary) do t, outline, dest
        Ref{SphereRegion}(boundary(t, dest; outline))
    end
    ComputePipeline.map!(g, [:boundary, :lonlat_limits], :view) do b, lims
        q = Quadrangle(lims)
        Ref{SphereRegion}(isfullsphere(q) ? b : Intersection(b, q))
    end
    ComputePipeline.map!(g, [:view, :transform], :rim_loops) do view, t
        project_rim(view, t)
    end
    ComputePipeline.map!(g, [:rim_loops, :view, :transform, :lonlat_limits], :view_bbox) do rl, view, t, lims
        rl.bbox === nothing ? _rimless_bbox(view, t, lims) : rl.bbox
    end
    ComputePipeline.map!(g, [:rim_loops, :finallimits], :frame) do rl, lims
        clip_frame(rl, Rect2d(lims))
    end
    ComputePipeline.map!(g, [:frame], :spine) do f
        spine_points(f)
    end

    setfield!(ax, :graph, g)
    bbox_obs = ComputePipeline.get_observable!(g, :view_bbox; use_deepcopy = false)
    Observables.connect!(ax.targetlimits, bbox_obs)
    return g
end

"""
    decorations(ax::GeoAxis) -> NamedTuple

The axis' current decoration state: `frame`, `targetlimits`, `view`,
`transform` and `finallimits`.
"""
decorations(ax::GeoAxis) = (;
    frame = ax.graph[:frame][],
    targetlimits = ax.targetlimits[],
    view = ax.graph[:view][],
    transform = ax.graph[:transform][],
    finallimits = ax.finallimits[],
)

"""
    lonlat_limits_rect(axis, xlims, ylims) -> Rect2d

The lon/lat rectangle for user limits given in the source CRS (`nothing` for an
unspecified bound means the whole extent in that direction).
"""
function lonlat_limits_rect(axis::GeoAxis, xlims, ylims)
    sp = axis.source[]
    x0 = xlims === nothing || xlims[1] === nothing ? nothing : float(xlims[1])
    x1 = xlims === nothing || xlims[2] === nothing ? nothing : float(xlims[2])
    y0 = ylims === nothing || ylims[1] === nothing ? nothing : float(ylims[1])
    y1 = ylims === nothing || ylims[2] === nothing ? nothing : float(ylims[2])
    if !is_lonlat_source(sp) && !all(isnothing, (x0, x1, y0, y1))
        # limits are in the source CRS; carry them to lon/lat through the source rect
        src_full = Makie.apply_transform(create_transform(sp, LONLAT_CRS), FULL_LONLAT)
        rx0 = something(x0, minimum(src_full)[1]); rx1 = something(x1, maximum(src_full)[1])
        ry0 = something(y0, minimum(src_full)[2]); ry1 = something(y1, maximum(src_full)[2])
        ll = Makie.apply_transform(create_transform(LONLAT_CRS, sp), Rect2d(rx0, ry0, rx1 - rx0, ry1 - ry0))
        x0, y0 = minimum(ll); x1, y1 = maximum(ll)
    end
    lo = Vec2d(clamp(something(x0, -180.0), -540.0, 540.0), clamp(something(y0, -90.0), -90.0, 90.0))
    hi = Vec2d(clamp(something(x1, 180.0), -540.0, 540.0), clamp(something(y1, 90.0), -90.0, 90.0))
    return Rect2d(lo, hi - lo)
end
