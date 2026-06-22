# HANDOFF — `GeoPolarAxis` (circular-boundary polar maps)

*(Working note for the next session/machine. Delete before the PR merges.)*

## Where this stands

`GeoPolarAxis` (in `src/polar.jl`) is **implemented and tested**. This session finished the
"NOT YET DONE" items from the previous handoff and started chasing one **open visual bug** (a
fill mirror the maintainer spotted) — that bug is the only thing left before docs/PR are final.

### Done this session
- **Tests pass.** `test/polar.jl` (32 tests) and the full `test/runtests.jl` (**179/179**) are green.
  - Run the suite directly against the dev manifest: `julia --project=. test/runtests.jl`.
    Do **not** use `Pkg.test()` here — the test target pulls in GLMakie, which the sandbox
    re-resolve can't satisfy against the dev-pinned Makie 0.24.12 (pre-existing env issue, unrelated).
- **Demo field fixed.** Earlier demos used `cosd(lat)*sind(2lon)+0.5cosd(3lon)`, which is
  **multivalued at the pole** (the `cosd(3lon)` term varies with lon at lat=90) → surface looked
  discontinuous and contourf smeared. Replaced everywhere with a **C∞ field built as a function of
  Cartesian `(x,y,z)` then sampled at `(lon,lat)`** (sum of Gaussians) → single-valued at the pole
  (verified: spread over all lons at lat=90 is exactly 0). This is the canonical way to make sphere
  test data; keep it.
- **Integration render** `/tmp/polar_integration.{png,pdf}` (regenerate with `/tmp/polar_integration.jl`):
  6 panels exercising every verb (poly+lines, scatter-coloured-by-field, Antarctica-to-pole,
  surface+colorbar, heatmap, contourf). Maintainer reviewed the PNG → **LGTM**. contourf verified
  programmatically healthy: 22 bands → 22 meshes, all 12 level colours present, every vertex ≤ rcap,
  fills reach r=0, max-edge/diameter = 0.61 (no branch-cut smear).
- **Docs** `docs/src/projections.md` "Polar (stereographic) — `GeoPolarAxis`": replaced the old
  parallel-circle GeoAxis hack with a real `GeoPolarAxis` section (N/S land caps + a laea-contourf /
  stere-surface field panel). Both example blocks were test-rendered and run clean.
  - The section is forced to **PNG** (a `@setup` switches the backend just before it): GeoPolarAxis
    fills are meshes inside a clipped PolarAxis, which CairoMakie emits in SVG via `feImage` filters
    referencing internal `<defs>` fragments — **Firefox can't render those** (Mozilla bugs
    [455986](https://bugzilla.mozilla.org/show_bug.cgi?id=455986),
    [1538554](https://bugzilla.mozilla.org/show_bug.cgi?id=1538554); Safari/Chrome are fine). This is
    why the maintainer saw blank SVGs in Firefox but not Safari. PNG renders everywhere.
- **Docstring**: removed an `@extref Makie.PolarAxis` from the `GeoPolarAxis` docstring — this docs
  build has no DocumenterInterLinks, so `@extref` would have broken it. `api.md` is `@autodocs`, so
  the (exported, documented) `GeoPolarAxis` is picked up automatically. The `[`GeoPolarAxis`](@ref)`
  link in projections.md resolves against that.

## ⚠️ OPEN — the fill "mirror" bug (do this first)

**Symptom (maintainer, viewing `/tmp/docs_polar_block1.pdf`):** in the N/S land caps, the grey
**fill** looks **mirrored over the horizontal axis** (the 90°E–90°W line) relative to the **stroke**
(black land outline), even though it's clipped to inside that outline. Stroke = correct, fill = wrong.

**Ruled out so far (all via `/tmp/diag_*.jl`, kept as scratch):**
- The `(θ,r)` data is not mirrored: for a single in-cap polygon the fill-mesh vertices equal the
  stroke vertices **exactly**, and both equal the direct `project(lon,lat)` (`/tmp/diag_mirror.jl`).
- It is not a render-backend mirror for the simple case: a single asymmetric polygon (no holes,
  inside the cap) drawn as red fill + blue stroke has **coincident centroids in BOTH PNG and PDF**
  (Δrow≈Δcol≈0; a vertical mirror would give Δrow≈−110…−147 px). See `/tmp/diag_pixel.jl`,
  `/tmp/diag_pdf_vs_png.jl`. So `_polar_fill_mesh` + `mesh!` + the Polar transform are correct, and
  CairoMakie applies the Polar `transform_func` to mesh vertices (`positions_transformed_f32c`).
- `_cap_split`/`_rings_to_polygons` return **lon/lat** polygons (the returned `Polygon` uses the
  original `valid` rings, not the projected ones), so the fill is not double-projected.

**Inconclusive / suspicious:** whole-`land()` red-fill vs blue-stroke centroids differ by
Δcol≈+49 px (PNG) / +37 px (PDF) with only small Δrow (`/tmp/diag_land.jl`) — that's a horizontal
shift, **not** the clean vertical mirror the symptom describes, and is probably just
area-centroid-vs-perimeter-centroid for an asymmetric landmass. The crude global centroid test
can't localise a partial mirror.

**What I had NOT tested yet (start here):**
1. A single polygon that **crosses the cap boundary** (so `_cap_split` actually clips it and inserts
   boundary arcs / may reorient rings), through the full `poly!` path → red fill / blue stroke,
   pixel-centroid compare. If a mirror shows up only here, suspect ring reorientation in
   `_split_polygon`/`_rings_to_polygons` or triangulation of clipped rings.
2. A single polygon **with a hole** (land polys have holes) → same compare.
3. Ground-truth overlay: project `land()` to `(x,y)`, draw on a plain `Axis` (equal aspect) scaled to
   the same disk, and overlay the GeoPolarAxis fill — shows directly whether the whole fill or only
   parts diverge, and in which direction.
4. Worth keeping in mind: **lines/scatter are not cap-clipped** (they use `split_resample_line` +
   the PolarAxis `rlimits` visual clip), whereas **fills are cap-clipped geometrically**. So near the
   boundary the stroke and the fill legitimately trace slightly different paths — check this isn't
   being misread as a mirror. (It wouldn't explain a *horizontal-axis* mirror, but rule it out.)

If it turns out to be real, the fix is almost certainly in the fill path (`_polar_fill_mesh` /
`_cap_split` / `_merge_fill_meshes` in `src/polar.jl`), not in the data or the PolarAxis.

## After the mirror is resolved
- Re-confirm the docs panels look right (they share the fill path).
- Optional (previous handoff "consider"): a dedicated `examples/` page reproducing cartopy's
  `always_circular_stereo` (south cap −65°, coastlines, empty corners). The projections.md section
  already cites and covers it, so this is a nice-to-have.
- Delete this file + `HANDOFF_poles.png` (old equidistant prototype image) before the PR merges.

## Files
- Source: `src/polar.jl` (+ `src/GeoMakie.jl` include/export), `test/polar.jl`, `test/runtests.jl`
  — all committed earlier (734cf9b).
- This session's uncommitted-until-now changes: `docs/src/projections.md`, `src/polar.jl` (docstring).
- Scratch (throwaway, in `/tmp`, not committed): `polar_integration.jl`, `polar_pdfs.jl`,
  `diag_mirror.jl`, `diag_pixel.jl`, `diag_pdf_vs_png.jl`, `diag_land.jl` and their `.png/.pdf` output.

### Prior context (still-relevant upstream follow-ups, NOT this PR)
When GeometryOps ships #417–#421 (spherical clip / arc intersection / point-in-polygon /
rings→nested-polygons / `GeographicFromUnitSphere` clamp), delete the matching bespoke code
(`_clip_against_polygon`+`_cp_*`, `_gc_intersect`, `_polygon_contains`, `_rings_to_polygons`,
`_sph`). Long-form draft: `dev/UPSTREAM_GEOMETRYOPS.md` (gitignored).
