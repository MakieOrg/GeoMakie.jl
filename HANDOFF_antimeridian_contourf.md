# Handoff: antimeridian-aware `contour` / `contourf` on `GeoAxis`

**Status: UNFINISHED / WIP — do not ship.** Filled `contourf` is correct for the
common cases but still has a known rendering residual at `lon_0 = 180` with
multi-extremum fields (see "Known bugs" below). This document is the handoff for
the next agent.

Branch: `bp-claued/contours_across_antimeridian` (GeoMakie).

---

## 1. Goal

Make `contour!` / `contourf!` on a `GeoAxis` render correctly when the contour
geometry crosses the projection's **antimeridian** (`lon_0 ± 180`). Without this,
a contour edge whose endpoints straddle the seam projects into a horizontal
"smear" across the whole map. Must also work for **curvilinear** grids (2-D x/y
coordinate matrices), e.g. Oceananigans tripolar ocean grids
([Makie.jl#4885](https://github.com/MakieOrg/Makie.jl/issues/4885)).

---

## 2. Architecture (how it works)

GeoMakie does **not** type-pirate Makie's recipes. The hook is the GeoMakie-owned
axis-level dispatch:

- `Makie.plot!(axis::GeoAxis, plot::Makie.Contourf)` and `… ::Contour` in
  `src/contoursplitting_geo.jl`.
- Each calls `_geoaxis_plot!(axis, plot)` (extracted from the generic
  `plot!(::GeoAxis, ::AbstractPlot)` in `src/geoaxis.jl`) which builds the
  standard Makie recipe child (`Poly` for contourf, `Lines` for contour) and
  injects the `transform_func`.
- Then it `register_computation!`s a split node on the plot's compute graph
  (`[:polys, :computed_colors, :transform_func] -> [:split_polys, :split_colors]`
  for contourf; `[:masked_lines, :contour_colors, :transform_func] ->
  [:split_lines, :split_line_colors]` for contour), **deletes** the recipe's
  child plot, and **re-creates** it reading the split node.
- The split is a no-op unless `transform_func` is a `Proj.Transformation`
  (`_antimeridian_lon0` returns `nothing` otherwise → plain `Axis` unaffected).

**Why delete+recreate** (not just rebind): a recipe child built from `poly!(c,
c.polys)` has its positional arg wired to the parent `Computed` via a cross-graph
edge; you can't re-source that edge (`register_computation!` refuses to redefine
an output with different inputs). Recreating is the working approach; verified it
renders (atomic recipe children live in `plot.plots`, not `scene.plots`, and the
backend walks `plot.plots`). See the long comment block at the top of
`src/contoursplitting_geo.jl`.

### Pipeline
`contour in lon/lat (data) space  →  split at lon_0 ± 180 in lon/lat  →  project
last (per-vertex, via the child plot's own transform_func)`. Splitting must happen
in lon/lat because the antimeridian is only a well-defined straight seam there.

### Splitting algorithm (`src/polygonsplitting.jl`)
- **Polygons (`split_polygon`)**: clip the polygon against each 360°-wide
  longitude strip `[lon0-180+360k, lon0+180+360k]` with
  `GeometryOps.intersection`, translate each clipped piece back into
  `[lon0-180, lon0+180]`. Abutting strip boundaries coincide after translation →
  pieces tile exactly. Handles unwrapped longitudes (e.g. tripolar λ ∈ 70°…430°),
  holes, and multiple crossings.
- **Lines (`split_linestring_points`)**: 1-D, cheap single pass that inserts two
  boundary vertices + a `NaN` break at each crossing (with a color-co-split
  variant so per-vertex `contour_colors` stay parallel).
- **Seam densification + nudge (`_densify_seam_ring`)**: seam edges (lon exactly
  on `lon0 ± 180`) are (1) resampled in latitude (≤ `seam_dlat`, default 1°) so
  they follow the *curved* projected meridian instead of a straight chord, and
  (2) nudged inward by `SEAM_EPS = 1f-3°` so Proj projects them cleanly to one
  map edge (fixes the "sawtooth").
- **`add_cyclic_point`** (`src/utils.jl`, exported): cartopy-style helper to wrap
  a longitude-periodic grid (append a copy of the first column at lon+360) so the
  *grid's own* periodic seam closes. Needed because Makie's contourf treats the
  grid as non-periodic. Vector + matrix (curvilinear) methods.

---

## 3. Dependencies / environment

- **Upstream Makie fix is REQUIRED.** This work surfaced a Makie `contourf` bug
  (closed interior minima not rendered): **Makie.jl#5651**, fixed by **PR 5654**
  (`briochemc/Makie.jl@fix-contourf-hollow-bands-5651`). The dev Makie monorepo at
  `~/.julia/dev/Makie` is checked out on that branch. Until 5654 merges + releases,
  GeoMakie's `Makie` compat may need to point at it. MWE that demonstrates the
  upstream bug: `contourf` vs `surface` of `[cosd(3l)*cosd(y) for l in -180:4:180,
  y in -90:4:90]`.
- New runtime deps already in `[deps]`: `GeometryOps`, `GeoInterface` (were
  already there).
- New **test** dep: `Oceananigans` (in `Project.toml` `[extras]` + `[targets]`)
  for the tripolar test. The tripolar testset is guarded (`try using Oceananigans`)
  so it skips if unavailable.

### Scratch env used during development (`/tmp/geomakie-scratch`)
A `.scratch`-style env devs the local monorepo Makie + GeoMakie:
```julia
using Pkg; Pkg.activate("/tmp/geomakie-scratch")
Pkg.develop([
  PackageSpec(path="/Users/benoitpasquier/.julia/dev/Makie/ComputePipeline"),
  PackageSpec(path="/Users/benoitpasquier/.julia/dev/Makie/Makie"),
  PackageSpec(path="/Users/benoitpasquier/.julia/dev/Makie/CairoMakie"),
  PackageSpec(path="/Users/benoitpasquier/.julia/dev/GeoMakie"),
])
# also: GeometryOps, GeoInterface, GeometryBasics, Oceananigans
```
`LocalPreferences.toml` there sets `precompile_workload = false` for fast iteration
(per Makie's `AGENTS.md`). Julia 1.12.6. Many diagnostic scripts live in that dir
(see §6) — reuse them.

---

## 4. What is DONE and verified

- ✅ Loads/precompiles on Julia 1.12 (the original blocker — recipe method
  overwriting — is gone; we use axis dispatch, no piracy).
- ✅ `parse_lon0` reads `lon_0` from a resolved `Proj.Transformation` pipeline
  string (`lon_0=` without a leading `+`). **This was a real bug** — previously it
  always returned 0.0, so the split ran at the wrong meridian for any `lon_0 ≠ 0`.
- ✅ Antimeridian **sawtooth** fixed (seam-vertex nudge, `SEAM_EPS`).
- ✅ **White-oval rings** fixed: polygons already inside the projection window are
  passed through untouched (clipping/reconstructing them perturbed multi-hole
  bands).
- ✅ Seam densification (curved meridians), `add_cyclic_point`, color co-split for
  lines.
- ✅ Tests green: `test/polygonsplitting.jl` (unit, 0 fail) and the
  "Antimeridian-aware contour/contourf" testset in `test/geoaxis.jl`
  (23763 assertions incl. Oceananigans tripolar, 0 fail).
- ✅ Clean visual cases confirmed (contourf matches `surface` ground truth):
  rectilinear `exp(cosd(l))+3y/90` at `lon_0=-150`; oscillatory
  `cosd(3l)*cosd(y)` at `lon_0=0`; tripolar `lon_0=0` (with `add_cyclic_point` to
  close the grid seam).

---

## 5. What is LEFT / KNOWN BUGS (the reason this is WIP)

### 5.1 BLOCKER — `lon_0 = 180` multi-hole bands leave thin seams
With a field that has **multiple closed extrema** (e.g. `cosd(3l)*cosd(y)`) on a
`lon_0 = 180` (or other `lon_0 ≠ 0` where bands genuinely wrap), the projected
`contourf` shows **2 thin white lines near the map center** (the data `l = ±180`
seam, where the clipped pieces meet). Monotonic fields (no closed interior bands)
are fine; this is specific to multi-hole bands that must be clipped across the
wrap.
- **Hypothesis**: `GeometryOps.intersection` re-tessellates/perturbs **holes** of
  the band when clipping across the wrap, so the two halves' hole boundaries
  don't meet exactly at the data seam.
- **Directions to try**:
  - Densify/snap the *data-edge* boundary (l = ±180) the same way we treat the
    seam, so the two halves share identical vertices there.
  - Or avoid clipping when the polygon can be handled by translation only; only
    clip the minimal crossing span.
  - Or pre-unwrap the input grid (and/or apply `add_cyclic_point`) before
    contouring so bands don't straddle the data edge. Check whether
    `add_cyclic_point` already hides this in practice for real (tripolar) data.
  - Inspect with the stroked-pieces debug (`/tmp/geomakie-scratch/debug_lon180.jl`,
    `zoom_seam.jl`).

### 5.2 Line contours: apply the seam nudge too
`split_linestring_points` inserts boundary vertices *exactly* on `lon0 ± 180`; it
does **not** apply the `SEAM_EPS` nudge. Lines may show a faint seam glitch at
`lon_0 ≠ 0`. Apply the same inward nudge to the inserted boundary points.

### 5.3 `surface` smear at `lon_0 = 180` (UPSTREAM-ish, out of scope but note it)
`surface!`/`heatmap!` on a `GeoAxis` are **not** antimeridian-split (only
contour/contourf are). At `lon_0 = 180` their seam-crossing cells smear. So at
`lon_0 = 180` the `surface` "ground truth" is itself unreliable — compare
contourf against the **plain lon/lat** (`Axis`) contourf instead. Splitting
surface/heatmap/mesh cells is a separate, larger feature.

### 5.4 Pole-enclosing rings
`close_at_poles` kwarg is accepted but **unused** (the old hand-rolled pole
closing was removed when we switched to strip-clip). A band whose ring encloses a
pole (longitude span ≥ 360°) is clipped like any other; the polar cap between the
ring and the pole may not fill. No test currently exercises a true pole-enclosing
contourf band. Add one (e.g. high-latitude band on a polar stereographic) and
decide whether to special-case it.

### 5.5 Performance / robustness
- `GeometryOps.intersection` runs per crossing-polygon per strip; fine for typical
  contourf but unbenchmarked for dense/high-level-count fields.
- `add_cyclic_point` matrix form assumes the periodic dimension is `dims=1`
  (Oceananigans tripolar convention). Document/validate for other layouts.
- Live-updating an already-displayed figure: delete+recreate adds the child to
  `plot.plots` but doesn't re-insert into an attached screen, so a contourf added
  to a *live* GLMakie window may not appear until redraw. Fine for the normal
  build-then-display flow (examples/tests). Worth a real fix for interactivity.

### 5.6 Docs/example polish
- `examples/antimeridian_contours.jl`: the vector `add_cyclic_point` panel (`F`)
  is a muddy demo (its field also crosses the antimeridian). Use the tripolar /
  matrix case or a cleaner isolated periodic field.
- Decide whether to keep `Oceananigans` as a hard test dep (heavy CI) or fall back
  to a static fixture of the #4885 grid.

---

## 6. Verification / how to test

```bash
# Unit tests (fast, no backend):
cd /tmp/geomakie-scratch && julia --project=. /path/to/GeoMakie/test/polygonsplitting.jl

# GeoAxis + tripolar testset (needs Oceananigans + CairoMakie):
julia --project=. -e 'using GeoMakie, GeometryBasics, CairoMakie, Test; include(".../test/geoaxis.jl")'
# or run the extracted testset: /tmp/geomakie-scratch/run_geoaxis_testset.jl
```

Key **diagnostic scripts** in `/tmp/geomakie-scratch` (reuse them):
- `contourf_vs_surface_mwe.jl` — the upstream Makie bug MWE.
- `diag_lon180.jl` — 3×2 (i/j, lon/lat, proj) × (heatmap/surface, contourf) for
  the hard `lon_0=180` case. **The main tool for the §5.1 blocker.**
- `A_compare.jl` — same 3×2 for the well-behaved rectilinear field, `lon_0=-150`.
- `debug_sawtooth.jl`, `zoom_seam.jl`, `debug_lon180.jl` — stroked split-piece
  geometry near the seam.
- `clean_check.jl` — quick surface-vs-contourf at lon_0 ∈ {-150, 0, 180}.
- `regenerate_all.jl` — full A–F example gallery render.
- Rendered PNGs accumulate in `/tmp/geomakie-scratch/all/`.

**The acceptance bar**: for a field that does *not* trip the (now-fixed) Makie
contourf bug, projected `contourf`/`contour` on a `GeoAxis` must match the plain
lon/lat `contourf` warped onto the projection (and `surface` where surface itself
doesn't smear), with no white seams/gaps/smears, for `lon_0 ∈ {0, ±90, 150, 180,
-150}` and for the Oceananigans tripolar grid (with `add_cyclic_point`).

---

## 7. Key files

| File | What |
|---|---|
| `src/contoursplitting_geo.jl` | the axis-dispatch hook (contourf + contour); was `contourf_geo.jl` (deleted, the pirating version) |
| `src/polygonsplitting.jl` | `parse_lon0`, `split_polygon` (strip-clip), `split_linestring_points`, `_densify_seam_ring` (+nudge), `split_polys_and_colors` |
| `src/geoaxis.jl` | extracted `_geoaxis_plot!` helper + `plot!(::GeoAxis, ::AbstractPlot)` |
| `src/utils.jl` | `add_cyclic_point` |
| `src/GeoMakie.jl` | includes + `export add_cyclic_point` |
| `test/polygonsplitting.jl` | unit tests for split primitives + `add_cyclic_point` |
| `test/geoaxis.jl` | "Antimeridian-aware contour/contourf" testset (incl. tripolar) |
| `examples/antimeridian_contours.jl` | docs example (registered in `docs/src/examples.md`) |
| `Project.toml` | `Oceananigans` test dep |
| `CHANGELOG.md` | feature entries |

Upstream: `MakieOrg/Makie.jl#5651` (issue), `#5654` (fix PR, by @briochemc).
