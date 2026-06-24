# Generator for `docs/src/projections.md`.
#
# This is the **single source of truth** for the projection gallery page. Edit the
# `PROJECTION_SECTIONS` list (or the prose constants) below — NOT the generated markdown, which
# `make.jl` overwrites on every build via `generate_projections(...)`.
#
# Why generate it? We want every panel to show a *self-contained, copy-pasteable* code cell above
# its figure (so a reader can reproduce any projection), but hand-maintaining ~110 near-identical
# `@example` blocks is error-prone. Keeping the data here and emitting the markdown gives us both:
# one short list to maintain, and fully spelled-out code on the page.

# (section title, payload): payload is a single PROJ string for a plain section, or a vector of
# (tab label, PROJ string) for a tabbed family. Order is preserved as the page order.
const PROJECTION_SECTIONS = [
    ("Adams projections", [
        ("Hemisphere in a square", "+proj=adams_hemi"),
        ("World in a square I", "+proj=adams_ws1"),
        ("World in a square II", "+proj=adams_ws2"),
    ]),
    ("Albers Equal-Area Conic", "+proj=aea +lat_1=29.5 +lat_2=42.5"),
    ("Azimuthal Equidistant", "+proj=aeqd"),
    ("Airy", "+proj=airy"),
    ("Aitoff", "+proj=aitoff"),
    ("Apian Globular I", "+proj=apian"),
    ("August Epicycloidal", "+proj=august"),
    ("Bacon Globular", "+proj=bacon"),
    ("Bertin 1953", "+proj=bertin1953"),
    ("Bipolar Conic", "+proj=bipc +ns"),
    ("Boggs Eumorphic", "+proj=boggs"),
    ("Bonne", "+proj=bonne +lat_1=10"),
    ("Cylindrical Equal-Area", "+proj=cea"),
    ("Chamberlin Trimetric", "+proj=chamb +lat_1=10 +lon_1=30 +lon_2=40"),
    ("Collignon", "+proj=collg"),
    ("Compact Miller", "+proj=comill"),
    ("Craster Parabolic", "+proj=crast"),
    ("Denoyer Semi-Elliptical", "+proj=denoy"),
    ("Eckert", [
        ("I", "+proj=eck1"),
        ("II", "+proj=eck2"),
        ("III", "+proj=eck3"),
        ("IV", "+proj=eck4"),
        ("V", "+proj=eck5"),
        ("VI", "+proj=eck6"),
    ]),
    ("Equidistant Cylindrical (Plate Carrée)", "+proj=eqc"),
    ("Equidistant Conic", "+proj=eqdc +lat_1=55 +lat_2=60"),
    ("Equal Earth", "+proj=eqearth"),
    ("Euler", "+proj=euler +lat_1=67 +lat_2=75"),
    ("Fahey", "+proj=fahey"),
    ("Foucaut projections", [
        ("Foucaut", "+proj=fouc"),
        ("Foucaut Sinusoidal", "+proj=fouc_s"),
    ]),
    ("Gall Stereographic", "+proj=gall"),
    ("Geostationary Satellite", "+proj=geos +h=35785831.0 +lon_0=-60 +sweep=y"),
    ("Ginsburg VIII", "+proj=gins8"),
    ("General Sinusoidal Series", "+proj=gn_sinu +m=2 +n=3"),
    ("Goode Homolosine", "+proj=goode"),
    ("Guyou", "+proj=guyou"),
    ("Hammer", "+proj=hammer"),
    ("Hatano Asymmetrical Equal-Area", "+proj=hatano"),
    ("Interrupted projections", [
        ("Goode Homolosine", "+proj=igh"),
        ("Goode Homolosine (oceanic)", "+proj=igh_o +lon_0=-160"),
        ("Mollweide", "+proj=imoll"),
        ("Mollweide (oceanic)", "+proj=imoll_o +lon_0=-160"),
    ]),
    ("International Map of the World Polyconic", "+proj=imw_p +lat_1=30 +lat_2=-40"),
    ("Icosahedral Snyder Equal-Area", "+proj=isea"),
    ("Kavrayskiy", [
        ("V", "+proj=kav5"),
        ("VII", "+proj=kav7"),
    ]),
    ("Lambert Azimuthal Equal-Area", "+proj=laea"),
    ("Lagrange", "+proj=lagrng"),
    ("Larrivée", "+proj=larr"),
    ("Laskowski", "+proj=lask"),
    ("Lambert Conformal Conic (Alternative)", "+proj=lcca +lat_0=35"),
    ("Lambert Equal-Area Conic", "+proj=leac"),
    ("Loximuthal", "+proj=loxim"),
    ("Space Oblique (Landsat)", "+proj=lsat +ellps=GRS80 +lat_1=-60 +lat_2=60 +lsat=2 +path=2"),
    ("McBryde–Thomas projections", [
        ("Flat-Polar Sine (No. 1)", "+proj=mbt_s"),
        ("Flat-Pole Sine (No. 2)", "+proj=mbt_fps"),
        ("Flat-Polar Parabolic", "+proj=mbtfpp"),
        ("Flat-Polar Quartic", "+proj=mbtfpq"),
        ("Flat-Polar Sinusoidal", "+proj=mbtfps"),
    ]),
    ("Mercator", "+proj=merc"),
    ("Miller Cylindrical", "+proj=mill"),
    ("Mollweide", "+proj=moll"),
    ("Murdoch", [
        ("I", "+proj=murd1 +lat_1=30 +lat_2=50"),
        ("III", "+proj=murd3 +lat_1=30 +lat_2=50"),
    ]),
    ("Natural Earth", [
        ("I", "+proj=natearth"),
        ("II", "+proj=natearth2"),
    ]),
    ("Nell projections", [
        ("Nell", "+proj=nell"),
        ("Nell–Hammer", "+proj=nell_h"),
    ]),
    ("Nicolosi Globular", "+proj=nicol"),
    ("General Oblique Transformation", "+proj=ob_tran +o_proj=mill +o_lon_p=40 +o_lat_p=50 +lon_0=60"),
    ("Oblique Cylindrical Equal-Area", "+proj=ocea"),
    ("Oblated Equal-Area", "+proj=oea +m=1 +n=2"),
    ("Oblique Mercator", "+proj=omerc +lat_1=45 +lat_2=55"),
    ("Ortelius Oval", "+proj=ortel"),
    ("Orthographic", "+proj=ortho"),
    ("Patterson Cylindrical", "+proj=patterson"),
    ("American Polyconic", "+proj=poly"),
    ("Putniņš", [
        ("P1", "+proj=putp1"),
        ("P2", "+proj=putp2"),
        ("P3", "+proj=putp3"),
        ("P3′", "+proj=putp3p"),
        ("P4′", "+proj=putp4p"),
        ("P5", "+proj=putp5"),
        ("P5′", "+proj=putp5p"),
        ("P6", "+proj=putp6"),
        ("P6′", "+proj=putp6p"),
    ]),
    ("Quartic Authalic", "+proj=qua_aut"),
    ("Robinson", "+proj=robin"),
    ("Roussilhe Stereographic", "+proj=rouss"),
    ("Rectangular Polyconic", "+proj=rpoly"),
    ("Sinusoidal", "+proj=sinu"),
    ("Spilhaus", "+proj=spilhaus"),
    ("Times", "+proj=times"),
    ("Tissot Modified Conic", "+proj=tissot +lat_1=60 +lat_2=65"),
    ("Transverse Mercator", "+proj=tmerc"),
    ("Tobler–Mercator", "+proj=tobmerc"),
    ("Two-Point Equidistant", "+proj=tpeqd +lat_1=60 +lat_2=65"),
    ("Urmaev V", "+proj=urm5 +n=0.9 +alpha=2 +q=4"),
    ("Urmaev Flat-Polar Sinusoidal", "+proj=urmfps +n=0.5"),
    ("Van der Grinten", [
        ("I", "+proj=vandg"),
        ("II", "+proj=vandg2"),
        ("III", "+proj=vandg3"),
        ("IV", "+proj=vandg4"),
    ]),
    ("Vitkovsky I", "+proj=vitk1 +lat_1=45 +lat_2=55"),
    ("Wagner", [
        ("I", "+proj=wag1"),
        ("II", "+proj=wag2"),
        ("III", "+proj=wag3"),
        ("IV", "+proj=wag4"),
        ("V", "+proj=wag5"),
        ("VI", "+proj=wag6"),
        ("VII", "+proj=wag7"),
    ]),
    ("Web Mercator (Pseudo-Mercator)", "+proj=webmerc +datum=WGS84"),
    ("Werenskiold I", "+proj=weren"),
    ("Winkel", [
        ("I", "+proj=wink1"),
        ("II", "+proj=wink2"),
    ]),
    ("Winkel Tripel", "+proj=wintri"),
]

# Page intro + the shared preamble cell (visible, so the per-panel snippets below are reproducible).
const _HEADER = """
# Projections

GeoMakie clips and resamples geometry **on the sphere before projection**, so filled
contours, polygons, lines, and the projection boundary stay correct across each
projection's discontinuity — the antimeridian, interrupted lobes (`igh`/`imoll`),
azimuthal/perspective horizons (`ortho`/`geos`), and oblique seams (`spilhaus`/`bertin`).

Each section below draws the **bare** projection on a `GeoAxis` — the coastline land
polygons and the graticule — for (almost) every projection PROJ provides, one panel per
projection (the PROJ string is shown as each panel's title), with related variants grouped
into tabs. The land outline and graticule stay correct right up to each projection's
discontinuity, with no smears across the tear.

(For a *filled-field* test on a curvilinear grid — `contourf!` of an Oceananigans tripolar
field, with `add_cyclic_point` and the interrupted `imoll_o` projection — see the
[Tripolar grid](@ref) example.)

Every panel below is the same handful of lines with a different `dest` — copy this preamble
once, then any panel reproduces on its own:

```@example projections
using GeoMakie, CairoMakie
CairoMakie.activate!(type = :svg)   # this page is pure vector content, so render crisp SVG

land = GeoMakie.land()              # Natural Earth land polygons, reused by every panel
nothing # hide
```
"""

# The polar tail: `GeoPolarAxis` land panels (the *field* demo lives in its own example page).
const _POLAR_TAIL = """
## Polar (stereographic) — `GeoPolarAxis`

For a **circular-boundary** polar map — stereographic centred on a pole and zoomed to a cap,
the way you'd view sea-ice or a tripolar-grid field (cartopy's
[`always_circular_stereo`](https://cartopy.readthedocs.io/latest/gallery/lines_and_polygons/always_circular_stereo.html))
— use [`GeoPolarAxis`](@ref). A pole-centred azimuthal projection *is* a polar plot, separable as
`θ = lon` and `r = radial(lat)` (the projection's radial law), so `GeoPolarAxis` re-expresses the
projection on a Makie `PolarAxis` and gets the **circular clip**, the **polar graticule**
(parallels as r-rings, meridians as θ-spokes) and the **circular spine** for free.

Pass the cap latitude as `latcap` — its sign picks the pole (`latcap ≥ 0` north, `< 0` south) —
then plot with the usual verbs (`lines!`, `scatter!`, `poly!`, `surface!`, `heatmap!`,
`contourf!`) using **geographic** `(lon, lat)` data:

```@example projections
polar = Figure(size = (840, 460))
for (i, (latcap, ttl)) in enumerate([
        (55, "North polar stereographic"),
        (-55, "South polar stereographic")])
    gpa = GeoPolarAxis(polar[1, i]; latcap = latcap, title = ttl, titlesize = 11)
    poly!(gpa, land; color = (:gray70, 0.55), strokecolor = :black, strokewidth = 0.3)
end
polar
```

For a *filled field* on a cap (`contourf!`/`surface!`/`heatmap!` with a colorbar and a
non-default azimuthal projection, reproducing cartopy's `always_circular_stereo`), see the
[Polar stereographic cap](@ref) example.

```@setup projections
## Backend type is process-global in CairoMakie. This page is pure vector content (rendered as
## SVG above); reset to PNG so later raster-heavy example pages don't balloon into huge SVGs.
CairoMakie.activate!(px_per_unit = 2, type = :png)
```
"""

# one self-contained @example cell drawing the bare land + graticule for `proj`. `fence` is "```"
# for a standalone section or "````" when nested inside a `::: tabs` container.
function _proj_cell(proj, fence)
    return join([
        fence * "@example projections",
        "fig = Figure(size = (420, 300))",
        "ga = GeoAxis(fig[1, 1]; dest = $(repr(proj)), title = $(repr(proj)),",
        "    titlesize = 9, titlefont = :regular)",
        "hidedecorations!(ga; grid = false)",
        "poly!(ga, land; color = (:gray70, 0.55), strokecolor = :black, strokewidth = 0.3)",
        "fig",
        fence,
    ], "\n")
end

function _emit_section!(io, title, payload)
    println(io, "## ", title, "\n")
    if payload isa AbstractString
        println(io, _proj_cell(payload, "```"), "\n")
    else
        println(io, "::: tabs\n")
        for (label, proj) in payload
            println(io, "== ", label, "\n")
            println(io, _proj_cell(proj, "````"), "\n")
        end
        println(io, ":::\n")
    end
    return nothing
end

"""
    generate_projections(outpath)

Write the projection gallery markdown to `outpath` from `PROJECTION_SECTIONS`. Called by `make.jl`.
"""
function generate_projections(outpath)
    io = IOBuffer()
    println(io, "<!-- AUTO-GENERATED by docs/generate_projections.jl — DO NOT EDIT BY HAND. -->")
    println(io, "<!-- Edit PROJECTION_SECTIONS in that script and rebuild the docs.        -->\n")
    println(io, _HEADER)
    for (title, payload) in PROJECTION_SECTIONS
        _emit_section!(io, title, payload)
    end
    print(io, _POLAR_TAIL)
    write(outpath, String(take!(io)))
    return outpath
end
