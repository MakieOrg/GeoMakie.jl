#=
# Tripolar grid

Ocean and climate models rarely live on a plain longitude–latitude grid: to avoid the
coordinate singularity at the North Pole they use a **curvilinear** grid whose northern
cells fold around two displaced poles (a *tripolar* grid). GeoMakie's `contourf!` works
directly on such a grid — you pass the longitude and latitude as 2-D matrices (one value
per cell) rather than 1-D vectors — and still clips correctly at a projection's seam.

Here we take a real [`Oceananigans.TripolarGrid`](https://github.com/CliMA/Oceananigans.jl),
paint a tilted wave field on it, close the grid's longitudinal seam with
`GeoMakie.add_cyclic_point`, and draw it with `contourf!` on the interrupted oblique
Mollweide projection (`imoll_o`) — a hard case that tears the map into lobes.
=#
using GeoMakie, CairoMakie
using Oceananigans
CairoMakie.activate!(type = :svg) # hide

# ## The field
# A wave that is zero and ``C^1`` at both poles (`sind(2φ)^2`), modulated in longitude. We
# evaluate it in a frame that is tilted 60° about an equatorial axis **and** rotated so the
# pattern's pole sits at 15°E rather than 0°E — an asymmetric field with no symmetry for the
# seam-splitter to lean on.
_pole_wave(λ, φ) = sind(2φ)^2 * cosd(15 + 3λ + 20 * cosd(2λ + 12))

function rotated_pole_wave_field(λ, φ; α = 60, λ₀ = 15)
    ## rigid-rotate east by λ₀ so the pattern's pole lands at λ₀°E, then tilt α° about the
    ## (rotated) equatorial axis
    x = @. cosd(φ) * cosd(λ - λ₀)
    y = @. cosd(φ) * sind(λ - λ₀)
    z = @. sind(φ)
    xr = @. x * cosd(α) + z * sind(α)
    yr = y
    zr = @. -x * sind(α) + z * cosd(α)
    φr = @. asind(clamp(zr, -1, 1))
    λr = @. atand(yr, xr)
    return _pole_wave.(λr, φr)
end

# ## The grid
# Build a tripolar grid and read its cell-centre longitudes/latitudes as 2-D matrices. The
# northern half is visibly curvilinear — the meridians bend around the two displaced poles.
grid = TripolarGrid(size = (120, 60, 1))
λn, φn, _ = nodes(grid, Center(), Center(), Center())
λ = Array(λn[1:grid.Nx, 1:grid.Ny, 1])
φ = Array(φn[1:grid.Nx, 1:grid.Ny, 1])
z = rotated_pole_wave_field(λ, φ)

# ## Close the seam
# A tripolar grid is periodic in its first (i) index, but the cells don't quite meet — so a
# `contourf!` would leave a thin wedge open at the seam. `add_cyclic_point` appends a copy of
# the first i-slice (with longitude shifted by 360°) to `λ`, `φ` and the data, closing it.
# The 3-argument (matrix) method is the one to use for curvilinear grids:
λc, φc, zc = GeoMakie.add_cyclic_point(λ, φ, z)

# ## Plot
# `imoll_o` is the interrupted oblique Mollweide — the field is torn into lobes and each
# lobe filled correctly, with no smear across the interruptions. The land polygons are drawn
# **opaque, on top of** the `contourf!` (and clipped at the same seam), so coastlines read
# clearly against the field rather than blending into it.
fig = Figure(size = (900, 480))
ga = GeoAxis(fig[1, 1]; dest = "+proj=imoll_o +lon_0=-160",
    title = "Tilted wave on an Oceananigans tripolar grid (imoll_o)")
hidedecorations!(ga; grid = false)
cf = contourf!(ga, λc, φc, zc; levels = range(-1, 1; length = 11),
    extendlow = :auto, extendhigh = :auto)
poly!(ga, GeoMakie.land(); color = :gray90, strokecolor = :black, strokewidth = 0.3)
Colorbar(fig[1, 2], cf; label = "field")
fig

#=
```@cardmeta
Description = "contourf on a curvilinear Oceananigans tripolar grid"
Cover = fig
```
=#

#=
The CairoMakie backend type is process-global, so restore the default PNG backend here —
otherwise later (raster-heavy) example pages such as `meshimage` would be emitted as SVG too.

```@setup tripolar_reset
using CairoMakie
CairoMakie.activate!(px_per_unit = 2, type = :png)
```
=#
