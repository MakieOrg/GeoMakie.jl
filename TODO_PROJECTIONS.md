# TODO — projection gallery rendering issues

Working tracker for the visual problems in the `projections.md` gallery. Delete before the PR
merges. Issues are grouped by **root cause** (not by projection) so each fix lands once across all
the projections it affects. Buckets A, B and H (spine crop, pole smoothness, polar tick labels) are
done and have been removed; what remains is the medium slice (C, F, narrow D) and the deferred work.

## How the rendering works (the three knobs every issue touches)

1. **The spine / projection boundary** is computed by `boundary_points(dest, src)` in
   `src/sphere_clip.jl`, dispatched per clip strategy. AntimeridianClip boundaries are densified then
   adaptively resampled; CircleClip uses adaptive recursion (`_DELTA2 = 0.5` squared screen units,
   depth 16); PolygonClip uses a convex hull of the projected grid (`_oblique_boundary`).
2. **The clip strategy** is chosen in `clip_strategy(t)` (`src/sphere_clip.jl`), keyed on the PROJ
   name. Anything untabled falls through to `AntimeridianClip(lon0)` — including all the oblique /
   multi-point projections that are actually broken (see Bucket D).
3. **The axis limits** fit to the plotted data, then snap to / clamp within the spine's bounding box
   (`Makie.getlimits`, `src/makie-axis.jl`).

---

## Bucket C — land / graticule spill *beyond* the spine (clip boundary ≠ true domain)

**Symptom:** equator graticule lines and a sliver of land run past the drawn boundary on the sides;
the spine looks like it "short-cuts straight down" instead of following the real domain edge.

**Affected:** Azimuthal Equidistant (`aeqd`), Nicolosi Globular (`nicol`); the other globular
projections `apian`/`bacon`/`ortel` share `nicol`'s root cause (confirmed below).

### Findings (measured this session — two *distinct* root causes, not one)

Diagnosis method (reproducible): for a `dest`, compare `boundary_points(dest)` (the spine) against
`split_geometry(GeoMakie.land(), t)` projected (the clipped land) and `split_resample_line` of the
equator; flag spine chords by max consecutive-vertex gap as a % of the spine's diameter, and run a
point-in-polygon test of land vertices vs the spine polygon. (All in `src/sphere_clip.jl`.)

**C1 — `aeqd`: the SPINE drops the left/right caps; the data is fine.** The clipped land is fully
inside the 179.5° horizon (max radius 1.82e7 vs spine 1.998e7; **0** land vertices beyond 179.5°),
and the equator, through the real graticule path (`split_resample_line` → CircleClip), is clipped
correctly to lon ±179.5 (max radius 1.99808e7 ≈ the intended 179.5° circle). The bug is in
`boundary_points` for **CircleClip**: the spine polygon has **two straight chords ~the full diameter
wide**, jumping `(±1.656e7, +1.119e7) → (±1.656e7, −1.119e7)` and skipping the ~68° arc through the
extreme points `(±2.0e7, 0)`. So the drawn spine cuts the left/right caps off the disk → "short-cuts
straight down", and ~29 land vertices then sit just outside the *chorded* (not the true) spine.
- *Mechanism:* CircleClip branch of `boundary_points` (~L1719–1724): the canonical 2° circle is
  `_unrotate`d to geographic then `_proj_ring`-resampled. The 179.5° ring passes next to the
  **antipode** (lon≈±180); where it straddles the antimeridian the great-circle densify/resample
  **drops that arc** → the chord. So this is NOT under-sampling — densifying the ring won't help;
  the arc nearest the antipode is being lost. Fix the antimeridian-straddle in the CircleClip spine
  build (handle the lon ±180 crossing, or build the rim directly in projected/azimuth space since
  for an azimuthal projection the 179.5° horizon is an exact circle of radius `_polar_radius`-style).

**C2 — `nicol` (and `apian`/`bacon`/`ortel`): wrong CLIP DOMAIN — land genuinely spills.** These are
**whole-world** globular projections (every lon is finite; not hemisphere disks). `nicol` is untabled
→ falls to `AntimeridianClip`. Its spine (the projected antimeridian, a clean oval x∈±2.0e7,
y∈±1.0e7, well-sampled at 2.97% max chord) is the WRONG boundary: **1369/5224 clipped-land vertices
fall OUTSIDE it.** The projection is non-convex w.r.t. the antimeridian — e.g. `nicol(120°,60°) =
(6.08e6, 7.85e6)` sits *above* the rim point `nicol(180°,60°) = (7.14e6, 7.21e6)`, so interior
meridians bulge past the antimeridian. The true outer boundary is the **envelope of all meridians**,
not lon=±180.
- *Fix:* route `nicol`/`apian`/`bacon`/`ortel` to **`PolygonClip` via `_oblique_boundary`** (convex
  hull of the projected grid — the same machinery `spilhaus`/`ob_tran` use; the globular outline is
  smooth and ~convex so the hull is a good fit). Add the names to that branch in `clip_strategy`.
  **Verify first:** these need a working PROJ inverse for `_oblique_boundary`; if any lacks one it
  falls back to `ProjectedClip` (no spine) and needs a per-projection analytic boundary instead.

**Priority: medium.** Suggested order: C1 (`aeqd` spine, self-contained) then C2 (globular domain).

## Bucket D — gross smearing + wrong spine (oblique / multi-point family routed to AntimeridianClip)

**Symptom:** land polygons smear toward a single point outside the frame, half the map is missing,
and the spine is in the wrong place or runs along the antimeridian through the map interior. These
projections have a seam/domain that is **not** the geographic ±180° meridian, but they fall through
to the default `AntimeridianClip(lon0)`. This is the deferred "oblique family" work (see
`dev/general_splitting_plan.md` step 5).

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

**Fix approach (this slice, narrow):** special-case `tmerc`/`omerc` first since "blank" is the worst
look, and stop `tpeqd`/`chamb` drawing the antimeridian through the interior (even if not
pixel-perfect). The exotics (`bipc`, `imw_p`, `isea`, `lsat`) stay deferred / known-issues.
**Priority: medium for `tmerc`/`omerc`/`tpeqd`; low for the exotics.**

## Bucket E — square-boundary projections show rounded corners

**Symptom:** a projection whose true boundary is a square renders with rounded corners (and, for
Adams ws1, a stray boundary segment at an angle).

**Affected:** Spilhaus, Adams "World in a square I", Adams "World in a square II" (corners),
possibly General Oblique Transformation.

**Hypothesis:** `spilhaus`/`guyou` use the convex-hull PolygonClip whose Douglas–Peucker pass rounds
the corners (a documented workaround). The `adams_ws1`/`adams_ws2` variants aren't tabled at all, so
they hit the default AntimeridianClip and get neither a square clip nor a square spine.

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

---

## Suggested plan / order of attack

1. **Medium slice (next up — not started):**
   - Bucket C — see the measured **Findings** under Bucket C above; two separate fixes:
     **C1 `aeqd` spine** (CircleClip `boundary_points` drops the arc that straddles the antimeridian
     near the antipode → a full-width chord; the data/graticule clip is already correct, so fix the
     spine build, not the ring density) and **C2 globular domain** (`nicol`/`apian`/`bacon`/`ortel`
     are whole-world and non-convex vs the antimeridian → route to `PolygonClip`/`_oblique_boundary`,
     after verifying each has a PROJ inverse).
   - Bucket F — dedupe the antimeridian graticule overdraw.
   - Bucket D, narrow — make `tmerc`/`omerc` non-blank and stop `tpeqd`/`chamb` drawing the
     antimeridian through the interior (even if not pixel-perfect).
2. **Deferred / known-issues:**
   - Bucket D, exotics (`bipc`, `imw_p`, `isea`, `lsat`) and Bucket E (square corners) — document as
     known imperfect in a short note on the page rather than block the PR.
   - Bucket G — verify `ocea` orientation.

Re-render the gallery after each slice (`julia --project=docs docs/make.jl`, or the standalone
generator for structure) and eyeball the panels — per project convention, the figures are reviewed
visually, not asserted pixel-wise.

---

## Prior context — upstream follow-ups (NOT this PR)

When GeometryOps ships #417–#421 (spherical clip / arc intersection / point-in-polygon /
rings→nested-polygons / `GeographicFromUnitSphere` clamp), delete the matching bespoke code
(`_clip_against_polygon`+`_cp_*`, `_gc_intersect`, `_polygon_contains`, `_rings_to_polygons`,
`_sph`). Long-form draft: `dev/UPSTREAM_GEOMETRYOPS.md` (gitignored).
