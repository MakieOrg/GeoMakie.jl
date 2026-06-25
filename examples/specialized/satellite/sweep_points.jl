# # Satellite sweep plot
# Here, we'll plot the data collected by a satellite as it orbits
# the Earth.
# Note that we've chosen to fake the data by simulating the satellite sweep
# over a high-level data product.  See the `satellite_sweep_plot.jl` example
# in `GeoMakie/examples/specialized/satellite/` for a more complete example
# using real data.
#=
```@cardmeta
Description = "Plot satellite data acquisition on the globe"
Cover = f
```
=#

using LinearAlgebra: normalize
using Geodesy
using GeometryBasics: Point2d
using SatelliteToolbox, SatelliteAnalysis
using GLMakie, GeoMakie

"""
    sweep_points(position, velocity, distances)

Sweep points along a line of sight, given a position and velocity in the ECEF frame,
and distances in meters.

## Arguments
- `position`: The position of the satellite.
- `velocity`: The velocity of the satellite.
- `distances`: The distances to sweep along the line of sight, in meters.  Will be interpreted as meters in the ENU frame.

## Returns
A vector of 2-tuples of (longitude, latitude) in degrees, representing the sweep points according to `distances`.

## Extended help

## How does this work?

The algorithm is pretty simple.  Given a position and velocity in the earth-centered earth-fixed frame (ECEF),
we can calculate the position and velocity in the local frame of the satellite's position on the surface 
of the ellipsoidal Earth.  This is the East-North-Up (ENU) frame.  

We can then calculate the points along the line of sight by sweeping along a vector perpendicular to the velocity vector,
in this ENU space which is essentially the projection of the local tangent plane to the sphere.
This vector can be adjusted, rotated, etc. as necessary to change the angle of the sensor etc.

From ENU space offsets we go back to long-lat space, which is the standard way to represent positions on the Earth.

## Performance

This runs with 2 allocations (not sure why 2, probably one of the transforms)
and in ~6 μs for 50 points on my machine.  Scales linearly with `length(distances)`.
"""
function sweep_points(position, velocity, distances)
    ## Input is in ECEF space.
    ## Operate in ENU space and then convert to long lat
    enu_transf = ENUfromECEF(position, wgs84)
    lla_transf = LLAfromENU(position, wgs84)
    enu_position = ENU(0.0, 0.0, 0.0) # by definition of the enu frame
    enu_velocity = enu_transf(position +velocity) # should be enu(position + velocity) - enu(position) but we don't actually need to do that

    ## Calculate the direction of the velocity
    enu_direction = normalize(Point2d(enu_velocity.e, enu_velocity.n))
    sweep_left_direction = Point2d(enu_direction[2], -enu_direction[1])

    ## Calculate the points along the line of sight
    sweep_points = map(distances) do distance
        p = Point2d(enu_position.e, enu_position.n) + distance * sweep_left_direction
        lla = lla_transf(ENU(p[1], p[2], 0.0))
        (lla.lon, lla.lat)
    end
end
## Convenience method for propagating a satellite and then sweeping points along its line of sight
sweep_points(sv::SatelliteToolbox.OrbitStateVector, distances) = sweep_points(ECEF(sv.r), ECEF(sv.v), distances)
## Simple example usage
JFK = LLA(; lat = 40.6413, lon = -73.7781, alt = 0.0)
sp = sweep_points(ECEFfromLLA(wgs84)(JFK), ECEF(0, 0, 1), LinRange(0, 49, 50))

# A more complex example, simulating a satellite
amz1_tle = SatelliteToolbox.tle"""
       AMAZONIA 1
       1 47699U 21015A   25205.73369244  .00000207  00000+0  78058-4 0  9996
       2 47699  98.3576 279.7581 0001748  96.4737 263.6651 14.40869396231498
"""

prop = SatelliteToolbox.Propagators.init(Val(:SGP4), amz1_tle)

sv_teme = SatelliteToolbox.Propagators.propagate!(prop, 0:12:(3600*10), OrbitStateVector)
eop = SatelliteToolbox.fetch_iers_eop()
sv_itrf = SatelliteToolbox.sv_eci_to_ecef.(sv_teme, (TEME(),), (SatelliteToolbox.ITRF(),), (eop,))

sweep_points_timeseries = sweep_points.(sv_itrf, (LinRange(-125000, 125000, 5),))

# Plot the sweep points on a globeaxis, just to get an idea.
scatter(reduce(vcat, sweep_points_timeseries); axis = (; type = GlobeAxis))

# Sample a raster, at the points at which 
# the satellite's sensor would "sample".
using Rasters, RasterDataSources
import ArchGDAL, NCDatasets # to activate extensions on rasters for file IO
ras = try
    worldclim_file = RasterDataSources.getraster(WorldClim{Climate}, :tmin; month = 1)
    replace_missing(Raster(worldclim_file), NaN)
catch e
    @warn "WorldClim is unreachable (server offline); using a synthetic raster so the docs still build. The published docs use the real data whenever the server is up." exception = (e, catch_backtrace())
    ## Synthetic global raster so the sampling/surface below still works. It must use
    ## `Intervals` sampling (like the real WorldClim raster) so `Contains(<arbitrary lon/lat>)`
    ## below resolves; `Points` sampling only matches exact grid coordinates.
    ## Span the full globe (to ±180/±90) so any sampled lon/lat is in bounds.
    _Lk = Rasters.DimensionalData.Lookups
    _r = Raster(rand(Float64, X(-180.0:1.0:180.0), Y(-90.0:1.0:90.0)))
    set(_r, X => _Lk.Intervals(_Lk.Center()), Y => _Lk.Intervals(_Lk.Center()))
end
# Re-sample the raster to the sampling timeseries.  This is currently a manual process,
# but we should just make everything a raster here.
xys = reduce(hcat, sweep_points_timeseries)
vals = map(xys) do xy
    ras[X(Contains(xy[1])), Y(Contains(xy[2]))]
end
# Finally, we plot the results on a GeoMakie GlobeAxis.
f, a, p = surface(
    first.(xys), last.(xys), zeros(size(xys)); 
    color = vals, 
    shading = NoShading,
    axis = (; type = GlobeAxis, show_axis = false)
)
## Create a "background" mesh such that the satellite traces 
## on the other side of the globe (from the camera's point of view) are faded out.
bg = meshimage!(a, -180..180, -90..90, reshape([RGBAf(1,1,1,0.5)], 1, 1); uv_transform = :rotr90, zlevel = -100_000, reset_limits = false)
lines!(a, GeoMakie.coastlines(); color = (:black, 0.5), linewidth = 1)
f