# HANDOFF — streamline `sphere_clip.jl` onto lower-level deps

*(Temporary working note for the next session. Delete before the PR merges.)*

## Mission

The PR on branch `bp-claued/sphere_clip_resampling` adds seam-aware clipping + adaptive
resampling for `GeoAxis` (`src/sphere_clip.jl` ≈ 1660 lines + `src/contoursplitting_geo.jl`).
It is a faithful port of d3-geo / d3-geo-polygon. **Goal of the next pass:** push as much of the
*generic geometry* down into the lower-level packages (`GeometryOps`, `GeometryBasics`,
`GeoInterface`, …) as makes sense, so GeoMakie keeps only what is genuinely GeoMakie-specific.

Guiding principles:
- **Prefer the dep's implementation** over our bespoke one — *but only if it is at least as
  correct and as fast.* If the dep is slower or missing a feature, **file an issue / open a PR
  upstream** rather than keeping a private copy. The wheel should live under the lower-level
  package so every downstream user benefits.
- **Don't bloat the deps with GeoMakie-only concepts** (PROJ pipeline-string parsing, the
  "Option B" centred-frame trick, the projection-adaptive resampler keyed to *projected* error,
  the Makie recipe overrides). Where a primitive is generally useful (e.g. spherical
  point-in-polygon), upstream it; where it's GeoMakie glue, keep it here.
- **Correctness guardrail:** `test/sphere_clip.jl` (8 testsets) already covers the dispatch,
  great-circle intersection oracle, resampler symmetry, no-smear split, boundary points, and the
  recipe renders for moll/spilhaus/igh/bertin. Keep it green through every swap. Add a numeric
  before/after diff for any geometry you delegate.

## Already done (commit `2311bd2`)

- Deleted ~75 lines of dead code (`_ring_contains`/`_inside_polygon`, `_planar_pip`/
  `_planar_inside`, `_ring_area_sph`, `_rewind_small`, the spilhaus conformal-rotation block).
- **Delegated the two planar helpers** used on the already-projected oblique-square outline:
  `_convex_hull` → `GO.convex_hull` (DelaunayTriangulation monotone-chain) and `_dp_simplify`
  → `GO.simplify(GO.DouglasPeucker(; tol=…))`. Added `_exterior_open(poly)` to read the GI ring
  back. Validated: spilhaus `_oblique_boundary` still yields a 400-pt ring, `clip_strategy` ⇒
  `PolygonClip`, full suite 140/140.
- De-duplicated `childfunc` (→ `_child_transformfunc`) and fixed a stale comment in
  `contoursplitting_geo.jl`. Updated the module header note (GO *does* now have spherical clip/area).

## This session — outcome summary

Investigated every roadmap item against the installed deps (GeometryOps **0.1.40**,
GeometryBasics 0.5.11, GeoInterface 1.6.1, Geodesy 1.2.0, CoordinateTransformations 0.6.4).
Net code change is small and conservative; the bigger deliverable is *evidence* of where
delegation is and isn't possible. sphere_clip testset stays **green** (8 testsets) throughout.

- **DONE — version compat fixed.** `Project.toml` `GeometryOps` `0.1.6` → **`0.1.28`**. The old
  bound was already wrong (the existing `GO.forcexyz` usage needs ≥0.1.15); 0.1.28 is the first
  tag shipping the `UnitSpherical` submodule we now use.
- **DONE — P2 primitives (pushed as far as correctness+perf allow).** Delegated to
  `GeometryOps.UnitSpherical` every spherical primitive where the swap is **at least as correct and
  as fast** (the stated bar):
  | helper | → delegated to | evidence |
  |---|---|---|
  | `_geo_interp` | `slerp` | ≡ old to ≤6e-14 (non-antipodal); antipodal-robust; neutral in boundary build |
  | `_gcdist_deg` | `spherical_distance` | ≡ old to 8.5e-7° |
  | `_cart` | `UnitSphereFromGeographic` | identical maths; 1.7 ns ≡ 1.7 ns; 0 allocs |
  | `_cp_dist` | `spherical_distance` (+`UnitSphericalPoint` wrap) | same atan2 form; 0 allocs |

  **Evaluated and deliberately KEPT** (each fails the bar — these are the upstream asks):
  | helper | why kept | upstream fix that would unblock |
  |---|---|---|
  | `_gc_intersect` | GO's `spherical_arc_intersection` is **correct** (matches incl. the degenerate-zero-length guard) but **allocates** 4×/240 B per call; ours is alloc-free and runs in the `_cp_clip_line` hot loop | an allocation-free / in-place arc-intersection variant |
  | `_sph` | `GeographicFromUnitSphere` does **not** `clamp(z,-1,1)` → `DomainError` on FP `|z|>1` | clamp `asind` arg upstream |
  | `_cartr` / `_sphr` | radian-native (hot clip); UnitSpherical is degrees-only → a rad→deg→rad round-trip regresses the loop | a radians entry point |
  | `_dot3`/`_cross3`/`_normalize3` | generic ℝ³ vector ops (LinearAlgebra), not geo primitives; on `NTuple` they're alloc-free and trivial | n/a |

  The d3 line-by-line ports (`_polygon_contains`, `_antimeridian_stream`, `_circle_*`, `_cp_*`) stay
  hand-rolled — they mirror the d3-geo source verbatim (the verifiability guardrail) and a type
  migration to `UnitSphericalPoint` buys no perf.
- **NOT FEASIBLE — P1 spherical clip.** GO's Foster–Hormann clip computes edge intersections with
  **planar** lon/lat math for *every* manifold: `_intersection_point(manifold::M, …)` →
  `_find_cross_intersection` is a 2-D parametric line solve, and the orientation predicates are
  planar. The GO source flags it: *"this is suitable for planar but spherical/geodesic will need
  s2 support at some point"* (`clipping_processor.jl`). Routing `_clip_against_polygon` through
  `GO.intersection(GO.Spherical(), …)` would replace true great-circle arc intersection with a
  planar lon/lat solve — a correctness regression exactly on the seam-crossing edges this code
  exists for. Keep our port; **upstream candidate** = a GO issue for s2/true-spherical clipping.
- **NOT A CLEAN DROP-IN — P3 segmentize.** `GO.segmentize` exposes only `Planar()` and
  `Geodesic()`; `segmentize(::Manifold, …)` silently falls back to `Planar()`. For `_densify_geo`
  (great-circle arcs over lon/lat°), `Planar` is geometrically wrong (straight lon/lat lines) and
  `Geodesic` is ellipsoidal, in metres, and needs Proj + whole-geometry GI wrapping. No unit-sphere
  mode exists. The underlying great-circle *interpolation* is nonetheless now delegated (via
  `slerp`); the densify *loop* (angular, K-points-per-edge, NTuple) stays ours.
- **NO DROP-IN — P4 ring nesting.** GO has hole-assignment logic but only **inside**
  `polygonize` (raster-based), not as a public helper, and it differs from `_rings_to_polygons`:
  it splits exterior/hole by **winding direction** (not even-odd containment *depth*), nests in
  **native** space (we need **projected** space so seam pieces at opposite map edges separate),
  and uses planar `covers`. Genuinely different requirements → **maintainer decision** whether GO
  should grow a generic `rings → nested polygons by depth` helper.

## Roadmap — what to delegate next (priority order)

Investigated against the **installed dev versions**: GeometryOps **0.1.40** (has a real
`Spherical()` manifold + `UnitSpherical` submodule), GeometryBasics 0.5.11, GeoInterface 1.6.1,
Geodesy 1.2.0, CoordinateTransformations 0.6.4. (Geodesy/CoordinateTransformations turned out
**orthogonal** — ellipsoid/ECEF-in-metres and math-spherical-radians-without-rotations — so the
rotation/cartesian/distance code is *not* reinvention of those two.)

### P1 — ❌ NOT FEASIBLE (GO spherical clip is planar-math) — the `PolygonClip` spherical-clip path → `GO.intersection(GO.Spherical(), …)`
**Verdict (this session):** GO's `Spherical()` Foster–Hormann clip still intersects edges with planar
lon/lat math (`_intersection_point`/`_find_cross_intersection` in `intersection.jl` are 2-D; source
comment: "spherical/geodesic will need s2 support at some point"). Delegating regresses correctness
on seam-crossing edges. Keep the port; file a GO issue for true-spherical clipping. Detail below.

Biggest single win (~217 lines): `_cp_clip_line` + `_cp_rejoin` + `_cp_interpolate!` +
`_clip_against_polygon` (lines ~560–780) implement a d3-geo-polygon `clipPolygon`. GO 0.1.40's
Foster–Hormann clipping (`src/methods/clipping/`) explicitly supports the `Spherical()` manifold.
- **Spike:** clip the same subject (`land()`) against an oblique-square / interrupted-lobe boundary
  with both paths; diff the resulting rings and **benchmark** both.
- **Risks to check:** (a) GO's spherical Foster–Hormann maturity; (b) whether the boundary-walk
  "interpolate along clip edges" semantics survive (d3 walks the boundary between exit/entry —
  confirm GO reproduces the same fill); (c) winding/orientation conventions (we currently rewind
  by role in `_split_polygon`).
- If GO is correct but slower, profile and PR upstream; if it's missing the boundary-walk fill,
  raise it as a GO issue.

### P2 — ✅ DONE (partial): `_geo_interp`→`slerp`, `_gcdist_deg`→`spherical_distance`; primitives/ports kept
**Verdict (this session):** benchmarked neutral, numerically verified; delegated the two non-port
helpers. Kept the `NTuple{3}` math + d3 ports (identical perf, mirror d3 source). Detail below.

Exact analogues exist (`src/utils/UnitSpherical/`):
| sphere_clip.jl | UnitSpherical |
|---|---|
| `_cart` / `_sph` (lon/lat° ↔ unit xyz) | `UnitSphereFromGeographic` / `GeographicFromUnitSphere` |
| `_dot3` / `_cross3` / `_normalize3` (on `NTuple{3}`) | `UnitSphericalPoint` + `LinearAlgebra` / `robust_cross_product` |
| `_gc_intersect` / `_IxSeg` | `spherical_arc_intersection` |
| `_cp_dist` (geodesic angle) | `spherical_distance` |
| `_geo_interp` (great-circle interp) | `slerp` |
| `_geo_area` / (removed `_ring_area_sph`) | `GO.area(GO.Spherical(), ring)` |
- Modest LOC saving and it **adds per-call conversion** (`NTuple` ↔ `UnitSphericalPoint`/SVector).
  **Benchmark first** — these run in hot loops (resampler, clip). Only swap if neutral-or-faster.
  This is a prime case where "keep the wheel upstream" may conflict with perf: if UnitSpherical is
  slower in our access pattern, PR an allocation-free path upstream rather than keeping ours.

### P3 — ⚠️ NOT A CLEAN DROP-IN (no unit-sphere segmentize) — densify → `GO.segmentize(GO.Spherical(); max_distance)`
**Verdict (this session):** `segmentize` has only `Planar()` (wrong geometry for us) and `Geodesic()`
(ellipsoidal/metres/Proj); `::Manifold` falls back to `Planar()`. Great-circle interpolation now goes
via `slerp`; the angular K-per-edge densify loop stays ours. Detail below.

`_densify_geo` / the great-circle densify loops are non-adaptive — a clean match for `segmentize`.
Note `resample_sphere` is **not** this (see "must stay" below).

### P4 — ⚠️ NO DROP-IN (GO nesting is internal/winding-based/native-space) — ring nesting (`_rings_to_polygons`, ~75 lines)
**Verdict (this session):** GO's hole assignment lives only inside `polygonize` (raster), splits by
winding not even-odd depth, and nests in native (not projected) space. Different requirements →
maintainer decision on a generic `rings→nested-polygons` helper. Detail below.

Rebuilds polygons-with-holes from a flat ring set by containment depth (Makie needs explicit
holes; d3 uses even-odd). `GO.polygonize` is **raster-based**, not ring-nesting, so no drop-in
today. **Candidate to upstream**: a "rings → nested polygons" helper is generally useful and a
natural GeometryOps addition. Decide with the GO maintainers whether it belongs there.

## What must stay in GeoMakie (no GO equivalent / GeoMakie-specific)

- **`resample_sphere`** — adaptive bisection keyed to *projected* straightness with a
  per-projection `scale`. `segmentize` is sphere-distance-based and projection-blind. A
  "projection-aware adaptive segmentize" could *in principle* be upstreamed, but it's arguably
  GeoMakie's concern (it needs the destination projector). **Discussion point with maintainers.**
- **Antimeridian + circle seam drivers** (`clip/antimeridian.js`, `circle.js` ports) — the
  antimeridian is a *topological periodicity cut*, not a polygon∩polygon. The circle horizon could
  map to a `SphericalCap` clip (GO has `SphericalCap`) — worth a look — but the antimeridian
  likely stays.
- **`_polygon_contains`** (winding spherical point-in-polygon) — GO's predicates
  (`contains`/`within`/…) are **planar only**. This is the clearest **upstream-PR candidate**:
  GO has a `Spherical()` manifold for area/clip but not for the geom-relation predicates — adding
  a spherical PIP there fills an obvious gap and lets us delete ours.
- **`clip_strategy` registry, `_NativeCentred`/bertin, Option B centred-frame, recipe overrides** —
  PROJ-string + Makie-specific glue. Keep here.

## Version / compat caveat — ✅ DONE

`Project.toml` `GeometryOps` bound raised `0.1.6` → **`0.1.28`** this session.
- `0.1.6` was already incorrect: the existing `GO.forcexyz` usage (utils.jl) needs **≥0.1.15**.
- `UnitSpherical` (the `slerp`/`spherical_distance` we now use) first ships in **v0.1.28**
  (commit `65c1f7a13`, "include in GeometryOps proper", 2025-04-03).
- The caret `0.1.28` still admits the tested 0.1.40. Resolves clean; suite green.

## How to verify

```julia
# fast: just the sphere-clip testset
julia --project=. -e 'using TestEnv; TestEnv.activate(); include("test/sphere_clip.jl")'
# full suite (≈40s after precompile, 140 tests)
julia --project=. -e 'using Pkg; Pkg.test("GeoMakie")'
```
For any delegation, add a temporary before/after numeric diff (e.g. compare `_oblique_boundary` /
`split_geometry` output ring-by-ring) and a `@btime` benchmark; keep the swap only if correct and
not slower.

## File / line reference (post-cleanup)

- `src/sphere_clip.jl` — math primitives (40–110); resampler (110–210); spherical PIP + area
  (210–300); strategy types (300–410); boundary derivation / `_oblique_boundary` (410–500);
  **`PolygonClip` clip (560–780) ← P1**; rotations + bertin (740–820); generic clip driver +
  antimeridian/circle clippers (840–1060); rejoin + `_clip_polygon` (1060–1180); `_rings_to_polygons`
  (1180–1260 ← P4); I/O + `split_geometry`/`split_resample_line`/`boundary_points` (1260–1570);
  `clip_strategy` registry (1570–1660).  *(ranges approximate — grep for the function.)*
- `src/contoursplitting_geo.jl` — recipe overrides for `Contourf`/`Contour`/`Poly`/`Lines`/
  `Surface`/`Heatmap` on `GeoAxis`. Shares `_clip_faces`/`_mesh_projector` with `mesh_image.jl`.

## Upstream issues → drafted in `dev/UPSTREAM_GEOMETRYOPS.md`

The investigation answered the old open questions; the gaps are written up as ready-to-file
GeometryOps issues (per maintainer request, drafts only — not yet posted):
1. `Spherical()` clipping is planar-math (Issue 1) — the P1 blocker.
2. Allocation-free `spherical_arc_intersection` (Issue 2) — would unblock delegating `_gc_intersect`.
3. Spherical point-in-polygon predicate (Issue 3) — would let us delete `_polygon_contains`.
4. Public rings→nested-polygons-by-depth helper (Issue 4) — the P4 question.
   Plus minor nits: `GeographicFromUnitSphere` should `clamp`; a radians transform for hot loops.

Still genuinely GeoMakie-side (confirmed, not upstream): the **projection-adaptive resampler**
(`resample_sphere`, keyed to *projected* error via a per-projection `scale`), the
antimeridian/circle seam drivers, and the `clip_strategy`/Option-B/recipe glue.
