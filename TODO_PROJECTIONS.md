# TODO — projection gallery rendering issues

Working tracker for the visual problems in the `projections.md` gallery. Delete before the PR
merges. Issues are grouped by **root cause** (not by projection) so each fix lands once across all
the projections it affects. Buckets A, B, C, F and H (spine crop, pole smoothness, azimuthal/globular
clip-vs-spine, antimeridian graticule overdraw, polar tick labels) are done and have been removed,
and the narrow slice of D (`tmerc`/`omerc`/`tpeqd`/`chamb`); what remains is the deferred work.

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
and the spine is in the wrong place or runs along the antimeridian through the map interior. These
projections have a seam/domain that is **not** the geographic ±180° meridian, but they fall through
to the default `AntimeridianClip(lon0)`. This is the deferred "oblique family" work (see
`dev/general_splitting_plan.md` step 5).

**Narrow slice — DONE** (in `clip_strategy`):
- `tmerc`/`etmerc`/`omerc` were **blank**: their antimeridian seam is the back of the central axis,
  which collapses to x≈0 (degenerate spine → blanked panel), and `tmerc` also blows up to ∞ at the
  zone singularity (lon_0±90°, 0). Routed to a `CircleClip` ~85° cap around (lon_0, lat_0), which
  excludes the singularity and frames the usable zone. (A general `omerc` centred away from
  (lon_0, lat_0) would need its true centre; the gallery's prime-meridian aspect is centred there.)
- `tpeqd`/`chamb` drew the **antimeridian through the interior**: they are continuous whole-globe
  (periodic, f(-180)≡f(180)), so they're routed to `NoClip` — no seam, no tear.

**Still deferred (exotics):** Space Oblique / Landsat (`lsat`), Bipolar Conic (`bipc`), International
Map of the World Polyconic (`imw_p`), Icosahedral Snyder (`isea`) — these have ∞ on the graticule and
**no native working frame**; they need a rotated/native frame or a per-projection domain (genuinely
hard). Also minor: Tobler–Mercator (`tobmerc`, pole smear), Oblated Equal-Area (`oea`, slight top
smear), Guyou (no spine — inverse unavailable, falls to ProjectedClip). **Priority: low.** Document
as known-imperfect rather than block the PR.

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

## Bucket G — orientation / sanity checks — VERIFIED, no code fix

- **Oblique Cylindrical Equal-Area (`ocea`)** — the north-at-bottom look is **PROJ's own output, not a
  GeoMakie bug.** Verified: (1) GeoMakie's projector equals a raw `Proj.Transformation` for `ocea` to
  **0 m** (no flip injected); (2) the GeoAxis pipeline has no global flip (`eqc` is north-up, 90°E at
  right); (3) `ocea` is **orientation-preserving** (signed-area sign matches `eqc`/`cea`, so it is
  *not* mirrored — continents aren't backwards). PROJ's `ocea` places the N pole at y=−R, S pole at
  y=+R for the gallery's **bare `+proj=ocea`** (an unparameterized/degenerate oblique aspect — no
  `lonc`/`alpha`/`lat_1`…). Do **not** add a flip (it would diverge from PROJ). *Optional gallery
  tweak (not a fix):* give the panel explicit oblique params for a more conventional look.

---

## Suggested plan / order of attack

The medium slice is done (Bucket F; Bucket D narrow). What remains is all deferred / known-issues:

- Bucket D exotics (`bipc`, `imw_p`, `isea`, `lsat`; minor `tobmerc`/`oea`/`guyou`) and Bucket E
  (square corners) — document as known-imperfect in a short note on the page rather than block the PR.
- Bucket G — DONE (verified `ocea` is correct PROJ output, not a bug; see above).

Re-render the gallery after each slice (`julia --project=docs docs/make.jl`, or the standalone
generator for structure) and eyeball the panels — per project convention, the figures are reviewed
visually, not asserted pixel-wise.

---

## Prior context — upstream follow-ups (NOT this PR)

When GeometryOps ships #417–#421 (spherical clip / arc intersection / point-in-polygon /
rings→nested-polygons / `GeographicFromUnitSphere` clamp), delete the matching bespoke code
(`_clip_against_polygon`+`_cp_*`, `_gc_intersect`, `_polygon_contains`, `_rings_to_polygons`,
`_sph`). Long-form draft: `dev/UPSTREAM_GEOMETRYOPS.md` (gitignored).
