#=
# The decoration graph

Everything the axis derives from its projection lives in one ComputeGraph, so
each stage is computed once per change of its inputs and pulled on demand:

    1  transform          ← dest
    1  boundary           ← transform, outline, dest
    2  view               ← boundary, lonlat_limits
    2  rim_loops          ← view, transform            (the projected, unclipped rim)
    2  view_bbox          ← rim_loops                  → targetlimits (bridged)
    3  frame              ← rim_loops, finallimits
    3  spine              ← frame                      → lines!(spine)
    3  extent             ← frame, transform, view, finallimits
    3  carriers           ← view, transform, finallimits, extent, viewport, frame (a pole line caps the longitude interval)
    3  xtickvalues        ← xticks, extent, carriers, xticklabelsize   (ytickvalues likewise)
    3  graticule          ← x/ytickvalues, view, transform, finallimits, extent  → lines!(grid)
    2  rim_pieces         ← view                       (rim(view), for exit angles on the sphere)
    3  exits              ← graticule, frame, finallimits, rim_pieces
    3  crossings          ← carriers, x/ytickvalues, view, transform, finallimits, carriermeridian, carrierparallel
                            (where each graticule line meets the carrier lines interior labels sit beside)
    3  labels, suppressed ← exits, frame, finallimits, graticule, crossings, carriers, formats, fonts, sizes, pads,
                            tick sizes, rotations, aligns, x/yaxisposition, ticklabelminangle, ticklabelmingap, interiorlabels,
                            framestyle, framewidth (a fancy band pushes labels out by its width)
    3  protrusion_bound   ← labels, x/yticklabelsvisible, framestyle, framewidth   → layoutobservables.protrusions (bridged)
    4  pixels             ← frame, graticule, labels, projectionview, viewport, tick attributes, framestyle,
                            ticklabelmingap, ticklabelcollisions       → text! (frame and interior), linesegments! (no stubs when fancy),
                                                                         lines!(spine_px); the crowding report
    4  bands              ← frame, exits, projectionview, viewport, framestyle, framewidth, framecolors
                                                                       → poly!(band_polygons; color = band_colors)

`lonlat_limits` is the user's lon/lat limit rectangle (the whole sphere by
default); `reset_limits!` writes it.  Level 3 reads the viewport only to
size the tick interval (pixels per degree along a carrier); the protrusion
bound depends on which labels exist, not on where the viewport puts them.
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

"The tick values of one direction, with the labels the user supplied beside them (or `nothing`)."
struct TickSet
    values::Vector{Float64}
    labels::Union{Nothing, Vector{String}}
    minors::Vector{Float64}
end

"Pixels per dest unit of the scene: the viewport fitted to the limits."
function _pixel_scale(viewport, lims::Rect2d)
    w = widths(viewport); lw = widths(lims)
    (lw[1] > 0 && lw[2] > 0 && w[1] > 0 && w[2] > 0) || return 1.0
    return sqrt((w[1] / lw[1]) * (w[2] / lw[2]))
end

"""
    _tickset(finder, ext, carrier, px_scale, fontsize, family; cap = Inf)

The tick set of one direction.  `cap` is a second dest-space length the labels
must also fit along (a pole line, where meridian labels land on a
pseudocylindrical map); the interval is sized to the shorter of the two.
"""
function _tickset(finder, ext::Extent, carrier::Carrier, px_scale, fontsize, family::Symbol; cap::Real = Inf)
    range = family === :lon ? lon_range(ext) : lat_range(ext)
    carrier_px = carrier.length * px_scale
    if carrier.span > 0 && carrier_px > 0
        # the finder sees the extent's span; scale the carrier to it
        carrier_px *= (family === :lon ? lon_span(ext) : lat_span(ext)) / carrier.span
    end
    carrier_px = min(carrier_px, cap * px_scale)
    vals, minors = tickvalues(finder, range, carrier_px, fontsize; wrap = family === :lon)
    labels = ticklabels_of(finder)
    if labels === nothing && !(finder isa LadderTicks)
        # user ticks: keep what lies in the extent (any representation of a longitude)
        keep = family === :lon ?
            (ext.full_turn ? trues(length(vals)) : [_lon_in_range(v, ext.lon_lo, ext.lon_hi) for v in vals]) :
            [ext.lat_lo - 1e-9 <= v <= ext.lat_hi + 1e-9 for v in vals]
        vals = vals[keep]
    end
    return TickSet(vals, labels, minors === nothing ? Float64[] : minors)
end

_lon_in_range(v, lo, hi) = (w = mod(v - lo, 360.0); w <= hi - lo + 1e-9 || w >= 360 - 1e-9)

"Label strings keyed by tick value."
function _label_table(ts::TickSet, fmt, finder, family::Symbol)
    strs = format_tickvalues(fmt, finder, family, ts.values, ts.labels)
    d = Dict{Float64, String}()
    for (v, s) in zip(ts.values, strs)
        d[v] = s
    end
    return d
end

"""
    build_graph!(ax::GeoAxis) -> ComputeGraph

Create the axis' decoration graph, bridge `view_bbox` to `ax.targetlimits`, and
store it in `ax.graph`.
"""
function build_graph!(ax::GeoAxis)
    g = ComputePipeline.ComputeGraph()
    scene = ax.scene
    boxed(k, v) = Ref{Any}(v)
    # node types are fixed by their first value, so inputs and regions that may
    # change type are boxed in abstractly-typed refs
    ComputePipeline.add_input!(boxed, g, :dest, ax.dest)
    ComputePipeline.add_input!(boxed, g, :source, ax.source)
    ComputePipeline.add_input!(boxed, g, :outline, ax.outline)
    ComputePipeline.add_input!(g, :lonlat_limits, FULL_LONLAT)
    ComputePipeline.add_input!(g, :finallimits, ax.finallimits)
    ComputePipeline.add_input!(g, :viewport, scene.viewport)
    ComputePipeline.add_input!(g, :projectionview, scene.camera.projectionview)
    ComputePipeline.add_input!(g, :fonts, Makie.to_value(theme(ax.blockscene, :fonts)))
    for k in (:xticks, :yticks, :xtickformat, :ytickformat, :xticklabelalign, :yticklabelalign,
              :xticklabelfont, :yticklabelfont, :interiorlabels, :carriermeridian, :carrierparallel, :framecolors)
        ComputePipeline.add_input!(boxed, g, k, getproperty(ax, k))
    end
    for k in (:xticklabelsize, :yticklabelsize, :xticklabelpad, :yticklabelpad, :xticksize, :yticksize,
              :xticksvisible, :yticksvisible, :xtickalign, :ytickalign, :xticklabelrotation, :yticklabelrotation,
              :xticklabelsvisible, :yticklabelsvisible, :xaxisposition, :yaxisposition,
              :ticklabelminangle, :ticklabelmingap, :ticklabelcollisions, :ticklabelreport,
              :framestyle, :framewidth)
        ComputePipeline.add_input!(g, k, getproperty(ax, k))
    end
    # the band's width in pixels: what labels and the layout must clear beyond the frame
    ComputePipeline.map!(g, [:framestyle, :framewidth], :band) do style, width
        style === :fancy ? float(width) : 0.0
    end

    # ---- levels 1 and 2: the projection and the view --------------------------
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
    ComputePipeline.map!(g, [:view], :rim_pieces) do view
        rim(view)
    end

    # ---- level 3: the frame and everything on it (dest space) -----------------
    ComputePipeline.map!(g, [:rim_loops, :finallimits], :frame) do rl, lims
        clip_frame(rl, Rect2d(lims))
    end
    ComputePipeline.map!(g, [:frame], :spine) do f
        spine_points(f)
    end
    ComputePipeline.map!(g, [:frame, :transform, :view, :finallimits], :extent) do f, t, view, lims
        visible_extent(f, t, view, Rect2d(lims))
    end
    ComputePipeline.map!(g, [:view, :transform, :finallimits, :extent, :viewport, :frame], :carriers) do view, t, lims, ext, vp, f
        rect = Rect2d(lims)
        c = carriers(view, t, rect, ext, central_meridian(t); tol = frame_tolerance(rect))
        # meridian labels land on a pole line when the frame has one: size to it
        (; lon = c.lon, lat = c.lat, px_scale = _pixel_scale(vp, rect), pole_length = pole_line_length(f, ext))
    end
    ComputePipeline.map!(g, [:xticks, :extent, :carriers, :xticklabelsize], :xtickvalues) do finder, ext, c, size
        _tickset(finder, ext, c.lon, c.px_scale, size, :lon; cap = c.pole_length)
    end
    ComputePipeline.map!(g, [:yticks, :extent, :carriers, :yticklabelsize], :ytickvalues) do finder, ext, c, size
        _tickset(finder, ext, c.lat, c.px_scale, size, :lat)
    end
    ComputePipeline.map!(g, [:xtickvalues, :ytickvalues, :view, :transform, :finallimits, :extent],
                         [:graticule, :xgrid_points, :ygrid_points]) do xt, yt, view, t, lims, ext
        rect = Rect2d(lims)
        tol = frame_tolerance(rect)
        lon = graticule_lines(:lon, xt.values, view, t, rect, ext; tol)
        lat = graticule_lines(:lat, yt.values, view, t, rect, ext; tol)
        (vcat(lon, lat), graticule_points(lon), graticule_points(lat))
    end
    ComputePipeline.map!(g, [:graticule, :frame, :finallimits, :rim_pieces], :exits) do lines, f, lims, pieces
        exits(lines, f, Rect2d(lims), pieces)
    end
    # where each graticule line meets the carrier lines interior labels sit beside
    ComputePipeline.map!(g, [:carriers, :xtickvalues, :ytickvalues, :view, :transform, :finallimits,
                             :carriermeridian, :carrierparallel], :crossings) do c, xt, yt, view, t, lims, cm, cp
        rect = Rect2d(lims)
        lc = label_carriers(xt.values, yt.values, c.lat.value, c.lon.value, cm, cp)
        lat = carrier_crossings(:lat, yt.values, lc.meridian, view, t, rect)
        lon = [(p, carrier_crossings(:lon, xt.values, p, view, t, rect)) for p in lc.parallels]
        (; lat_carrier = lc.meridian, lat, lon)
    end
    ComputePipeline.map!(g, [:exits, :frame, :finallimits, :graticule, :crossings, :carriers,
                             :xtickvalues, :ytickvalues, :xticks, :yticks,
                             :xtickformat, :ytickformat, :fonts,
                             :xticklabelsize, :yticklabelsize, :xticklabelfont, :yticklabelfont,
                             :xticklabelpad, :yticklabelpad, :xticksize, :yticksize, :xticksvisible, :yticksvisible,
                             :xticklabelrotation, :yticklabelrotation, :xticklabelalign, :yticklabelalign,
                             :xaxisposition, :yaxisposition, :ticklabelminangle, :ticklabelmingap, :interiorlabels, :band],
                         [:labels, :suppressed]) do ex, f, lims, lines, crossings, c, xt, yt, xticks, yticks, xfmt, yfmt, fonts,
                                     xsize, ysize, xfont, yfont, xpad, ypad, xtsize, ytsize, xtvis, ytvis,
                                     xrot, yrot, xalign, yalign, xpos, ypos, minangle, mingap, interior, band
        attrs = (;
            lon = (; labels = _label_table(xt, xfmt, xticks, :lon), size = xsize, font = xfont, pad = xpad,
                     ticksize = xtsize, ticksvisible = xtvis, rotation = xrot, align = xalign),
            lat = (; labels = _label_table(yt, yfmt, yticks, :lat), size = ysize, font = yfont, pad = ypad,
                     ticksize = ytsize, ticksvisible = ytvis, rotation = yrot, align = yalign),
            fonts, xaxisposition = xpos, yaxisposition = ypos, minangle, band,
            interior = (; mode = interior, px_scale = c.px_scale, mingap),
        )
        place(ex, f, Rect2d(lims), lines, crossings, attrs)
    end
    ComputePipeline.map!(g, [:labels, :xticklabelsvisible, :yticklabelsvisible, :band], :protrusion_bound) do labels, xv, yv, band
        protrusion_bound(labels, (; lon = xv, lat = yv); base = band)
    end

    # ---- level 4: pixels ----------------------------------------------------------
    last_report = Ref("")
    ComputePipeline.map!(g, [:frame, :graticule, :labels, :suppressed, :projectionview, :viewport,
                             :xticksize, :yticksize, :xtickalign, :ytickalign, :xticksvisible, :yticksvisible,
                             :ticklabelmingap, :ticklabelcollisions, :ticklabelreport, :ticklabelminangle, :band],
                         [:pixels, :xlabel_positions, :xlabel_strings, :ylabel_positions, :ylabel_strings,
                          :xinterior_positions, :xinterior_strings, :yinterior_positions, :yinterior_strings,
                          :xstubs, :ystubs, :spine_px]) do f, lines, labels, sup3, pv, vp, xts, yts, xta, yta, xtv, ytv,
                                                mingap, collisions, report, minangle, band
        # the band's edges mark the ticks: no stubs on a fancy frame
        stubs = band == 0
        px = pixels(f, lines, labels, pv, vp,
            (; lon = (; size = xts, align = xta, visible = xtv && stubs), lat = (; size = yts, align = yta, visible = ytv && stubs));
            mingap, collisions)
        # the report is repeated only when what it says changes
        msg = suppression_report(vcat(sup3, px.suppressed), mingap, minangle)
        msg = something(msg, "")
        if msg != last_report[]
            last_report[] = msg
            isempty(msg) || report_suppressions(vcat(sup3, px.suppressed), report, mingap, minangle)
        end
        (px, px.positions[:lon], px.strings[:lon], px.positions[:lat], px.strings[:lat],
         px.interior_positions[:lon], px.interior_strings[:lon], px.interior_positions[:lat], px.interior_strings[:lat],
         px.stubs[:lon], px.stubs[:lat], closed_polylines(px.frame))
    end
    # the fancy band, swept along the frame in pixels between consecutive exits
    ComputePipeline.map!(g, [:frame, :exits, :projectionview, :viewport, :band, :framecolors],
                         [:bands, :band_polygons, :band_colors]) do f, ex, pv, vp, band, colors
        band > 0 || return (FrameBands(), Vector{Point2d}[], RGBAf[])
        m = PixelMap(pv, vp)
        loops = [Point2d[m(p) for p in lp] for lp in f.loops]
        epx = [(e.loop, e.edge, m(e.p)) for e in ex]
        b = frame_bands(loops, epx, band, RGBAf[Makie.to_color(c) for c in colors]; outward = pixel_orientation(m))
        (b, b.polygons, b.colors)
    end

    setfield!(ax, :graph, g)
    bbox_obs = ComputePipeline.get_observable!(g, :view_bbox; use_deepcopy = false)
    Observables.connect!(ax.targetlimits, bbox_obs)
    return g
end

"""
    decorations(ax::GeoAxis) -> NamedTuple

The axis' current decoration state, read back from the graph: the dest-space
`frame`, `extent`, tick sets, `graticule`, `exits`, `labels`, the protrusion
`bound`, the pixel-space `pixels`, and `suppressed` (every tick not drawn,
with its reason, from both levels), with `targetlimits`, `finallimits`,
`view`, `transform`, `viewport`, the carrier `crossings`, the
`interiorlabels` mode, the `framestyle` and the fancy `bands` beside them.
"""
decorations(ax::GeoAxis) = (;
    frame = ax.graph[:frame][],
    targetlimits = ax.targetlimits[],
    view = ax.graph[:view][],
    transform = ax.graph[:transform][],
    finallimits = ax.finallimits[],
    extent = ax.graph[:extent][],
    xticks = ax.graph[:xticks][],
    yticks = ax.graph[:yticks][],
    xtickvalues = ax.graph[:xtickvalues][],
    ytickvalues = ax.graph[:ytickvalues][],
    carriers = ax.graph[:carriers][],
    graticule = ax.graph[:graticule][],
    exits = ax.graph[:exits][],
    labels = ax.graph[:labels][],
    bound = ax.graph[:protrusion_bound][],
    pixels = ax.graph[:pixels][],
    suppressed = vcat(ax.graph[:suppressed][], ax.graph[:pixels][].suppressed),
    viewport = ax.scene.viewport[],
    projectionview = ax.scene.camera.projectionview[],
    xaxisposition = ax.xaxisposition[],
    yaxisposition = ax.yaxisposition[],
    crossings = ax.graph[:crossings][],
    interiorlabels = ax.interiorlabels[],
    framestyle = ax.framestyle[],
    bands = ax.graph[:bands][],
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
