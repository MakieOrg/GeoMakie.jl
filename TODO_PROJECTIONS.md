# TODO — projection gallery rendering issues

Working tracker for the visual problems in the `projections.md` gallery. Delete before the PR
merges. Issues are grouped by **root cause** (not by projection) so each fix lands once across all
the projections it affects. Buckets A, B, C, F and H (spine crop, pole smoothness, azimuthal/globular
clip-vs-spine, antimeridian graticule overdraw, polar tick labels) are done and have been removed.
Most of Bucket D is now fixed too — `tmerc`/`etmerc`/`omerc`/`tpeqd`/`chamb`/`lsat`/`isea`/`tobmerc`
(see below); only the genuinely-hard exotics remain. Bucket G (`ocea` "upside-down") was verified as
**correct PROJ output** — north-down is PROJ's bare-`+proj=ocea` oblique aspect, reproduced to 0 m and
not mirrored, so do **not** add a flip. What remains is the deferred work: the Bucket D exotics
(`bipc`/`imw_p`/`guyou`, minor `oea`) and Bucket E.

## How the rendering works (the three knobs every issue touches)

1. **The spine / projection boundary** is computed by `boundary_points(dest, src)` in
   `src/sphere_clip.jl`, dispatched per clip strategy. AntimeridianClip boundaries are densified then
   adaptively resampled; CircleClip builds the limb as an exact circle in projected space (centre =
   projected projection-centre, radius = max projected horizon distance — robust to the ellipsoidal
   antipode instability of `aeqd`); PolygonClip uses a convex hull of the projected grid
   (`_oblique_boundary`).
2. **The clip strategy** is chosen in `clip_strategy(t)` (`src/sphere_clip.jl`), keyed on the PROJ
   name. Anything untabled falls through to `AntimeridianClip(lon0)` — including all the oblique /
   multi-point projections that are actually broken (see Bucket D).
3. **The axis limits** fit to the plotted data, then snap to / clamp within the spine's bounding box
   (`Makie.getlimits`, `src/makie-axis.jl`).

---

## Bucket D — gross smearing + wrong spine (oblique / multi-point family routed to AntimeridianClip)

**Symptom:** land polygons smear toward a single point outside the frame, half the map is missing,
and the spine is in the wrong place or runs along the antimeridian through the map interior. The
shared *trigger* is falling through to the default `AntimeridianClip(lon0)`, but the underlying causes
turned out to be **several distinct issues**, each with its own remedy (in `clip_strategy`):

**DONE:**
- **Degenerate spine + ∞ zone singularity → CircleClip ~85° cap.** `tmerc`/`etmerc`/`omerc` were
  **blank**: their "antimeridian" is the back of the central axis (collapses to x≈0 → degenerate
  spine), and `tmerc` blows to ∞ at (lon_0±90°, 0). The cap around (lon_0, lat_0) excludes the
  singularity and frames the usable zone. (A general `omerc` centred away from (lon_0, lat_0) would
  need its true centre; the gallery's prime-meridian aspect is centred there.)
- **Continuous, no real seam → NoClip.** `tpeqd`/`chamb` (compromise globes), `lsat` (space-oblique
  track), `isea` (icosahedral net) are continuous across ±180° (periodic, f(-180)≡f(180); a
  dateline step ≈ a mid-map step), so AntimeridianClip only *tears* an interior line. (For `isea` the
  NoClip spine is the projected lon/lat frame — an approximation of the true icosahedron-net outline.)
- **Correct seam, just unbounded poles → ±lat clamp.** `tobmerc`'s antimeridian already maps to the
  left/right edges; it only had the Mercator "pole smear" (y→∞), fixed by the same ±85° clamp as
  `merc`.

**Still deferred — genuinely hard:**
- **∞ on the graticule, no native frame:** Bipolar Conic (`bipc`, two cones), International Map of the
  World Polyconic (`imw_p`, blows up across a lat band) — need per-cone / banded domains.
- **No PROJ inverse → no spine:** Guyou (`guyou`) falls to `ProjectedClip`; land draws but there is no
  analytic boundary (needs a native square frame).
- **Minor/cosmetic:** Oblated Equal-Area (`oea`, already `PolygonClip`, slight top smear).

**Priority: low.** Document as known-imperfect rather than block the PR.

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

---

## Suggested plan / order of attack

The medium slice is done (Bucket F; Bucket D narrow), most of Bucket D's exotics are fixed
(`lsat`/`isea`→NoClip, `tobmerc`→pole clamp), and Bucket G is verified. What remains is all
deferred / known-issues:

- Bucket D — genuinely hard: `bipc`/`imw_p` (∞ on the graticule, no native frame), `guyou` (no PROJ
  inverse → no spine); minor `oea` (already PolygonClip, slight top smear). And Bucket E (square
  corners) — document as known-imperfect in a short note on the page rather than block the PR.

Re-render the gallery after each slice (`julia --project=docs docs/make.jl`, or the standalone
generator for structure) and eyeball the panels — per project convention, the figures are reviewed
visually, not asserted pixel-wise.

---

## Prior context — upstream follow-ups (NOT this PR)

When GeometryOps ships #417–#421 (spherical clip / arc intersection / point-in-polygon /
rings→nested-polygons / `GeographicFromUnitSphere` clamp), delete the matching bespoke code
(`_clip_against_polygon`+`_cp_*`, `_gc_intersect`, `_polygon_contains`, `_rings_to_polygons`,
`_sph`). Long-form draft: `dev/UPSTREAM_GEOMETRYOPS.md` (gitignored).
