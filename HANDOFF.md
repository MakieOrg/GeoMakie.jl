# Handoff — sphere-clip branch, docs build status

Branch: `bp-claued/sphere_clip_resampling` (base: `master`)
Last updated: 2026-06-15

## Commits this session (all pushed-ready, not yet pushed)

- `a122ebc` Fix polar stereographic: route `stere`/`sterea`/`ups` through antipode `CircleClip`
  (was mis-routed via the antimeridian centred frame → polar `lat_0=±90` collapsed to an
  equatorial "Africa" aspect).
- `098fb1b` Fix GeoAxis `StackOverflow` on equatorial `laea`: cap the spine callback's synchronous
  re-entry depth (protrusion↔layout↔projectionview feedback never converged).
- `431206a` docs: rewrite `docs/src/projections.md` into per-projection sections; variant families
  (`eck*`, `wag*`, `putp*`, `vandg*`, `wink*`, `murd*`, `natearth*`, `kav*`, `adams_ws*`) grouped
  into DocumenterVitepress `::: tabs`. Contourf only (no PROJ images in docs).
- `9bd30d4` Fix `_clip_faces` O(faces×4^depth) blowup: drop a face in O(1) when all 3 vertices are
  non-finite (back hemisphere of ortho/geos). `heatmap`/`surface` on a GeoAxis under ortho was
  ~minutes; now linear (dest→ortho on 720×360: 44.5s → 4.3s). **This fixed the `rasters` docs stall.**

Tests green: `julia --project=dev/scratch-env test/sphere_clip.jl` (68 pass).

## OPEN ISSUE — full docs build stalls after `Running Cardmeta for geoid`

Symptom: `julia --project=docs docs/make.jl` hangs in the Cardmeta phase, last line
`[ Info: Running Cardmeta for geoid`. CI (Jun 4, master) does geoid→vesta3d in ~15 s.

Likely **NOT our regression** — evidence:
- `geoid.jl` uses `GlobeAxis` + `surface!` on a 1441×2881 (~4.15M-cell) raster (`Cover = fig`).
- The next page (CI order) is `vesta3d.jl` = `meshimage(...; type = GlobeAxis)`.
- `src/sphere/globeaxis.jl` is **not** in our changed files (`git diff --name-only master..HEAD -- src`
  = GeoMakie.jl, contoursplitting_geo.jl, geoaxis.jl, mesh_image.jl, sphere_clip.jl, utils.jl).
- Our `utils.jl` change is purely additive (`add_cyclic_point`). GlobeAxis does not use the
  GeoAxis spine callback or `_geo_grid_mesh`/`_clip_faces` paths we touched.

So it should reproduce on `master` too (verify on the other machine).

### Disambiguate geoid vs the next page (the "annotation" lesson)
If the run was **block-buffered** (output redirected to a file), `geoid` may have finished and the
real stall is `vesta3d`. Run with line buffering to be sure the last printed page is the live one:
`script -q /dev/null julia --project=docs docs/make.jl | tee build.log` (on macOS `stdbuf` is absent;
`script` needs a TTY — works from a terminal, not from a non-TTY background job).

### Next steps to localize
1. Reproduce `geoid` core without data download — GlobeAxis + `surface!` on a synthetic 1441×2881
   grid + `Makie.colorbuffer(fig; px_per_unit=2)`; time build/layout vs colorbuffer. (CairoMakie
   renders 3D in software — an ~8M-triangle globe surface cover could be inherently minutes.)
2. Reproduce `vesta3d` core — `meshimage(-180..180,-90..90, img; axis=(; type=GlobeAxis))` +
   colorbuffer. Note `vesta3d` also downloads via `DataDeps` (`datadep"vesta_image"`); a download
   prompt/stall would hang ExpandTemplates, not Cardmeta.
3. If geoid's GlobeAxis surface is the cost: it's a CairoMakie 3D-rasterization scaling issue, not
   the sphere-clip work — decide whether to downsample the geoid raster for the docs cover.

## Useful commands / scratch
- Full build: `julia --project=docs docs/make.jl`  (env: `DRAFT=true` skips `@example` exec but the
  Vitepress bundle still fails on draft because `is_it_a_plane.md`/`rotating_earth.md` reference
  generated media — `plane.mp4` — that only exist in a full build).
- Projection sweep (dev gallery, gitignored): `julia --project=dev/scratch-env dev/antimeridian_gallery/projection_sweep.jl`
  → `dev/antimeridian_gallery/projection_sweep_gallery.md` (scatter | our contourf | PROJ reference).
- Repro scripts used this session live in `/tmp` (not committed): `repro_rasters.jl`, `prof.jl`,
  `verify_mesh.jl`. Rebuild as needed.
