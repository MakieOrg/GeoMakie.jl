# Projections

GeoMakie clips and resamples geometry **on the sphere before projection**, so filled
contours, polygons, lines, and the projection boundary stay correct across each
projection's discontinuity — the antimeridian, interrupted lobes (`igh`/`imoll`),
azimuthal/perspective horizons (`ortho`/`geos`), and oblique seams (`spilhaus`/`bertin`).

Each section below draws the **bare** projection on a `GeoAxis` — the coastline land
polygons and the graticule — for (almost) every projection PROJ provides, one panel per
projection, with related variants (e.g. `eck1`…`eck6`) grouped into tabs. The land outline
and graticule stay correct right up to each projection's discontinuity (the antimeridian,
interrupted lobes, azimuthal horizons, oblique seams), with no smears across the tear.

(For a *filled-field* test on a curvilinear grid — `contourf!` of an Oceananigans tripolar
field, with `add_cyclic_point` and the interrupted `imoll_o` projection — see the
[Tripolar grid](@ref) example.)

```@setup projections
using GeoMakie, CairoMakie

const LAND = GeoMakie.land()

## one bare land + graticule panel for a single projection; a try-catch keeps a bad
## projection from sinking the whole page (it renders a "(skipped)" label instead)
function panel(proj)
    fig = Figure(size = (420, 280))
    try
        ga = GeoAxis(fig[1, 1]; dest = proj)
        hidedecorations!(ga; grid = false)
        poly!(ga, LAND; color = (:gray70, 0.55), strokecolor = :black, strokewidth = 0.3)
    catch
        Label(fig[1, 1], replace(proj, "+proj=" => "") * "\n(skipped)"; fontsize = 10)
    end
    return fig
end
```

## `+proj=adams_hemi`

```@example projections
panel("+proj=adams_hemi") # hide
```

## `adams_ws` family

::: tabs

== adams_ws1

````@example projections
panel("+proj=adams_ws1") # hide
````

== adams_ws2

````@example projections
panel("+proj=adams_ws2") # hide
````

:::

## `+proj=aea +lat_1=29.5 +lat_2=42.5`

```@example projections
panel("+proj=aea +lat_1=29.5 +lat_2=42.5") # hide
```

## `+proj=aeqd`

```@example projections
panel("+proj=aeqd") # hide
```

## `+proj=airy`

```@example projections
panel("+proj=airy") # hide
```

## `+proj=aitoff`

```@example projections
panel("+proj=aitoff") # hide
```

## `+proj=apian`

```@example projections
panel("+proj=apian") # hide
```

## `+proj=august`

```@example projections
panel("+proj=august") # hide
```

## `+proj=bacon`

```@example projections
panel("+proj=bacon") # hide
```

## `+proj=bertin1953`

```@example projections
panel("+proj=bertin1953") # hide
```

## `+proj=bipc +ns`

```@example projections
panel("+proj=bipc +ns") # hide
```

## `+proj=boggs`

```@example projections
panel("+proj=boggs") # hide
```

## `+proj=bonne +lat_1=10`

```@example projections
panel("+proj=bonne +lat_1=10") # hide
```

## `+proj=cea`

```@example projections
panel("+proj=cea") # hide
```

## `+proj=chamb +lat_1=10 +lon_1=30 +lon_2=40`

```@example projections
panel("+proj=chamb +lat_1=10 +lon_1=30 +lon_2=40") # hide
```

## `+proj=collg`

```@example projections
panel("+proj=collg") # hide
```

## `+proj=comill`

```@example projections
panel("+proj=comill") # hide
```

## `+proj=crast`

```@example projections
panel("+proj=crast") # hide
```

## `+proj=denoy`

```@example projections
panel("+proj=denoy") # hide
```

## `eck` family

::: tabs

== eck1

````@example projections
panel("+proj=eck1") # hide
````

== eck2

````@example projections
panel("+proj=eck2") # hide
````

== eck3

````@example projections
panel("+proj=eck3") # hide
````

== eck4

````@example projections
panel("+proj=eck4") # hide
````

== eck5

````@example projections
panel("+proj=eck5") # hide
````

== eck6

````@example projections
panel("+proj=eck6") # hide
````

:::

## `+proj=eqc`

```@example projections
panel("+proj=eqc") # hide
```

## `+proj=eqdc +lat_1=55 +lat_2=60`

```@example projections
panel("+proj=eqdc +lat_1=55 +lat_2=60") # hide
```

## `+proj=eqearth`

```@example projections
panel("+proj=eqearth") # hide
```

## `+proj=euler +lat_1=67 +lat_2=75`

```@example projections
panel("+proj=euler +lat_1=67 +lat_2=75") # hide
```

## `+proj=fahey`

```@example projections
panel("+proj=fahey") # hide
```

## `+proj=fouc`

```@example projections
panel("+proj=fouc") # hide
```

## `+proj=fouc_s`

```@example projections
panel("+proj=fouc_s") # hide
```

## `+proj=gall`

```@example projections
panel("+proj=gall") # hide
```

## `+proj=geos +h=35785831.0 +lon_0=-60 +sweep=y`

```@example projections
panel("+proj=geos +h=35785831.0 +lon_0=-60 +sweep=y") # hide
```

## `+proj=gins8`

```@example projections
panel("+proj=gins8") # hide
```

## `+proj=gn_sinu +m=2 +n=3`

```@example projections
panel("+proj=gn_sinu +m=2 +n=3") # hide
```

## `+proj=goode`

```@example projections
panel("+proj=goode") # hide
```

## `+proj=guyou`

```@example projections
panel("+proj=guyou") # hide
```

## `+proj=hammer`

```@example projections
panel("+proj=hammer") # hide
```

## `+proj=hatano`

```@example projections
panel("+proj=hatano") # hide
```

## `+proj=igh`

```@example projections
panel("+proj=igh") # hide
```

## `+proj=igh_o +lon_0=-160`

```@example projections
panel("+proj=igh_o +lon_0=-160") # hide
```

## `+proj=imoll`

```@example projections
panel("+proj=imoll") # hide
```

## `+proj=imoll_o +lon_0=-160`

```@example projections
panel("+proj=imoll_o +lon_0=-160") # hide
```

## `+proj=imw_p +lat_1=30 +lat_2=-40`

```@example projections
panel("+proj=imw_p +lat_1=30 +lat_2=-40") # hide
```

## `+proj=isea`

```@example projections
panel("+proj=isea") # hide
```

## `kav` family

::: tabs

== kav5

````@example projections
panel("+proj=kav5") # hide
````

== kav7

````@example projections
panel("+proj=kav7") # hide
````

:::

## `+proj=laea`

```@example projections
panel("+proj=laea") # hide
```

## `+proj=lagrng`

```@example projections
panel("+proj=lagrng") # hide
```

## `+proj=larr`

```@example projections
panel("+proj=larr") # hide
```

## `+proj=lask`

```@example projections
panel("+proj=lask") # hide
```

## `+proj=lcca +lat_0=35`

```@example projections
panel("+proj=lcca +lat_0=35") # hide
```

## `+proj=leac`

```@example projections
panel("+proj=leac") # hide
```

## `+proj=loxim`

```@example projections
panel("+proj=loxim") # hide
```

## `+proj=lsat +ellps=GRS80 +lat_1=-60 +lat_2=60 +lsat=2 +path=2`

```@example projections
panel("+proj=lsat +ellps=GRS80 +lat_1=-60 +lat_2=60 +lsat=2 +path=2") # hide
```

## `+proj=mbt_s`

```@example projections
panel("+proj=mbt_s") # hide
```

## `+proj=mbt_fps`

```@example projections
panel("+proj=mbt_fps") # hide
```

## `+proj=mbtfpp`

```@example projections
panel("+proj=mbtfpp") # hide
```

## `+proj=mbtfpq`

```@example projections
panel("+proj=mbtfpq") # hide
```

## `+proj=mbtfps`

```@example projections
panel("+proj=mbtfps") # hide
```

## `+proj=merc`

```@example projections
panel("+proj=merc") # hide
```

## `+proj=mill`

```@example projections
panel("+proj=mill") # hide
```

## `+proj=moll`

```@example projections
panel("+proj=moll") # hide
```

## `murd` family

::: tabs

== murd1

````@example projections
panel("+proj=murd1 +lat_1=30 +lat_2=50") # hide
````

== murd3

````@example projections
panel("+proj=murd3 +lat_1=30 +lat_2=50") # hide
````

:::

## `natearth` family

::: tabs

== natearth

````@example projections
panel("+proj=natearth") # hide
````

== natearth2

````@example projections
panel("+proj=natearth2") # hide
````

:::

## `+proj=nell`

```@example projections
panel("+proj=nell") # hide
```

## `+proj=nell_h`

```@example projections
panel("+proj=nell_h") # hide
```

## `+proj=nicol`

```@example projections
panel("+proj=nicol") # hide
```

## `+proj=ob_tran +o_proj=mill +o_lon_p=40 +o_lat_p=50 +lon_0=60`

```@example projections
panel("+proj=ob_tran +o_proj=mill +o_lon_p=40 +o_lat_p=50 +lon_0=60") # hide
```

## `+proj=ocea`

```@example projections
panel("+proj=ocea") # hide
```

## `+proj=oea +m=1 +n=2`

```@example projections
panel("+proj=oea +m=1 +n=2") # hide
```

## `+proj=omerc +lat_1=45 +lat_2=55`

```@example projections
panel("+proj=omerc +lat_1=45 +lat_2=55") # hide
```

## `+proj=ortel`

```@example projections
panel("+proj=ortel") # hide
```

## `+proj=ortho`

```@example projections
panel("+proj=ortho") # hide
```

## `+proj=patterson`

```@example projections
panel("+proj=patterson") # hide
```

## `+proj=poly`

```@example projections
panel("+proj=poly") # hide
```

## `putp` family

::: tabs

== putp1

````@example projections
panel("+proj=putp1") # hide
````

== putp2

````@example projections
panel("+proj=putp2") # hide
````

== putp3

````@example projections
panel("+proj=putp3") # hide
````

== putp3p

````@example projections
panel("+proj=putp3p") # hide
````

== putp4p

````@example projections
panel("+proj=putp4p") # hide
````

== putp5

````@example projections
panel("+proj=putp5") # hide
````

== putp5p

````@example projections
panel("+proj=putp5p") # hide
````

== putp6

````@example projections
panel("+proj=putp6") # hide
````

== putp6p

````@example projections
panel("+proj=putp6p") # hide
````

:::

## `+proj=qua_aut`

```@example projections
panel("+proj=qua_aut") # hide
```

## `+proj=robin`

```@example projections
panel("+proj=robin") # hide
```

## `+proj=rouss`

```@example projections
panel("+proj=rouss") # hide
```

## `+proj=rpoly`

```@example projections
panel("+proj=rpoly") # hide
```

## `+proj=sinu`

```@example projections
panel("+proj=sinu") # hide
```

## `+proj=spilhaus`

```@example projections
panel("+proj=spilhaus") # hide
```

## `+proj=times`

```@example projections
panel("+proj=times") # hide
```

## `+proj=tissot +lat_1=60 +lat_2=65`

```@example projections
panel("+proj=tissot +lat_1=60 +lat_2=65") # hide
```

## `+proj=tmerc`

```@example projections
panel("+proj=tmerc") # hide
```

## `+proj=tobmerc`

```@example projections
panel("+proj=tobmerc") # hide
```

## `+proj=tpeqd +lat_1=60 +lat_2=65`

```@example projections
panel("+proj=tpeqd +lat_1=60 +lat_2=65") # hide
```

## `+proj=urm5 +n=0.9 +alpha=2 +q=4`

```@example projections
panel("+proj=urm5 +n=0.9 +alpha=2 +q=4") # hide
```

## `+proj=urmfps +n=0.5`

```@example projections
panel("+proj=urmfps +n=0.5") # hide
```

## `vandg` family

::: tabs

== vandg

````@example projections
panel("+proj=vandg") # hide
````

== vandg2

````@example projections
panel("+proj=vandg2") # hide
````

== vandg3

````@example projections
panel("+proj=vandg3") # hide
````

== vandg4

````@example projections
panel("+proj=vandg4") # hide
````

:::

## `+proj=vitk1 +lat_1=45 +lat_2=55`

```@example projections
panel("+proj=vitk1 +lat_1=45 +lat_2=55") # hide
```

## `wag` family

::: tabs

== wag1

````@example projections
panel("+proj=wag1") # hide
````

== wag2

````@example projections
panel("+proj=wag2") # hide
````

== wag3

````@example projections
panel("+proj=wag3") # hide
````

== wag4

````@example projections
panel("+proj=wag4") # hide
````

== wag5

````@example projections
panel("+proj=wag5") # hide
````

== wag6

````@example projections
panel("+proj=wag6") # hide
````

== wag7

````@example projections
panel("+proj=wag7") # hide
````

:::

## `+proj=webmerc +datum=WGS84`

```@example projections
panel("+proj=webmerc +datum=WGS84") # hide
```

## `+proj=weren`

```@example projections
panel("+proj=weren") # hide
```

## `wink` family

::: tabs

== wink1

````@example projections
panel("+proj=wink1") # hide
````

== wink2

````@example projections
panel("+proj=wink2") # hide
````

:::

## `+proj=wintri`

```@example projections
panel("+proj=wintri") # hide
```

## Polar (stereographic)

Stereographic centred on each pole and zoomed to the cap — the way you'd view sea-ice
or tripolar-grid fields. Stereographic is azimuthal: its only discontinuity is the
*antipode* (the opposite pole), so the on-sphere clip is an antipodal cap, and the
graticule stays concentric right up to the centre. GeoAxis `limits` are in lon/lat, so
the cap is "all longitudes, lat in `[55, 90]`" (or the southern mirror), which the
projection maps to the disk.

```@example projections
polar = Figure(size = (840, 440))
for (i, (d, lims, ttl)) in enumerate([
        ("+proj=stere +lat_0=90 +lon_0=0",  ((-180, 180), (55, 90)),   "North polar stereographic"),
        ("+proj=stere +lat_0=-90 +lon_0=0", ((-180, 180), (-90, -55)), "South polar stereographic")])
    ga = GeoAxis(polar[1, i]; dest = d, limits = lims, title = ttl, titlesize = 11)
    hidedecorations!(ga; grid = false)
    poly!(ga, LAND; color = (:gray70, 0.55), strokecolor = :black, strokewidth = 0.3)
end
polar # hide
```
