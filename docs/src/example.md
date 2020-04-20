# Example usage

```@setup 1
using GeoMakie, AbstractPlotting, MakieLayout, CairoMakie
```

This is a small example which demonstrates how to use GeoMakie.  We go through the basic setup of a plot, and explore the different options which are available for plotting.

It helps to think of GeoMakie not as a fully featured, all-in-one solution like Cartopy is; instead, it is simply a collection of utilities which make creating geographical plots easier.

We'll begin by simulating a field across the Earth:

```@example 1
using GeoMakie

lons = LinRange(-179.5, 179.5, 360)
lats = LinRange(-89.5, 89.5, 180)

field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]
```

Presumably, you won't want to use the boring old Plate-Carrée projection.  Fortunately, GeoMakie provides several convenience constructors, and you can use [Proj4.jl](https://github.com/JuliaGeo/Proj4.jl) to construct arbitrary projections.

```@example 1
source, dest = LonLat(), WinkelTripel()
```

There are two main entry points to plot a field.  If you're using the GLMakie backend (which is the default, but does require a GPU), then you have the option of using `surface` or `mesh`; however, if you're using the CairoMakie backend (which does not require a GPU), then you can only use `mesh`.

We'll cover the `surface` method first.

```julia
xs, ys = xygrid(lons, lats)
Proj4.transform!(source, dest, vec(xs), vec(ys))

scene = surface(xs, ys; color = field, shading = false, show_axis = false, scale_plot = false)
```
![](rawmesh.png)

This is a basic field over the Earth!

Now, we can make this a bit more interpretable by adding an axis:
```julia
geoaxis!(scene,  extrema(lons), extrema(lats); crs = (src = source, dest = dest,))
```
![](axismesh.png)

GeoMakie also ships a low-resolution coastline file from [Natural Earth](https://www.naturalearthdata.com/), which is conveniently exposed by the `coastlines` function:
```julia
coastlines!(scene; crs = (src = source, dest = dest,))
```
![](final.png)

That's the surface API done.  Now, we can go a little lower-level into the `mesh` function, which can be used whether you have a GPU or not.

To create a mesh, we need to create a triangulation scheme.  This is very easy for a regular grid (made up of regular, rectangular cells), and there is a convenience function to do this in GeoMakie:

```@example 1
points, faces = GeoMakie.triangulated_grid(lons, lats)
```
This returns a vector of points as vertices of a grid, and a matrix of triangle faces.

We can now transform our points into the target coordinate space:
```@example 1
tpoints = Proj4.transform.(source, dest, points)
```

and plot them as a mesh:
```@example 1
scene = mesh(
    tpoints, faces;
    color = GeoMakie.img2colorvec(field),
    shading = false,
    show_axis = false, scale_plot = false, # don't show the normal axis and
                                           # ensure the aspect ratio is correct
    resolution = (1000, 500)               # just a nice resolution for this projection
)
save("rawmesh.png", scene); nothing # hide
```
![](rawmesh.png)

Now, we can add the geoaxis and coastlines:
```julia
geoaxis!(scene, extrema(lons), extrema(lats); crs = (src = source, dest = dest,))
coastlines!(scene; crs = (src = source, dest = dest,))
```
```@setup 1
geoaxis!(scene, extrema(lons), extrema(lats); crs = (src = source, dest = dest,))
save("axismesh.png", scene); nothing # hide
coastlines!(scene; crs = (src = source, dest = dest,))
save("final.png", scene); nothing # hide
```
and we're done!
![](final.png)

Using the CairoMakie backend, you can output to vector formats like SVG and PDF.  However, be warned - these files can become quite large!  Even a small example like this yields a 3 MB SVG, and a 20 MB PDF.
