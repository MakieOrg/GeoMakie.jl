# HANDOFF — circular-boundary polar maps via `GeoPolarAxis`

*(Working note for the next session/machine. Delete before the PR merges.)*

## Goal (unchanged)

Reproduce cartopy's **[always_circular_stereo](https://cartopy.readthedocs.io/latest/gallery/lines_and_polygons/always_circular_stereo.html)**:
a polar-stereographic map whose boundary is a **circle** (a cap at a chosen latitude), everything
outside the circle **clipped**, with a polar graticule (parallels = r-rings, meridians = θ-spokes).

## STATUS: Phase 1 implemented (`GeoPolarAxis`), not yet test-run / visually reviewed

Maintainer decisions this session (via AskUserQuestion): **API = thin `GeoPolarAxis` wrapper**,
**scope = everything incl. fields** (lines, scatter, poly fill, surface, heatmap, contourf).

### What landed

- **`src/polar.jl`** — new file. `GeoPolarAxis` wraps a Makie `PolarAxis` + the Proj transform.
  Overloads `Makie.lines!/scatter!/poly!/surface!/heatmap!/contourf!` on `::GeoPolarAxis`: they take
  **geographic (lon,lat)** input, map to `(θ,r)` and forward to the wrapped axis.
- **`src/GeoMakie.jl`** — `include("polar.jl")` (after `mesh_image.jl`/`linesplitting.jl`, because
  polar.jl reuses `_geo_grid_mesh`, `_split_polygon`, `_resample_to_grid`, `_collect_polys`); and
  `export GeoAxis, GeoPolarAxis, automatic`.
- **`test/polar.jl`** + entry in `test/runtests.jl` (`@testset "GeoPolarAxis"`).

### Core idea / key technical decisions (so you don't re-derive them)

1. **A pole-centred azimuthal projection IS a polar plot.** `project(lon,lat)→(x,y)`;
   `θ = atan2(y,x)`, `r = hypot(x,y)`. We re-express the chosen PROJ projection in polar coords and
   let `PolarAxis` give the circular clip (`rlimits`), polar grid and circular spine **for free**.
2. **Orientation is automatic — do NOT hand-set `theta_0`/`direction`.** With PolarAxis defaults
   (`theta_0=0, direction=+1`), feeding the projector's own `θ=atan2(y,x)` reproduces the exact PROJ
   layout (north stere: 0°-meridian at bottom; south: at top). Verified by round-trip
   `(θ,r)→(x,y)` == `project(lon,lat)`. (The earlier prototype's `r=colat`/manual theta_0 idea is
   superseded — the projector is exact and simpler.)
3. **The atan2 branch cut (θ flips ±π at one meridian, here lon=−90 for lon_0=0, NOT lon=180).**
   - Harmless for **lines/scatter** (PolarAxis transforms each vertex then draws straight Cartesian
     segments → a π→−π step is a short correct segment). Confirmed: 0 spurious in-cap jumps.
   - **Fatal for fills** (poly/surface/contourf triangulate in `(θ,r)` → a triangle across the cut
     warps over the whole disk). **Fix: build the mesh in projected `(x,y)` (continuous, no seam),
     then remap vertices to `(θ,r)`.** The round-trip is exact so PolarAxis recovers the true
     projected triangles. This is the crux — every filled verb uses it.
4. **Cap-clip fills first** (`_cap_clip` = `CircleClip(0, ±90, 90−|latcap|)`, `_cap_split`): trims
   land/bands to the disk before triangulating, so far-away continents aren't meshed only to be
   `rlimits`-clipped, and a **pole-enclosing polygon (Antarctica) still fills to r=0**.
5. **Reuse:** fields (`surface!`/`heatmap!`) call existing `_geo_grid_mesh` (projects grid→mesh in
   x,y) then remap to (θ,r). `contourf!` **harvests band polys+colours from a detached
   `contourf!(Scene(), …)`** (`probe.polys[]`, `probe.computed_colors[]`,
   `computed_colormap`/`computed_colorrange`), cap-clips each band (`winding=:planar`), mesh-fills.
6. Grid/spine styled to **match GeoAxis** (faint black @ 12%, opaque spine), not PolarAxis's darker
   defaults.

### Validated PROGRAMMATICALLY this session (ad-hoc scripts mirroring `test/polar.jl`)

- Construction + pole inference from `latcap` sign; `rlimits=(0,rcap)`.
- Radial law: `r(90°)=0`, monotone; `(θ,r)` round-trips to `project(lon,lat)` (atol 1e-3).
- Cap-clipped land fills: all verts ≤ rcap; no triangle edge > disk diameter (branch-cut guard);
  **Antarctica min_r=0** (fills to pole); maxedge north 7.6e6 / south 3.0e6 (was 1.25e8 before
  cap-clip — far land).
- Coastline lines: 0 in-cap Cartesian jumps > 0.5·rcap.
- Full render of all 6 verbs to PNG ran without error (`/tmp/polar_integration.png`).

## ⚠️ NOT YET DONE — do these next

1. **RUN THE TESTS.** `test/polar.jl` is written but was NOT executed in this session (interrupted).
   Run: `julia --project=test -e 'using GeoMakie,CairoMakie,GeometryBasics,Test; include("test/polar.jl")'`
   then the full `test/runtests.jl`. Fix anything red. (IDE flagged a couple of low-severity
   "possible method call" infos in polar.jl — recheck `_split_polygon`/`PolarAxis` call sites.)
2. **VISUALLY REVIEW** `/tmp/polar_integration.png` (4 panels: N land+coast+points, S Antarctica
   fill, N surface+colorbar, N contourf). Per memory, *you* eyeball it — I didn't open it. Confirm:
   Antarctica fills cleanly to the pole with no disk-spanning smear; contourf bands are seam-free;
   grid reads as parallels/meridians; orientation right (N: 0° bottom, S: 0° top).
3. **DOCS:** replace the parallel-circle hack in `docs/src/projections.md` "Polar (stereographic)"
   (≈ lines 837–859) with a real `GeoPolarAxis` panel; consider a dedicated example reproducing the
   cartopy figure (south cap −65°, coastlines, empty corners) side-by-side.
4. **Add a docstring/API mention** in `docs/src/api.md` if GeoAxis is documented there.

## Known limitations / smaller follow-ups

- **Lines/scatter are NOT cap-clipped** — they use `split_resample_line` (antipode CircleClip) +
  rely on PolarAxis `rlimits` for the visual cap clip. Correct, slightly wasteful (draws far
  coastlines then clips). Fine for now; cap-clip later if perf matters (need a custom-clip variant
  of `split_resample_line`).
- **Empty-geometry guard**: `_merge_fill_meshes` on an empty cap returns an empty Mesh; `mesh!` on
  it is untested — add a guard if a verb is ever called with no in-cap geometry.
- **Oblique (non-pole-centred) azimuthal**: `GeoPolarAxis` assumes pole-centred (radius depends only
  on lat, sampled at lon=0). Document that constraint / guard. The general oblique-circular-clip case
  is the old **Phase 2** (GeoAxis + cap CircleClip + graticule clip + mask) — still deferred, only if
  a real use-case needs it.
- `contourf!` harvests bands via a throwaway `Scene()` — works, but is a slightly hacky way to reach
  Makie's band computation; revisit if the compute-graph API changes.

## Files touched
- `src/polar.jl` (new), `src/GeoMakie.jl` (include + export), `test/polar.jl` (new),
  `test/runtests.jl` (testset). Scratch (gitignored/throwaway): `/tmp/polar_*.jl`,
  `/tmp/polar_integration.png`.
- `HANDOFF_poles.png` — the original equidistant prototype image; keep until docs example lands,
  then delete with this file before the PR merges.

---

### Prior context (delegation pass — still relevant follow-ups)

Earlier work on this branch pushed generic geometry down into GeometryOps where it could go
without regressing correctness/perf, and filed the rest upstream. **Gated on upstream
(future PRs, not this one):** when GeometryOps ships
[#417](https://github.com/JuliaGeo/GeometryOps.jl/issues/417) (spherical polygon clip),
[#418](https://github.com/JuliaGeo/GeometryOps.jl/issues/418) (alloc-free arc intersection),
[#419](https://github.com/JuliaGeo/GeometryOps.jl/issues/419) (spherical point-in-polygon),
[#420](https://github.com/JuliaGeo/GeometryOps.jl/issues/420) (rings→nested-polygons-by-depth),
[#421](https://github.com/JuliaGeo/GeometryOps.jl/issues/421) (`GeographicFromUnitSphere`
`clamp`), delete the corresponding bespoke code (`_clip_against_polygon`+`_cp_*`,
`_gc_intersect`, `_polygon_contains`, `_rings_to_polygons`, `_sph`). Each is an isolated swap.
Long-form draft: `dev/UPSTREAM_GEOMETRYOPS.md` (gitignored).
