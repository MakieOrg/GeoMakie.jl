```@setup nonlinear-transformations
using Makie, CairoMakie, GeoMakie
using Makie.FileIO
```
# Nonlinear transformations


## What are they?

Nonlinear transformations take many forms.  Some are simply "projections" like perspective or orthographic, which are linear in some dimension (representable by a matrix).  Then you have things like log-scale axes, geographic projections, and esoteric physics stuff (like the space near a black hole).

When dealing with nonlinear transformations, it's useful to define our terminology.  _Spaces_ are coordinate spaces, and we consider two relevant ones:
- **Data** space is the space before transformation, also called the **input** space.
- **Transformed** space is the space after transformation is applied.  This can be transformed directly to pixel space by an affine, linear transform.

I can categorize all nonlinear transforms into three types:

### Affine

Any affine transform is not actually nonlinear, but a simple combination of translation, scale and rotation.  They are explained quite well in [this StackOverflow question](https://gamedev.stackexchange.com/questions/72044/why-do-we-use-4x4-matrices-to-transform-things-in-3d).

We don't really consider affine transforms nonlinear here, since they are more or less linear.  But these are the transformations which you generate when you call `translate!`, `rotate!`, or `scale!`.  In these transformations, a straight line is still straight.

```@example nonlinear-transformations
meshimage(rotr90(Makie.logo()))
```

### Nonlinear but separable

Here, I mean separable in the sense that systems of ODEs can be separable.  Specifically, _nonlinear and separable_ transforms have the property that each coordinate is independent of all others.  This means that the `x`-coordinate in transformed space depends only on the `x`-coordinate in input space, and so on and so forth for the y and z coordinates.

```@example nonlinear-transformations
meshimage(
    1..size(Makie.logo(), 2), 1..size(Makie.logo(), 1), 
    rotr90(Makie.logo()); 
    axis = (; xscale = log, yscale = log10)
)
```

##### Examples


### Nonlinear and inseparable

Geographic projections are prime examples of this.  The `x`-coordinate in transformed space depends on the input `x` and `y` coordinates, as does the the `y`-coordinate in transformed space.

```@example nonlinear-transformations
meshimage(
    -180..180,
    -90..90,
    rotr90(Makie.logo()); 
    axis = (; type = GeoAxis, target_projection = "+proj=igh")
)
```

##### Examples

###### Geographic plots

###### The space near a black hole

## Special situations

## Input v/s transformed bounding boxes

The bounding box in transformed space directly maps to that in pixel space, and so must be a rectangle by virtue of its nature.

However, in input space, this is not necessarily the case.  Consider the following GeoAxis:

```@example nonlinear-transformations
fig = Figure()
ga = GeoAxis(fig[1, 1]; target_projection = "+proj=ortho +lon_0=19 +lat_0=50")
lines!(ga, GeoMakie.coastlines())
fig
```

If we look at the grid of lon/lat values which are valid in transformed space,

```@example nonlinear-transformations
lons = LinRange(-180, 180, 500)
lats = LinRange(-90, 90, 500)

valid_points = [isfinite(Makie.apply_transform(ga.transform_func[], Point2f(lon, lat))) for lon in lons, lat in lats]

f, a, p = heatmap(
    lons, lats, valid_points; 
    axis = (; aspect = DataAspect(), xlabel = "Longitudes", ylabel = "Latitudes")
)
Legend(f[2, 1], [PolyElement(color = first(to_colormap(p.colormap[]))), PolyElement(color = last(to_colormap(p.colormap[])))], ["Invalid (invisible)", "Valid (visible)"], tellheight = true, tellwidth = false)
f
```

You can see that if we were to try to find a bounding box, it would either be too small (excluding the bulge at the middle) or too large (including some invalid regions).

## Coordinate singularities
