using Revise

using Makie, CairoMakie, GeoMakie, Tyler

using GeoInterface
using GeoInterface: extent

import GeometryOps as GO
import GeoInterface as GI

using GeoInterfaceMakie

geojson = GeoMakie.coastlines()

webmerc_geojson = GO.reproject(GI.convert.((GI,), geojson) |> GO.tuples; transform = GeoMakie.create_transform("+proj=webmerc +datum=WGS84", "+proj=longlat +datum=WGS84"))

function Makie.MakieCore.attribute_name_allowlist()
    (:xautolimits, :yautolimits, :zautolimits, :label, :rasterize, :model, :transformation, :dest, :source)
end

fig = Figure()
nax = Axis(fig[1, 1]; aspect = DataAspect())
m = Tyler.Map(london, figure = fig, axis = nax)

fig = Figure()
ga = GeoAxis(fig[1, 1]; source = "+proj=webmerc +datum=WGS84", dest = "+proj=webmerc +datum=WGS84")
lines!(ga, webmerc_geojson)
image!(ga, -180..180, -89..89, GeoMakie.earth() |> rotr90; source = "+proj=longlat +datum=WGS84", dest = "+proj=webmerc +datum=WGS84", interpolate = false)
fig

mumbai_xy = (-72.877655, 19.075983)
mumbai_wm_xy = GO.reproject(mumbai_xy; transform = GeoMakie.create_transform("+proj=webmerc +datum=WGS84", "+proj=longlat +datum=WGS84"))
GO.reproject(mumbai_wm_xy; transform = GeoMakie.create_transform("+proj=webmerc +datum=WGS84", "+proj=longlat +datum=WGS84") |> Makie.inverse_transform)



mumbai_limits = (((mumbai_wm_xy .- 5000)...,), ((mumbai_wm_xy .+ 5000)...,))
limits!(ga, mumbai_limits[1], mumbai_limits[2])
fig
lims = ((-10252.524915718823, -5799.745763988467), (6.710218830581673e6, 6.714690955633332e6))
london = Rect2d(-0.0921, 51.5, 0.04, 0.025)
fig = Figure();
ga = GeoAxis(fig[1, 1]; source = "+proj=webmerc +datum=WGS84", dest = "+proj=eqearth +datum=WGS84")
mgeo = Tyler.Map(GeoInterface.extent(m), Tyler.MapTiles.web_mercator, figure=fig, axis=ga)

limrect = Rect2f(rect.X[1], rect.Y[1], -(-)(rect.X...), -(-)(rect.Y...))

fig = 