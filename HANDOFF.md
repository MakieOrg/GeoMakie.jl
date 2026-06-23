# HANDOFF — `GeoPolarAxis` (circular-boundary polar maps)

*(Working note for the next session/machine. Delete before the PR merges.)*

## Where this stands

`GeoPolarAxis` (in `src/polar.jl`) is **implemented, refactored, and green** (48 tests). The big
open items from earlier handoffs — the fill "mirror", the antimeridian cut, the heatmap smear — are
all **resolved**. What's left is mostly review/polish before the PR (see "Remaining").

## The design (after the refactor — read this first)

A pole-centred azimuthal projection is **separable** in polar coords, so we map directly:
- **`θ = lon`** (the display orientation is set by PolarAxis `direction`/`theta_0`)
- **`r = radial(lat) = hypot(project(lon₀, lat))`** (the projection's exact radial law)

`direction`/`theta_0` are **auto-derived from the projector** (`_polar_orientation`) so the layout
matches the true azimuthal projection exactly (verified 0 m error; the projected bearing is provably
lon-only). N cap → 0° at bottom, S cap → 0° at top. Both overridable.

**Why `θ = lon` and not `atan2(y,x)`** (the previous approach — *don't go back to it*): `atan2`
puts the branch cut at a weird meridian (lon ≈ −90 for lon₀=0), which forced filled artists through
a hand-built `mesh!` in projected (x,y). `mesh!` is what made CairoMakie **rasterise** the fill into
`feImage`/`<image>` tiles → the **PDF mirror/shift** and **SVG seam**. With `θ = lon` the only seam
is the **antimeridian (lon ±180)** — a constant-longitude graticule line — so we reuse the existing
`AntimeridianClip` (with pole-walk for Antarctica) and then filled artists go through **ordinary
`poly!`/`contourf!`** → **clean vector paths**.

### Per-verb (all in `src/polar.jl`)
- `lines!`/`scatter!`: `split_resample_line` (antipode clip + resample) → map to `(θ,r)`.
- `poly!`: `_anti_split` (antimeridian split, lon0=0, pole-walk) → `_polar_polygon` → native `poly!`
  (vector). Antarctica's two pieces abut on the same radial line (θ=±π) so the **fill is seamless to
  r=0**. The **stroke** is drawn separately (`_polar_stroke_points`) and **skips antimeridian-aligned
  edges** so there's no radial cut to the pole.
- `contourf!`: map coords → native `contourf!` (bands are simple in (θ,r) → **vector**).
- `surface!`/`heatmap!`: a `(θ,r)` **pcolormesh** (`_polar_field_mesh!`), data as per-vertex colour,
  warped per-vertex. **Raster data on a nonlinear axis MUST be a mesh** (heatmap's native image path
  smears — same reason GeoAxis meshes its grids), so these **rasterise in vector backends**
  (`feImage` → slow PDF, blank in Firefox SVG). **This is inherent to raster fields — use
  `contourf!` for a vector field.** Not a bug; don't try to "fix" it.

## Verified this session
- Maintainer: `poly!` land caps LGTM in **PNG, SVG, and PDF** — no mirror/shift, no antimeridian cut.
- Heatmap smear fixed (was the native-image regression); now a proper pcolormesh.
- 48 tests green (`test/polar.jl`). Run: `julia --project=. -e 'using GeoMakie,CairoMakie,GeometryBasics,Test; const G=GeoMakie; include("test/polar.jl")'`
  (or full suite `julia --project=. test/runtests.jl`; **not** `Pkg.test()` — it pulls GLMakie which
  the sandbox can't resolve against dev-pinned Makie).
- New regression test asserts the poly-fill SVG has no `feImage`/`<image>` (guards against a
  mesh-fill relapse).

## Remaining (before PR)
1. **Re-render the docs section** `docs/src/projections.md` "Polar (stereographic) — `GeoPolarAxis`"
   and eyeball: the `poly!` caps block + the `contourf!`/`surface!` field block. Both updated this
   session (description now says `θ=lon`/`r=radial`; the `@setup` PNG caveat now correctly scopes the
   Firefox/`feImage` issue to `surface!`/`heatmap!` only). Confirm they build clean.
2. **Optional**: a dedicated `examples/` page reproducing cartopy `always_circular_stereo` (south cap
   −65°, coastlines, empty corners). projections.md already cites/covers it — nice-to-have.
3. **Cleanup before merge**: delete this file + `HANDOFF_poles.png` (stale equidistant prototype).
4. Scratch (throwaway, `/tmp`, not committed): `polar_check_all.jl`, `polar_field_check.jl`,
   `polar_mirror_check.jl`, `polaraxis_poly_mwe.jl`, `diag_*.jl` and their image output.

## Files
- `src/polar.jl` (rewritten), `src/GeoMakie.jl` (include/export), `test/polar.jl`,
  `test/runtests.jl`, `docs/src/projections.md`.

### Prior context (still-relevant upstream follow-ups, NOT this PR)
When GeometryOps ships #417–#421 (spherical clip / arc intersection / point-in-polygon /
rings→nested-polygons / `GeographicFromUnitSphere` clamp), delete the matching bespoke code
(`_clip_against_polygon`+`_cp_*`, `_gc_intersect`, `_polygon_contains`, `_rings_to_polygons`,
`_sph`). Long-form draft: `dev/UPSTREAM_GEOMETRYOPS.md` (gitignored).
