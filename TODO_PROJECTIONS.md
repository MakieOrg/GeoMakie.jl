# TODO — projection gallery rendering issues

Working tracker for the visual problems in the `projections.md` gallery (and the `GeoPolarAxis`
default). Delete before the PR merges. Issues below come from a manual eyeball of every rendered
panel; they are grouped by **root cause** (not by projection) so each fix lands once across all the
projections it affects.

## How the rendering works (the three knobs every issue touches)

1. **The spine / projection boundary** is computed by `boundary_points(dest, src)` in
   `src/sphere_clip.jl:1634-1715`, dispatched per clip strategy. AntimeridianClip boundaries are
   densified at **24 points/edge** (`src/sphere_clip.jl:1708`); CircleClip uses adaptive recursion
   (`_DELTA2 = 0.5` squared screen units, depth 16); PolygonClip uses a convex hull of the projected
   grid (`_oblique_boundary`, `src/sphere_clip.jl:486-538`).
2. **The clip strategy** is chosen in `clip_strategy(t)` (`src/sphere_clip.jl:1748-1806`), keyed on
   the PROJ name. Anything untabled falls through to `AntimeridianClip(lon0)` — including all the
   oblique / multi-point projections that are actually broken (see Bucket D).
3. **The axis limits** fit to the plotted data, then clamp to the spine's bounding box
   (`Makie.getlimits`, `src/makie-axis.jl:269-305`). A 1% sliver is kept so the spine isn't
   half-clipped (`src/geoaxis.jl:921-922`). When the spine looks "cropped", this clamp is the place
   to look.

---

## Bucket A — spine cropped at top/bottom (limits slightly tighter than the spine) — DONE (pending visual review)

**Fix landed:** `getlimits` now snaps an auto-fit edge out to the spine when the data already reaches
within `_SPINE_SNAP = 0.1` of it (`src/makie-axis.jl`), so world-land panels frame the full
projection while regional plots (italy.jl on ortho) stay zoomed to their data. Verified numerically
(gall/mill/times/vandg now show the full spine top & bottom; italy ortho stays zoomed).


**Symptom:** the boundary line is cut off (usually at the north and/or south edge), sometimes by a
few pixels, sometimes the whole top edge is gone.

**Affected:** Adams "Hemisphere in a square" (top), Adams "World in a square II" (north, badly),
Gall Stereographic (top entirely), Miller Cylindrical (top), Times (top), Tobler–Mercator (top &
bottom), Van der Grinten I & III (tops), Lagrange (top, slight), Larrivée (top, at both bumps),
Fahey (north, slight), Foucaut (north, few px), General Oblique Transformation (bottom), Oblated
Equal-Area (bottom-left corner).

**Hypothesis:** the limit clamp uses the spine's *bounding box*, but the drawn spine line has finite
width and sits exactly on that box, so the 1% sliver isn't enough on the pole edges — or the spine's
topmost sample doesn't quite reach the true domain max (latitude clamp / cutoff). Worth checking
whether the inset should be applied symmetrically in *projected* space and be a touch larger, or
whether `getlimits` should pad by a half-linewidth.

**Fix approach:** (a) confirm spine extent vs. clamped limits for one cylindrical case (e.g. Gall);
(b) either grow the sliver / pad by the spine linewidth in `getlimits`, or stop clamping `hi`/`lo`
to the spine box on the axes where the spine *is* the data; (c) re-check all the cases above.
**Priority: high** (affects ~14 otherwise-correct projections, cheap fix).

## Bucket B — spine facets / not smooth near poles (insufficient densification) — DONE (pending visual review)

**Fix landed:** the spine ring now resamples on a `_SPINE_REFINE = 6×` tighter projected threshold
(`src/sphere_clip.jl`), and the conic cutoff cone is routed through the adaptive resampler instead of
a fixed 181-point arc. Measured turn angles dropped sharply on curved boundaries (august 27°→14°,
poly 86→44 facets) while true corners stay sharp (conic apex, flat-pole corners on wag1/robin, larr's
bumps are all unchanged).


**Symptom:** the boundary is visibly polygonal (straight segments) where it should curve, especially
at pointed N/S poles.

**Affected:** Albers Equal-Area Conic, August Epicycloidal, Lambert Conformal Conic (Alternative),
Lambert Equal-Area Conic (south), Murdoch I & III, American Polyconic, Tissot Modified Conic,
Vitkovsky I, Wagner (all), Natural Earth (slight), Fahey (south), Larrivée, Van der Grinten,
Adams "Hemisphere in a square".

**Hypothesis:** the 24-points/edge AntimeridianClip densification (`src/sphere_clip.jl:1708`) is too
coarse where the boundary curves sharply near a pole. CircleClip is already adaptive and looks fine.

**Fix approach:** make the AntimeridianClip boundary densification adaptive on projected curvature
(reuse the `_resample_to!` / `_DELTA2` machinery already used for CircleClip), or simply raise the
per-edge count and add extra samples in the last few degrees near each pole. **Priority: high**
(one change, many projections; purely cosmetic but very visible).

## Bucket C — land / graticule spill *beyond* the spine (clip boundary ≠ true domain)

**Symptom:** equator graticule lines and a sliver of land run past the drawn boundary on the sides;
the spine looks like it "short-cuts straight down" instead of following the real domain edge.

**Affected:** Azimuthal Equidistant (equator gridlines + land beyond spine, L & R), Nicolosi
Globular (land + grid beyond spine).

**Hypothesis:** for `aeqd` the CircleClip horizon (179.5°) is correct in topology, but the boundary
ring isn't sampled densely enough on the left/right extremes so it chords across; the *clip* then
admits geometry the *spine* visually excludes. Nicolosi is a globular disk routed to the default
AntimeridianClip, so its disk domain isn't being clipped at all.

**Fix approach:** densify the CircleClip ring on the wide axis (aeqd); add globular projections
(`nicol`, and check `apian`/`bacon`/`ortel`) to a disk/CircleClip-style domain so the clip matches
the boundary. **Priority: medium.**

## Bucket D — gross smearing + wrong spine (oblique / multi-point family routed to AntimeridianClip)

**Symptom:** land polygons smear toward a single point outside the frame, half the map is missing,
and the spine is in the wrong place or runs along the antimeridian through the map interior. These
projections have a seam/domain that is **not** the geographic ±180° meridian, but they fall through
to the default `AntimeridianClip(lon0)` (`src/sphere_clip.jl:1804`). This is the deferred
"oblique family" work (see `dev/general_splitting_plan.md` step 5).

**Affected:** Oblique Mercator (`omerc`, **blank**), Transverse Mercator (`tmerc`, **blank**),
Space Oblique / Landsat (`lsat`), Chamberlin Trimetric (`chamb`), Two-Point Equidistant (`tpeqd`),
Bipolar Conic (`bipc`), International Map of the World Polyconic (`imw_p`), Icosahedral Snyder
(`isea`), Guyou (`guyou`, no spine — inverse unavailable, falls to ProjectedClip), Tobler–Mercator
(pole smear), Oblated Equal-Area (slight top smear).

**Hypothesis / sub-cases:**
- **Blank** (`omerc`, `tmerc`): boundary_points returns empty or all geometry is clipped to the
  wrong side; the antimeridian seam is in the wrong frame for a transverse/oblique aspect.
- **Antimeridian-through-interior** (`tpeqd`, `chamb`): the ±180° meridian is *interior* for these
  full-globe-ish layouts, so drawing it as the seam tears the map.
- **No native frame** (`lsat`, `bipc`, `imw_p`, `isea`): need a rotated/native working frame or a
  per-projection domain; genuinely hard.

**Fix approach:** this is the big one. Port the rotated-frame clip (`ObliqueAntimeridianClip` exists
but is unused for these) or add a projected-space seam detector for the oblique family; special-case
`tmerc`/`omerc` first since "blank" is the worst look. Several of these (`bipc`, `imw_p`, `isea`,
`lsat`) are exotic — acceptable to leave them visibly imperfect with a known-issues note.
**Priority: medium for `tmerc`/`omerc`/`tpeqd` (common, currently blank/torn); low for the exotics.**

## Bucket E — square-boundary projections show rounded corners

**Symptom:** a projection whose true boundary is a square renders with rounded corners (and, for
Adams ws1, a stray boundary segment at an angle).

**Affected:** Spilhaus, Adams "World in a square I", Adams "World in a square II" (corners),
possibly General Oblique Transformation.

**Hypothesis:** `spilhaus`/`guyou` use the convex-hull PolygonClip whose Douglas–Peucker pass rounds
the corners (`src/sphere_clip.jl:1783-1787`, a documented workaround). The `adams_ws1`/`adams_ws2`
variants aren't tabled at all, so they hit the default AntimeridianClip and get neither a square
clip nor a square spine.

**Fix approach:** give the square-boundary projections an exact square domain (route `adams_ws1/ws2`
with the correct square frame; for `spilhaus` build the boundary from the analytic square rather than
the convex hull). **Priority: low** (cosmetic, exotic).

## Bucket F — antimeridian graticule line drawn twice

**Symptom:** the ±180° meridian renders darker than the other graticule lines (overdraw).

**Affected:** Bertin 1953 (clearly); check whether it happens elsewhere (any AntimeridianClip
projection could draw the seam meridian on both the left and right edges).

**Hypothesis:** after the antimeridian split both copies of the seam meridian land on the boundary
and are stroked, or the graticule emits the ±180 line once and the spine re-draws it.

**Fix approach:** dedupe the seam meridian in the graticule/clip, or skip stroking the graticule
line that coincides with the spine. **Priority: low.**

## Bucket G — orientation / sanity checks

- **Oblique Cylindrical Equal-Area (`ocea`)** looks upside-down — confirm against PROJ/d3 whether
  that's the correct orientation before "fixing" it. **Priority: low (verify only).**

## Bucket H — GeoPolarAxis defaults — DONE (pending visual review)

**Fix landed:** added a `ticklabelsvisible` attribute (default `false`) on `GeoPolarAxis`, wired to
the wrapped PolarAxis's `rticklabelsvisible`/`thetaticklabelsvisible` (`src/polar.jl`). Grid rings,
spokes and the circular spine stay visible; users opt back in with `ticklabelsvisible = true`.
Verified, and `test/polar.jl` stays green.


**Symptom:** `GeoPolarAxis` shows r/θ tick labels by default, unlike the `GeoAxis` gallery panels
(which `hidedecorations!`).

**Fix approach:** in `initialize_block!` (`src/polar.jl:209-227`) default the PolarAxis to
`rticklabelsvisible = false, thetaticklabelsvisible = false` (expose a `ticklabelsvisible`
attribute, default `false`, so users can turn them back on). The grid rings/spokes and circular
spine should stay visible. **Priority: high (trivial, user-requested).**

---

## Suggested plan / order of attack

1. **Quick wins first (one PR slice):**
   - Bucket H — hide GeoPolarAxis tick labels by default.
   - Bucket A — fix the top/bottom spine crop in `getlimits` (pad by spine linewidth / grow sliver),
     re-render, confirm the ~14 cases.
   - Bucket B — adaptive (or denser) AntimeridianClip boundary densification near poles.
   - Re-run the gallery and re-eyeball A & B together (they touch overlapping projections).
2. **Medium slice:**
   - Bucket C — densify the aeqd CircleClip ring; route globular disks (nicol, …) to a disk clip.
   - Bucket F — dedupe the antimeridian graticule overdraw.
   - Bucket D, narrow — make `tmerc`/`omerc` non-blank and stop `tpeqd`/`chamb` drawing the
     antimeridian through the interior (even if not pixel-perfect).
3. **Deferred / known-issues:**
   - Bucket D, exotics (`bipc`, `imw_p`, `isea`, `lsat`) and Bucket E (square corners) — document as
     known imperfect in a short note on the page rather than block the PR.
   - Bucket G — verify `ocea` orientation.

Re-render the gallery after each slice (`julia --project=docs docs/make.jl`, or the standalone
generator for structure) and eyeball the panels — per project convention, the figures are reviewed
visually, not asserted pixel-wise.

---

## GeoPolarAxis architecture notes (still current — read before touching `src/polar.jl`)

- `GeoPolarAxis` is `Makie.@Block GeoPolarAxis <: Makie.AbstractAxis`, a sibling of `GeoAxis` (both
  are concrete `@Block`s, so neither can subtype the other). It uses `@forwarded_layout` and creates
  its wrapped `PolarAxis` at `gpa.layout[1, 1]` (the `SliderGrid` nesting pattern).
- Makie rejects any kwarg that isn't a declared attribute (`_check_remaining_kwargs`,
  `blocks.jl:334`), so there is no `kwargs...`→`PolarAxis` passthrough. Every accepted keyword
  (`latcap`, `dest`, `source`, `lat/lonticks`, `direction`, `theta_0`, grid styling, the `title*`
  family) is a declared attribute; anything else must be set via `gpa.axis`.
- `latcap`/`dest`/etc. are attributes (Observables): use `gpa.dest[]`. `gpa.axis`/`gpa.transform`
  are plain fields (no `[]`). `dest`/`source` resolve in `initialize_block!` and the resolved PROJ
  strings are written back into the attributes.
- It owns no limits, so `Makie.update_state_before_display!(gpa)` forwards to `gpa.axis`; otherwise
  the generic `AbstractAxis` path hits `reset_limits!`/`gpa.limits` and errors on `save`.
- Construction is read-once (not reactive to a later `gpa.latcap[] = …`); full reactivity is a
  follow-up.
- South-cap orientation was fixed: `_polar_orientation` returns `direction, direction * α0` (Makie's
  `Polar` applies the offset *inside* the direction flip).

## Prior context — upstream follow-ups (NOT this PR)

When GeometryOps ships #417–#421 (spherical clip / arc intersection / point-in-polygon /
rings→nested-polygons / `GeographicFromUnitSphere` clamp), delete the matching bespoke code
(`_clip_against_polygon`+`_cp_*`, `_gc_intersect`, `_polygon_contains`, `_rings_to_polygons`,
`_sph`). Long-form draft: `dev/UPSTREAM_GEOMETRYOPS.md` (gitignored).
