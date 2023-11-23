```@meta
EditURL = "../../examples/geostationary_image.jl"
```

````@example geostationary_image
using Makie, GeoMakie, CairoMakie
using Downloads, FileIO
````

Download a geostationary satellite image

````@example geostationary_image
img = rotr90(FileIO.load(Downloads.download("https://gist.github.com/pelson/5871263/raw/EIDA50_201211061300_clip2.png")))
image(img)
````

then, plot the figure etc

````@example geostationary_image
fig = Figure()
ga = GeoAxis(fig[1, 1]; dest = "+proj=natearth")
lines!(ga, GeoMakie.coastlines())

ga.title[] = "Image from geostationary satellite" # this doesn't do anything - yet!
````

# Surface could be used as well but is slower!
surface!(
    ga,
    -5500000..5500000, -5500000..5500000, # the bounding box in input space for the image
    ones(size(img)...); # dummy points to create the surface
    color = img,
    source = "+proj=geos +h=35786000"
)

````@example geostationary_image
meshimage!(ga,
    -5500000 .. 5500000, -5500000 .. 5500000, img;
    source="+proj=geos +h=35786000",
    npoints=100
)
fig
````

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

