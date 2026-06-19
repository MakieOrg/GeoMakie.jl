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

```@setup projections
using GeoMakie, CairoMakie

## This page is pure vector content (land polygons + graticule lines, no raster data
## layer), so render it as SVG for crisp output at any zoom. backend type is process-
## global in CairoMakie, so we reset to PNG in a hidden block at the end of the page
## (otherwise raster-heavy later pages would balloon into huge SVGs).
CairoMakie.activate!(type = :svg)

const LAND = GeoMakie.land()

## one bare land + graticule panel for a single projection; the PROJ string is the title.
## a try-catch keeps a bad projection from sinking the whole page (it renders a
## "(skipped)" label instead)
function panel(proj)
    fig = Figure(size = (420, 300))
    try
        ga = GeoAxis(fig[1, 1]; dest = proj, title = proj, titlesize = 9, titlefont = :regular)
        hidedecorations!(ga; grid = false)
        poly!(ga, LAND; color = (:gray70, 0.55), strokecolor = :black, strokewidth = 0.3)
    catch
        Label(fig[1, 1], replace(proj, "+proj=" => "") * "\n(skipped)"; fontsize = 10)
    end
    return fig
end
```

## Adams projections

::: tabs

== Hemisphere in a square

````@example projections
panel("+proj=adams_hemi") # hide
````

== World in a square I

````@example projections
panel("+proj=adams_ws1") # hide
````

== World in a square II

````@example projections
panel("+proj=adams_ws2") # hide
````

:::

## Albers Equal-Area Conic

```@example projections
panel("+proj=aea +lat_1=29.5 +lat_2=42.5") # hide
```

## Azimuthal Equidistant

```@example projections
panel("+proj=aeqd") # hide
```

## Airy

```@example projections
panel("+proj=airy") # hide
```

## Aitoff

```@example projections
panel("+proj=aitoff") # hide
```

## Apian Globular I

```@example projections
panel("+proj=apian") # hide
```

## August Epicycloidal

```@example projections
panel("+proj=august") # hide
```

## Bacon Globular

```@example projections
panel("+proj=bacon") # hide
```

## Bertin 1953

```@example projections
panel("+proj=bertin1953") # hide
```

## Bipolar Conic

```@example projections
panel("+proj=bipc +ns") # hide
```

## Boggs Eumorphic

```@example projections
panel("+proj=boggs") # hide
```

## Bonne

```@example projections
panel("+proj=bonne +lat_1=10") # hide
```

## Cylindrical Equal-Area

```@example projections
panel("+proj=cea") # hide
```

## Chamberlin Trimetric

```@example projections
panel("+proj=chamb +lat_1=10 +lon_1=30 +lon_2=40") # hide
```

## Collignon

```@example projections
panel("+proj=collg") # hide
```

## Compact Miller

```@example projections
panel("+proj=comill") # hide
```

## Craster Parabolic

```@example projections
panel("+proj=crast") # hide
```

## Denoyer Semi-Elliptical

```@example projections
panel("+proj=denoy") # hide
```

## Eckert

::: tabs

== I

````@example projections
panel("+proj=eck1") # hide
````

== II

````@example projections
panel("+proj=eck2") # hide
````

== III

````@example projections
panel("+proj=eck3") # hide
````

== IV

````@example projections
panel("+proj=eck4") # hide
````

== V

````@example projections
panel("+proj=eck5") # hide
````

== VI

````@example projections
panel("+proj=eck6") # hide
````

:::

## Equidistant Cylindrical (Plate Carrée)

```@example projections
panel("+proj=eqc") # hide
```

## Equidistant Conic

```@example projections
panel("+proj=eqdc +lat_1=55 +lat_2=60") # hide
```

## Equal Earth

```@example projections
panel("+proj=eqearth") # hide
```

## Euler

```@example projections
panel("+proj=euler +lat_1=67 +lat_2=75") # hide
```

## Fahey

```@example projections
panel("+proj=fahey") # hide
```

## Foucaut projections

::: tabs

== Foucaut

````@example projections
panel("+proj=fouc") # hide
````

== Foucaut Sinusoidal

````@example projections
panel("+proj=fouc_s") # hide
````

:::

## Gall Stereographic

```@example projections
panel("+proj=gall") # hide
```

## Geostationary Satellite

```@example projections
panel("+proj=geos +h=35785831.0 +lon_0=-60 +sweep=y") # hide
```

## Ginsburg VIII

```@example projections
panel("+proj=gins8") # hide
```

## General Sinusoidal Series

```@example projections
panel("+proj=gn_sinu +m=2 +n=3") # hide
```

## Goode Homolosine

```@example projections
panel("+proj=goode") # hide
```

## Guyou

```@example projections
panel("+proj=guyou") # hide
```

## Hammer

```@example projections
panel("+proj=hammer") # hide
```

## Hatano Asymmetrical Equal-Area

```@example projections
panel("+proj=hatano") # hide
```

## Interrupted projections

::: tabs

== Goode Homolosine

````@example projections
panel("+proj=igh") # hide
````

== Goode Homolosine (oceanic)

````@example projections
panel("+proj=igh_o +lon_0=-160") # hide
````

== Mollweide

````@example projections
panel("+proj=imoll") # hide
````

== Mollweide (oceanic)

````@example projections
panel("+proj=imoll_o +lon_0=-160") # hide
````

:::

## International Map of the World Polyconic

```@example projections
panel("+proj=imw_p +lat_1=30 +lat_2=-40") # hide
```

## Icosahedral Snyder Equal-Area

```@example projections
panel("+proj=isea") # hide
```

## Kavrayskiy

::: tabs

== V

````@example projections
panel("+proj=kav5") # hide
````

== VII

````@example projections
panel("+proj=kav7") # hide
````

:::

## Lambert Azimuthal Equal-Area

```@example projections
panel("+proj=laea") # hide
```

## Lagrange

```@example projections
panel("+proj=lagrng") # hide
```

## Larrivée

```@example projections
panel("+proj=larr") # hide
```

## Laskowski

```@example projections
panel("+proj=lask") # hide
```

## Lambert Conformal Conic (Alternative)

```@example projections
panel("+proj=lcca +lat_0=35") # hide
```

## Lambert Equal-Area Conic

```@example projections
panel("+proj=leac") # hide
```

## Loximuthal

```@example projections
panel("+proj=loxim") # hide
```

## Space Oblique (Landsat)

```@example projections
panel("+proj=lsat +ellps=GRS80 +lat_1=-60 +lat_2=60 +lsat=2 +path=2") # hide
```

## McBryde–Thomas projections

::: tabs

== Flat-Polar Sine (No. 1)

````@example projections
panel("+proj=mbt_s") # hide
````

== Flat-Pole Sine (No. 2)

````@example projections
panel("+proj=mbt_fps") # hide
````

== Flat-Polar Parabolic

````@example projections
panel("+proj=mbtfpp") # hide
````

== Flat-Polar Quartic

````@example projections
panel("+proj=mbtfpq") # hide
````

== Flat-Polar Sinusoidal

````@example projections
panel("+proj=mbtfps") # hide
````

:::

## Mercator

```@example projections
panel("+proj=merc") # hide
```

## Miller Cylindrical

```@example projections
panel("+proj=mill") # hide
```

## Mollweide

```@example projections
panel("+proj=moll") # hide
```

## Murdoch

::: tabs

== I

````@example projections
panel("+proj=murd1 +lat_1=30 +lat_2=50") # hide
````

== III

````@example projections
panel("+proj=murd3 +lat_1=30 +lat_2=50") # hide
````

:::

## Natural Earth

::: tabs

== I

````@example projections
panel("+proj=natearth") # hide
````

== II

````@example projections
panel("+proj=natearth2") # hide
````

:::

## Nell projections

::: tabs

== Nell

````@example projections
panel("+proj=nell") # hide
````

== Nell–Hammer

````@example projections
panel("+proj=nell_h") # hide
````

:::

## Nicolosi Globular

```@example projections
panel("+proj=nicol") # hide
```

## General Oblique Transformation

```@example projections
panel("+proj=ob_tran +o_proj=mill +o_lon_p=40 +o_lat_p=50 +lon_0=60") # hide
```

## Oblique Cylindrical Equal-Area

```@example projections
panel("+proj=ocea") # hide
```

## Oblated Equal-Area

```@example projections
panel("+proj=oea +m=1 +n=2") # hide
```

## Oblique Mercator

```@example projections
panel("+proj=omerc +lat_1=45 +lat_2=55") # hide
```

## Ortelius Oval

```@example projections
panel("+proj=ortel") # hide
```

## Orthographic

```@example projections
panel("+proj=ortho") # hide
```

## Patterson Cylindrical

```@example projections
panel("+proj=patterson") # hide
```

## American Polyconic

```@example projections
panel("+proj=poly") # hide
```

## Putniņš

::: tabs

== P1

````@example projections
panel("+proj=putp1") # hide
````

== P2

````@example projections
panel("+proj=putp2") # hide
````

== P3

````@example projections
panel("+proj=putp3") # hide
````

== P3′

````@example projections
panel("+proj=putp3p") # hide
````

== P4′

````@example projections
panel("+proj=putp4p") # hide
````

== P5

````@example projections
panel("+proj=putp5") # hide
````

== P5′

````@example projections
panel("+proj=putp5p") # hide
````

== P6

````@example projections
panel("+proj=putp6") # hide
````

== P6′

````@example projections
panel("+proj=putp6p") # hide
````

:::

## Quartic Authalic

```@example projections
panel("+proj=qua_aut") # hide
```

## Robinson

```@example projections
panel("+proj=robin") # hide
```

## Roussilhe Stereographic

```@example projections
panel("+proj=rouss") # hide
```

## Rectangular Polyconic

```@example projections
panel("+proj=rpoly") # hide
```

## Sinusoidal

```@example projections
panel("+proj=sinu") # hide
```

## Spilhaus

```@example projections
panel("+proj=spilhaus") # hide
```

## Times

```@example projections
panel("+proj=times") # hide
```

## Tissot Modified Conic

```@example projections
panel("+proj=tissot +lat_1=60 +lat_2=65") # hide
```

## Transverse Mercator

```@example projections
panel("+proj=tmerc") # hide
```

## Tobler–Mercator

```@example projections
panel("+proj=tobmerc") # hide
```

## Two-Point Equidistant

```@example projections
panel("+proj=tpeqd +lat_1=60 +lat_2=65") # hide
```

## Urmaev V

```@example projections
panel("+proj=urm5 +n=0.9 +alpha=2 +q=4") # hide
```

## Urmaev Flat-Polar Sinusoidal

```@example projections
panel("+proj=urmfps +n=0.5") # hide
```

## Van der Grinten

::: tabs

== I

````@example projections
panel("+proj=vandg") # hide
````

== II

````@example projections
panel("+proj=vandg2") # hide
````

== III

````@example projections
panel("+proj=vandg3") # hide
````

== IV

````@example projections
panel("+proj=vandg4") # hide
````

:::

## Vitkovsky I

```@example projections
panel("+proj=vitk1 +lat_1=45 +lat_2=55") # hide
```

## Wagner

::: tabs

== I

````@example projections
panel("+proj=wag1") # hide
````

== II

````@example projections
panel("+proj=wag2") # hide
````

== III

````@example projections
panel("+proj=wag3") # hide
````

== IV

````@example projections
panel("+proj=wag4") # hide
````

== V

````@example projections
panel("+proj=wag5") # hide
````

== VI

````@example projections
panel("+proj=wag6") # hide
````

== VII

````@example projections
panel("+proj=wag7") # hide
````

:::

## Web Mercator (Pseudo-Mercator)

```@example projections
panel("+proj=webmerc +datum=WGS84") # hide
```

## Werenskiold I

```@example projections
panel("+proj=weren") # hide
```

## Winkel

::: tabs

== I

````@example projections
panel("+proj=wink1") # hide
````

== II

````@example projections
panel("+proj=wink2") # hide
````

:::

## Winkel Tripel

```@example projections
panel("+proj=wintri") # hide
```

## Polar (stereographic)

Stereographic centred on each pole and zoomed to the cap — the way you'd view sea-ice
or tripolar-grid fields. Stereographic is azimuthal: its only discontinuity is the
*antipode* (the opposite pole), so the on-sphere clip is an antipodal cap, and the
graticule stays concentric right up to the centre. GeoAxis `limits` are in lon/lat, so
the cap is "all longitudes, lat in `[lat_cap, 90]`" (or the southern mirror), which the
projection maps to a disk. We draw the bounding parallel (`lat_cap`) as a circular spine.

```@example projections
polar = Figure(size = (840, 460))
for (i, (d, latcap, ttl)) in enumerate([
        ("+proj=stere +lat_0=90 +lon_0=0",   55, "North polar stereographic"),
        ("+proj=stere +lat_0=-90 +lon_0=0", -55, "South polar stereographic")])
    lims = latcap > 0 ? ((-180, 180), (latcap, 90)) : ((-180, 180), (-90, latcap))
    ga = GeoAxis(polar[1, i]; dest = d, limits = lims, title = ttl, titlesize = 11)
    hidedecorations!(ga; grid = false)
    poly!(ga, LAND; color = (:gray70, 0.55), strokecolor = :black, strokewidth = 0.3)
    ## circular spine: the bounding parallel at the cap latitude (a circle in stereographic)
    lines!(ga, Point2f.(-180:180, latcap); color = :black, linewidth = 1.0)
end
polar # hide
```

```@setup projections
## Restore the global PNG backend so later (raster-heavy) doc pages are not emitted as SVG.
CairoMakie.activate!(px_per_unit = 2, type = :png)
```
