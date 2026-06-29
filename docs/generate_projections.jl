# Generator for `docs/src/projections.md`, the single source of truth for the projection gallery.
# Edit the `PROJECTION_SECTIONS` list (or the prose constants) below, NOT the generated markdown,
# which `make.jl` overwrites on every build via `generate_projections(...)`.
#
# Generating it keeps one short list to maintain here while emitting a self-contained,
# copy-pasteable `@example` cell above each figure, instead of hand-maintaining ~110 near-identical
# blocks.

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

A `GeoAxis` can draw (almost) every projection PROJ provides. Each section below shows the
PROJ string for a projection and the code that draws it, with related variants grouped into
tabs.

Every panel is the same few lines with a different `dest`. Copy this preamble once, then any
panel below reproduces on its own:

```@example projections
using GeoMakie, CairoMakie
CairoMakie.activate!(type = :svg)

land = GeoMakie.land()
nothing # hide
```
"""

# The polar tail: `GeoPolarAxis` land panels (the field demo lives in its own example page).
const _POLAR_TAIL = """
## Polar stereographic (`GeoPolarAxis`)

!!! note "A separate axis type"
    Pole-centred polar maps use [`GeoPolarAxis`](@ref) rather than `GeoAxis`. It is a
    distinct axis type on purpose, so that a circular boundary, a polar graticule, and a
    circular spine all come for free.

Pass the cap latitude as `latcap` (its sign picks the pole: `latcap ≥ 0` north, `< 0` south),
then plot with the usual verbs using geographic `(lon, lat)` data:

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

For a filled field on a cap, see the [Polar stereographic cap](@ref) example.

```@setup projections
## Reset CairoMakie to PNG (the backend type is process-global) so later raster-heavy example
## pages don't balloon into huge SVGs.
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
    # A `@raw html` block passes the comment through verbatim so it stays a true (hidden) HTML
    # comment in the built page; a bare `<!-- -->` gets mangled into visible text by the
    # Documenter -> Vitepress markdown round-trip.
    println(io, "```@raw html")
    println(io, "<!-- AUTO-GENERATED by docs/generate_projections.jl. Do not edit by hand;")
    println(io, "     edit PROJECTION_SECTIONS in that script and rebuild the docs. -->")
    println(io, "```\n")
    println(io, _HEADER)
    for (title, payload) in PROJECTION_SECTIONS
        _emit_section!(io, title, payload)
    end
    print(io, _POLAR_TAIL)
    write(outpath, String(take!(io)))
    return outpath
end
