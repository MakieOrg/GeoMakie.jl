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

## Already done this session (commit `2311bd2`)

- Deleted ~75 lines of dead code (`_ring_contains`/`_inside_polygon`, `_planar_pip`/
  `_planar_inside`, `_ring_area_sph`, `_rewind_small`, the spilhaus conformal-rotation block).
- **Delegated the two planar helpers** used on the already-projected oblique-square outline:
  `_convex_hull` → `GO.convex_hull` (DelaunayTriangulation monotone-chain) and `_dp_simplify`
  → `GO.simplify(GO.DouglasPeucker(; tol=…))`. Added `_exterior_open(poly)` to read the GI ring
  back. Validated: spilhaus `_oblique_boundary` still yields a 400-pt ring, `clip_strategy` ⇒
  `PolygonClip`, full suite 140/140.
- De-duplicated `childfunc` (→ `_child_transformfunc`) and fixed a stale comment in
  `contoursplitting_geo.jl`. Updated the module header note (GO *does* now have spherical clip/area).

## Roadmap — what to delegate next (priority order)

Investigated against the **installed dev versions**: GeometryOps **0.1.40** (has a real
`Spherical()` manifold + `UnitSpherical` submodule), GeometryBasics 0.5.11, GeoInterface 1.6.1,
Geodesy 1.2.0, CoordinateTransformations 0.6.4. (Geodesy/CoordinateTransformations turned out
**orthogonal** — ellipsoid/ECEF-in-metres and math-spherical-radians-without-rotations — so the
rotation/cartesian/distance code is *not* reinvention of those two.)

### P1 — the `PolygonClip` spherical-clip path → `GO.intersection(GO.Spherical(), …)`
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

### P2 — low-level spherical primitives → `GeometryOps.UnitSpherical`
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

### P3 — densify → `GO.segmentize(GO.Spherical(); max_distance)`
`_densify_geo` / the great-circle densify loops are non-adaptive — a clean match for `segmentize`.
Note `resample_sphere` is **not** this (see "must stay" below).

### P4 — ring nesting (`_rings_to_polygons`, ~75 lines)
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

## Version / compat caveat (do this before relying on Spherical)

`Project.toml` pins `GeometryOps = "0.1.6"`. The caret bound technically admits 0.1.40, but the
`Spherical()` manifold / `UnitSpherical` / spherical Foster–Hormann landed **well after** 0.1.6.
To depend on them, **raise the lower bound** to whichever 0.1.x introduced the manifold refactor
(check the GO changelog/registry; `GeometryOpsCore` owns the manifold types) so users don't
resolve to a version that `MethodError`s. Treat the spherical API as comparatively new — verify,
don't assume.

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

## Open design questions for the maintainers

1. Where is the GeoMakie↔GeometryOps boundary for the **projection-adaptive resampler**? (Likely
   GeoMakie, but worth confirming.)
2. Will GO accept a **spherical point-in-polygon predicate** and a **rings→nested-polygons** helper?
3. Is `UnitSpherical` allocation-free enough for our hot loops, or do we PR a faster path?
