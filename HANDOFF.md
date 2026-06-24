# HANDOFF — `GeoPolarAxis` polish (orientation fix · docs generator · Block promotion)

*(Working note for continuing on another machine. Delete before the PR merges.)*

## Where this stands

All three items from this session are **implemented and green** (`test/polar.jl`, 6 testsets, all
pass). What's left is mostly a full docs build + cleanup before the PR (see "Remaining").

### 1. South polar stereographic orientation — FIXED
The south cap was rotated 180° (0E at bottom, 90E to the left). Root cause: `_polar_orientation`
returned `theta_0 = α0`, but Makie's `Polar` transform is `θ_screen = direction·(θ + theta_0)`
(the offset is applied *inside* the direction flip — see
`~/.julia/dev/Makie/Makie/src/layouting/transformation.jl:673`). For a north cap `direction=+1`
so it was harmless; for a south cap `direction=-1` it negated the offset.
Fix (`src/polar.jl`, `_polar_orientation`): `return direction, direction * α0`. North is unchanged;
south now reads 0E at top, 90E right, 180 bottom, 90W left. The orientation testset asserts the real
Makie convention `r·(cos|sin)(dir·(θ + th0)) ≈ (x, y)` (was `dir·θ + th0`, which only held for north).

### 2. `projections.md` is now generated from a data list
`docs/src/projections.md` is **auto-generated** by `docs/generate_projections.jl` (the single source
of truth: the `PROJECTION_SECTIONS` list — 82 sections, 13 tabbed). `make.jl` runs the generator on
every build (just after `using Literate`). Each panel now shows a **self-contained, copy-pasteable**
`@example` cell (full `GeoAxis(...) + poly!`) above its figure, instead of a hidden `panel(proj)`
call. A visible preamble cell (`using …; land = GeoMakie.land()`) is shared by all panels. To
add/edit a projection, edit `PROJECTION_SECTIONS`, never the generated markdown (it has a
"DO NOT EDIT" banner). The page resets CairoMakie to PNG at the end (process-global backend) so later
raster-heavy example pages don't balloon into SVG.

### 3. Polar field demo moved out + `GeoPolarAxis` is now a real Makie Block
- **Docs**: the `contourf!`/`surface!`/`Colorbar` field demo (the "fluff") moved from
  `projections.md` to a new Literate example, `examples/polar_stereo.jl` (heading
  **"Polar stereographic cap"**, added to the `examples` list in `make.jl`). `projections.md` now
  shows only the land panels for the polar section, consistent with every other projection, and links
  to the new example.
- **Architecture**: `GeoPolarAxis` was promoted from a plain struct to
  `Makie.@Block GeoPolarAxis <: Makie.AbstractAxis` — a **sibling of `GeoAxis`** (it can't be a
  subtype: both are concrete `@Block`s). It uses **`@forwarded_layout`** and creates its wrapped
  `PolarAxis` at `gpa.layout[1, 1]` (the `SliderGrid` pattern — the only supported way to nest a
  Block; see `~/.julia/dev/Makie/Makie/src/makielayout/blocks/slidergrid.jl`). It now places/sizes
  like any axis and registers as the **current axis**.

#### Block gotchas already handled (read before touching it)
- Makie rejects any kwarg that isn't a declared attribute (`_check_remaining_kwargs`,
  `blocks.jl:334`), so the old `kwargs...`→`PolarAxis` passthrough is gone. Every accepted keyword
  (`latcap`, `dest`, `source`, `lat/lonticks`, `direction`, `theta_0`, grid styling, and the
  `title*` family) is a **declared attribute**; anything else must be set via `gpa.axis`.
- `latcap`/`dest`/etc. are now attributes (Observables): `gpa.dest[]` (tests use `[]`), not
  `gpa.dest`. `gpa.axis` and `gpa.transform` are plain fields (no `[]`). `dest`/`source` resolve in
  `initialize_block!` and the resolved PROJ strings are written back into the attributes.
- It owns no limits → `Makie.update_state_before_display!(gpa)` forwards to `gpa.axis`, else the
  generic `AbstractAxis` path hits `reset_limits!`/`gpa.limits` and errors on `save`.
- The construction is read-once (not reactive to later `gpa.latcap[] = …`); that matches the old
  behavior. Full reactivity would be a follow-up.

## Verified this session
- `test/polar.jl` green (construction/current-axis, exact radial law + orientation for N&S,
  antimeridian split to the pole, stroke seams, every verb renders incl. `save`, poly! stays vector
  in SVG). Run:
  `julia --project=. -e 'using GeoMakie,CairoMakie,GeometryBasics,Test; include("test/polar.jl")'`
- Render spot-checks (in `/tmp`, throwaway): `polar_block_check.png` (N/S land panels, Block +
  orientation), `polar_example_southcap.png`, `polar_example_field.png`. (Per project convention,
  eyeball these visually; correctness is otherwise asserted in tests.)

## Remaining (before PR)
1. **Full docs build** to confirm the generated page + new example compile end-to-end:
   `julia --project=docs docs/make.jl` (slow; or `DRAFT=true` for a structure-only pass). Eyeball the
   generated `projections.md` panels and the `examples/polar_stereo.md` figures.
2. **Full test suite**: `julia --project=. test/runtests.jl` (**not** `Pkg.test()` — it pulls GLMakie
   which the sandbox can't resolve against dev-pinned Makie).
3. **Cleanup before merge**: delete this file + `HANDOFF_poles.png` (stale prototype) and the `/tmp`
   scratch renders.

## Files touched this session
- `src/polar.jl` (orientation fix + Block promotion + `update_state_before_display!`)
- `test/polar.jl` (attribute `[]` access, Block assertions, corrected orientation reconstruction)
- `docs/generate_projections.jl` (new — generator + `PROJECTION_SECTIONS`)
- `docs/src/projections.md` (now generated)
- `docs/make.jl` (run generator; add `polar_stereo.jl` to examples)
- `examples/polar_stereo.jl` (new — the moved field demo / cartopy `always_circular_stereo`)

### Prior context (still-relevant upstream follow-ups, NOT this PR)
When GeometryOps ships #417–#421 (spherical clip / arc intersection / point-in-polygon /
rings→nested-polygons / `GeographicFromUnitSphere` clamp), delete the matching bespoke code
(`_clip_against_polygon`+`_cp_*`, `_gc_intersect`, `_polygon_contains`, `_rings_to_polygons`,
`_sph`). Long-form draft: `dev/UPSTREAM_GEOMETRYOPS.md` (gitignored).
