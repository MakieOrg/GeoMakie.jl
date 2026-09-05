# Unreleased

# 0.8.0 - 2026-09-05

`GeoAxis` draws its decorations on the shape the projection gives it.  The frame is the projection's own boundary (an ellipse, a limb, a lon/lat-limited region, or an `outline` of your own), the graticule is clipped to it, the ticks sit where meridians and parallels leave the frame, and the labels stand outside on the frame's normal, thinned where they would overlap.  Lines that never reach the frame (polar parallels, converging meridians) are labelled inside the map.  Titles, axis labels, spine and grid are drawn natively and take their colours from the `Axis` theme, so a `GeoAxis` lines up with an `Axis` beside it.  Data plots are cut at the boundary's seams and everything drawn beyond the frame is masked.

New attributes: `framestyle` (`:plain` / `:fancy`), `framewidth`, `framecolors`, `gridbehind`, `maskoutside`, `outline`, `x/yaxisposition`, `ticklabelminangle`, `ticklabelmingap`, `ticklabelcollisions`, `ticklabelreport`, `interiorlabels`, `carriermeridian`, `carrierparallel`, `interiorlabelsize`, `interiorlabelrotation`, `interiorlabelhalo`, `interiorlabelhalocolor`, `interiorlabelhalowidth`, and the `Axis` minor tick and minor grid attributes.  New tick finders `GeographicTicks` (the default) and `ArcMinuteTicks`.  `hidedecorations!`, `hidexdecorations!`, `hideydecorations!`, `hidespines!` and `tight_ticklabel_spacing!` work as on `Axis`.

Behaviour changes for existing attributes:

| Attribute | Before | After |
|---|---|---|
| `x/yticks` | `automatic`, a fixed tick set over the whole domain | `GeographicTicks()` sized to the visible extent; any Makie finder, vector, range, or `(values, labels)` tuple accepted |
| `x/ytickformat` | declared, never read | honoured; `automatic` prints hemisphere suffixes (`110°W`, `45°N`, `0°`, `180°`) |
| `x/yticklabelpad` | protrusion padding only | the gap between the tick mark and the label |
| `x/ylabelpadding` | moved the tick labels | pads the axis label, as on `Axis` |
| `x/yticklabelrotation` | ignored | honoured |
| `x/yticklabelalign` | hard-coded `(:center, :center)` | derived from the frame normal; a user value overrides |
| `x/yticksize`, `*tickwidth`, `*tickcolor`, `*ticksvisible`, `*tickalign` | no tick marks existed | tick marks drawn on the frame |
| `spinewidth`, `spinecolor`, `spinevisible` | no spine existed | the frame's spine, defaulting to the `Axis` theme |
| `x/yminorticks`, `x/yminorgrid*` | absent | minor ticks and minor graticule, paired with the major step |
| a `transformation` on `ax.scene` | ignored by the ticks | frame, graticule and labels follow it |

Closes #134, #150, #155, #157, #190, #215, #231, #234, #268, #273, #281, #317, #338, #339, #349, #350 and #388.  The decoration tests in `test/decorations` name each of these as an `issue_NNN` case, and `test/refimages` renders every case against a reference set hosted on the `refimages-0.8` release (Makie's `ReferenceTests`; skipped when it is not installed).

Requires ComputePipeline 0.1.8; Julia 1.10 stays supported.

# 0.7.17 - 2026-08-29
- `geo2basic` converts any GeoInterface geometry: it decomposes the input to geometries and hands each to `GeoInterface.convert`.
- `GlobeAxis` lights the globe automatically.
- `GlobeAxis` accepts spherical projections and a wider range of ellipsoid specifications.
- 3D polygon triangulation passes the right arguments to its collinearity predicate.
- Added a geoid example, draping coastlines over an EGM geoid surface.
- Added a regions-of-Italy example.
- Added an API reference page, plus docstrings for `create_globe_transform`, `GeodesyGlobeTransform` and `to_multipoly`.

# 0.7.16 - 2025-11-08
- `GlobeAxis` accepts any ellipsoid Geodesy.jl understands, and its globe transforms carry exact inverses.
- Added `geom_to_bands`, which lifts a geometry into a lower/upper point pair ready to splat into `band!`.
- Added satellite examples: ground tracks, sweep footprints, and a dashboard.
- `DataInspector` skips the map grid lines.

# 0.7.15 - 2025-07-21
- Compatible with Makie v0.24 and GeometryBasics v0.5.
- `meshimage` runs on Makie's compute pipeline.
- `GlobeAxis` handles observables whose lengths change.

# 0.7.14 - 2025-07-19
- Compatible with Makie v0.23 and GeoInterface v1.5.
- GeoMakie plots GeoInterface geometries itself; GeoInterfaceMakie is no longer a dependency.

# 0.7.13 - 2025-06-19
- Ticks keep three significant digits, so fractional degrees print.
- Docs build on DocumenterVitepress v0.2.

# 0.7.12 - 2025-04-21
- Refreshed the docs theme and the example gallery cards.

# 0.7.11 - 2025-02-20
- Added `GlobeAxis`, an experimental 3D axis that draws geographic data on a globe, along with globe transforms that carry 2D coordinates onto it.
- Rectangle zoom works in `GeoAxis`.
- `meshimage` forwards every attribute to the underlying mesh.
- Compatible with Makie v0.22 and GeometryBasics v0.5.

# 0.7.10 - 2025-01-10
- `Makie.transform_func` returns a `GeoAxis`'s projection.
- Protrusions count only visible decorations, so `hidedecorations!` shrinks the axis frame.
- `meshimage` participates in the tight-limits machinery.

# 0.7.9 - 2024-11-27
- Plot calls into a `GeoAxis` accept `reset_limits`, which controls whether inserting the plot resets the axis limits.

# 0.7.8 - 2024-11-12
- Compatible with GeometryOps v0.1.6.

# 0.7.7 - 2024-11-11
- 2D-ness detection accepts any point element type.
- Added tests covering common plot types and plot lists in `GeoAxis`.

# 0.7.6 - 2024-11-11
- Polygons that a transformation lifts out of the plane triangulate in 3D: GeoMakie fits a plane through the polygon and earcuts within it.

# 0.7.5 - 2024-10-12
- `Legend(ga)` and the other Makie block integrations work with `GeoAxis`.

# 0.7.4 - 2024-09-02
- `meshimage` accepts a 2-tuple `npoints` and honours UV transforms.
- Added a tutorial on warping and masking rasters.

# 0.7.3 - 2024-07-17
- `meshimage` gained `z_level` and `shading` attributes, and builds a 3D mesh.
- `split` handles vectors of geometries, with an example for `lon_0 = -160`.
- Geodesy transformations compute in `Float64`.
- Docs gallery cards come from OhMyCards.jl.

# 0.7.2 - 2024-06-20
- `meshimage` uses Makie's `@recipe` attribute syntax.
- Added a Healpix.jl example.

# 0.7.1 - 2024-06-14
- Added the example gallery to the docs.
- `to_multipoly` accepts geometry collections.

# 0.7.0 - 2024-06-12
- Converted all internal computations to use `Float64` instead of `Float32` thanks to @ffreyer's work in Makie.jl v0.21.
    - Consequently, the `PROJ_RESCALE_FACTOR` hack is also removed.
    - Zooming in close should also work now, with the correct ticks being shown.
- Added the option to provide an integer `scale` in `coastlines` and `land`, which triggers GeoMakie to get data from [NaturalEarth.jl](https://github.com/JuliaGeo/NaturalEarth.jl) instead of using the bundled data.
- Updated the `to_multipoly` function to use GeoInterface traits, so that it's more universal.
- Added several new examples - `tissot.jl`, `source_crs.jl`, etc.
- Plots accept `source` and `dest` directly, so a single axis can hold data in several CRS.
- `datalims` and `datalims!` are deprecated; use `Makie.autolimits` and `Makie.reset_limits!`.
- Added `hidedecorations!` for `GeoAxis`.
- Ticks and limits are correct when `source` is a CRS other than lon/lat.
- GeoMakie precompiles: the Makie method extensions moved into `__init__`.
- Docs moved to DocumenterVitepress, with a gallery of examples.
- Compatible with Makie v0.21.

# 0.6.5 - 2024-05-18
- Added `coastlines(ga)`, which returns an observable of coastlines split at the axis's reference longitude, so `lon_0` other than 0 draws cleanly.

# 0.6.4 - 2024-05-16
- Removed the pirated `Base.isfinite` method on GeometryBasics points and vectors.

# 0.6.3 - 2024-05-13
- Compatible with GeometryBasics v0.4.11.

# 0.6.2 - 2024-02-25
- Added a German lakes example.

# 0.6.1 - 2024-02-06
- Examples render at higher PNG quality and pick their backend correctly.
- Compatible with GeoJSON v0.8 and any Proj v1.

# 0.6.0 - 2024-01-04
- `GeoAxis` is a Makie block, built on Makie's transformed-space support.
- Added the `meshimage` recipe, which draws an image as a projected mesh.
- Added Geodesy.jl-based transformations to Cartesian Earth coordinates.
- Added themable axis spines and grid lines, and customizable `npoints` for their density.
- Ticks and `x`/`ylimits` are computed in transformed space.
- Compatible with Makie v0.20.

# 0.5.1 - 2023-07-06
- `geo2basic` accepts any GeoInterface type.
- `xticklabelpad` offsets in the right direction, and axis spines are no longer cut off.
- Compatible with GeoJSON v0.7.

# 0.5.0 - 2022-12-06
- Compatible with Makie v0.19.

# 0.4.6 - 2022-10-26
- Axis bounds come from `Proj.bounds`, which is accurate near projection edges.

# 0.4.5 - 2022-10-13
- Compatible with Makie v0.18.

# 0.4.4 - 2022-09-23
- Grid lines are transparent.

# 0.4.3 - 2022-09-22
- `geo2basic` looks up GeoInterface traits directly, and handles GeoJSON integer coordinates.

# 0.4.2 - 2022-07-23
- GeoMakie uses Proj.jl; the tick label formatter is fixed.
- Compatible with GeoInterface v1.0.

# 0.4.1 - 2022-05-15
- Compatible with Makie v0.17.1: text bounding boxes pass the new word-wrap width.

# 0.4.0 - 2022-05-09
- Added minor grid lines, and made the tick formatters themable.
- Added `geoformat_ticklabels` and the lon/lat tick label formatting functions.
- Tick labels are padded per direction and aligned to the axis frame.
- Compatible with Makie v0.17.

# 0.3.1 - 2022-03-16
- The axis bounding box is computed from the transformation, so limits fit the projected data.

# 0.3.0 - 2022-01-13
- Added `GeoAxis`, with gridlines, user-tunable ticks, and keywords propagated to `Axis`.
- Added `coastlines()` as a plottable geometry.
- Added a documentation site.
- Compatible with Makie v0.16.

# 0.2.2 - 2021-08-28
- Compatible with Makie v0.15.2 and GeometryBasics v0.4.

# 0.2.1 - 2021-07-19
- Compatible with Makie v0.15.

# 0.2.0 - 2021-07-04
- Proj4.jl is a test dependency; GeoMakie itself carries no projection library.
- Grid lines stop wrapping around the globe.

# 0.1.17 - 2021-06-23
- Compatible with Makie v0.14.

# 0.1.16 - 2021-05-26
- Compatible with Makie v0.13 and GeoJSON v0.5.

# 0.1.15 - 2020-10-27
- Compatible with AbstractPlotting v0.13 and Proj4 v0.7.

# 0.1.14 - 2020-08-27
- `GeoAxis` stores a `transform_func` in place of a CRS.
- Compatible with GeometryBasics v0.3.

# 0.1.13 - 2020-05-24
- Compatible with AbstractPlotting v0.11.

# 0.1.12 - 2020-05-21
- Compatible with MakieLayout v0.9.

# 0.1.11 - 2020-04-29
- Compatible with MakieLayout v0.8.

# 0.1.10 - 2020-04-29
- `coastlines` draws correctly.
- Compatible with MakieLayout v0.7.

# 0.1.9 - 2020-04-20
- Removed the side constants; the axis uses the new AbstractPlotting API.
- CairoMakie renders GeoMakie plots.

# 0.1.8 - 2020-04-15
- GeoMakie uses GeometryBasics throughout, replacing GeometryTypes.
- Compatible with AbstractPlotting v0.10 and MakieLayout v0.6.

# 0.1.7 - 2020-03-29
- Compatible with MakieLayout v0.5.

# 0.1.6 - 2020-03-22
- Compatible with MakieLayout v0.4.

# 0.1.5 - 2020-03-05
- Compatible with GeometryTypes v0.8.

# 0.1.4 - 2020-02-27
- Added the documentation site, covering `GeoAxis`, the stock recipes, and the API.
- NaN-separated vectors plot correctly.
- Compatible with MakieLayout v0.3.

# 0.1.3 - 2020-02-18
- `coastlines` accepts plot keywords.

# 0.1.2 - 2020-02-17
- Projections are `CoordinateTransformations` transformations, constructed via `ExpTransformation`.
- Added a MakieLayout example.

# 0.1.1 - 2020-02-01
- Added the full set of geometry conversions, and the full projection transform.

# 0.1.0 - 2020-01-30
- Initial release: `geoaxis` and `coastlines` recipes, Proj4-backed projections, and conversions from GeoJSON and GeometryTypes geometries to plottable types.
