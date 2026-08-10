# Review: PR #381 — sphere-space clipping + resampling

> Claude Code review of https://github.com/MakieOrg/GeoMakie.jl/pull/381, 2026-07-29.
> Scope: the GitHub PR diff (27 files, +5264/−86) plus a full read of the new sources
> (`src/sphere_clip.jl`, `src/polar.jl`, `src/contoursplitting_geo.jl`) and both new test files.
> Note: the branch previously merged `origin/master`, so a few things the PR body mentions
> (geoid example, globeaxis tests) are already on master and no longer part of this diff.
> **Delete this file before the PR merges** (like `TODO_PROJECTIONS.md`).

## Overview

Ports d3-geo's `rotate → preclip → resample` architecture into GeoMakie so fills, lines,
graticules, `surface!`/`heatmap!`, and `meshimage` clip correctly at projection seams and
horizons. Adds a `clip_strategy` registry keyed on PROJ name (antimeridian / circle / oblique /
polygon / projected-jump clips), an "Option B" centred-frame drawing path to defeat PROJ's
longitude-wrap collapse, spherical winding for ring orientation, a projection-domain spine wired
into auto-limits (cartopy-style clamp), a new `GeoPolarAxis` block, and a generated
per-projection docs gallery. CI is green on both checks.

**Overall: high quality.** The port is faithful and unusually well-annotated — every non-obvious
deviation from d3 (the `_normalize3` zero-vector guard, the seam nudge, the winding-regime
split, why GeometryOps delegation stops where it does) carries a why-comment, and the tests
encode regression guards that prove the old behavior was actually broken (e.g. asserting
`planar_worst > 1e14` in `test/sphere_clip.jl:218`). The findings below are mostly
packaging/hygiene and edge cases, not core-algorithm problems.

## Must fix before merge

- **CairoMakie is now a hard dependency** (`Project.toml:7`, compat at line 27). Nothing in
  `src/` uses it — it's only needed by tests/docs, and it's already in `[extras]` + the test
  target. This looks like an accidental `Pkg.add` in the package env; it would drag a full
  backend into every GeoMakie install. Remove it from `[deps]`/`[compat]`.
- **Leftover work-tracker artifacts committed**: `HANDOFF_poles.png` (binary, repo root) and
  `TODO_PROJECTIONS.md`, whose own header says *"Delete before the PR merges."* Delete both (or
  move the tracker content into the PR description / an issue — the "remaining known-imperfect"
  list is worth preserving somewhere).
- **No version bump**: still `0.7.16` despite a new export (`GeoPolarAxis`), a required compat
  bump (GeometryOps `0.1.6 → 0.1.28`), and user-visible default changes — grid alpha
  `0.5 → 0.12` (`src/geoaxis.jl:208`), a spine drawn by default, tight-limits now keeping a 1%
  margin, and the heatmap semantics change (below). At minimum `0.7.17`; the visual-default
  changes arguably justify `0.8.0`.

## Bugs / correctness risks

- **Per-vertex line colors will error** on the seam-aware `lines!` path:
  `src/contoursplitting_geo.jl:198-219` forwards `color = plot.color` onto the resampled line,
  whose vertex count differs from the input. The `Contour` path guards exactly this (line 180
  falls back to `:black`); the generic `Lines` path doesn't. Untested, and would throw on
  `lines!(ga, pts; color = 1:n)`.
- **Seam-split `poly!` coverage gap**: only `Poly{<:Tuple{<:AbstractVector{<:Polygon}}}` is
  intercepted (`src/contoursplitting_geo.jl:135`). A single `Polygon` or a `MultiPolygon`
  argument takes the generic path and still smears across the seam — surprising given
  `_collect_polys` already handles both. Consider widening the dispatch, or documenting the
  limitation.
- **Guard asymmetry in rejoin**: `_cp_rejoin` has a runaway-iteration cap
  (`src/sphere_clip.jl:776`) precisely because a malformed derived boundary can spin the
  entry/exit walk, but the antimeridian/circle `_rejoin` (`src/sphere_clip.jl:1182-1246`) has
  the same `while true` structure with no cap. Faithful to d3, but since the guard was added to
  one port, the other deserves it too — degenerate input hangs the render loop otherwise.
- **`add_cyclic_point` is documented as if exported but isn't**: the docstring examples in
  `src/utils.jl` call it unqualified, while `examples/tripolar.jl:54` must use
  `GeoMakie.add_cyclic_point`. Either export it or qualify the docstring examples.
- **`GeoPolarAxis` attributes are init-only**: `latcap`, `dest`, `direction`, etc. are read once
  in `initialize_block!` (`src/polar.jl:186`); setting `gpa.latcap[] = ...` later silently does
  nothing, which breaks the usual Block expectation of reactive attributes. Worth a docstring
  note if full reactivity is out of scope.

## Minor / polish

- `_SPINE_SNAP = 0.1` (`src/makie-axis.jl:271`): snapping limits out to the full projection
  domain whenever data comes within 10% of an edge is a fairly aggressive heuristic — a regional
  map whose data legitimately ends near the domain edge will suddenly frame the whole world.
  Consider a smaller tolerance or an opt-out.
- `heatmap!` on a GeoAxis now renders as a vertex-colored mesh between *cell centres*
  (`src/contoursplitting_geo.jl:228-259`): colors interpolate across cells and the outer
  half-cells are trimmed — a real semantics change from flat-cell heatmaps that deserves a line
  in the docs/changelog.
- `_BOUNDARY_CACHE` (`src/sphere_clip.jl:465`) is a global, unbounded, non-thread-safe `Dict`
  mutated via `get!` — fine in practice, but a `Threads.@spawn`-ed first plot on two oblique
  projections could race.
- The `spine_reentry` cap of 8 (`src/geoaxis.jl:694`) bounds the layout feedback loop rather
  than fixing convergence — acceptable and well-commented, just noting it's a mitigation.
- Type piracy on `DocumenterVitepress.mime_priority` in `docs/make.jl:29` — acknowledged inline,
  docs-build-only, fine.
- `poly!(gpa::GeoPolarAxis, ...)` hardcodes `color = :gray70` (bypasses theme cycling), and its
  stroke is a separate `lines!` not tied to the returned plot (hiding/deleting the fill won't
  remove the stroke) — `src/polar.jl:323-335`.
- `src/utils.jl` lost its trailing newline; `authors` line churn in `Project.toml`.

## Tests & performance

- Test coverage is strong: d3-oracle unit tests for the intersection primitives, resampler
  direction-symmetry, clip-strategy dispatch for every bucket, no-smear and spine-shape
  regression guards, full render smoke tests, and an SVG assertion that polar fills stay
  vector. Gaps: `add_cyclic_point` has no unit test, and the per-vertex line-color path (bug
  above) is untested.
- Performance work is real and documented (O(1) off-map face drop, projected-extent seam test in
  `src/mesh_image.jl`). One note: `_oblique_boundary` projects a 721×359 grid (~260k PROJ
  round-trips, each in try/catch) on first use of an oblique-square projection — cached per def
  string, so a one-time hit; fine, but worth knowing.
- Security: nothing concerning; the examples' network fallbacks (GADM try/catch) are a nice
  touch for docs resilience.

## Verdict

Approve with changes — the three "must fix" items (CairoMakie dep, leftover tracker files,
version bump) are quick mechanical fixes; the per-vertex line-color bug and the `_rejoin` guard
are the only code changes wanted before merge. Everything else can be follow-up.
