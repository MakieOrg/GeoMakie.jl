using GLMakie
using GeoMakie
using GeoMakie.GeoInterface
using GeoMakie.GeoJSON
using Downloads
using Proj4

begin
    # select a coordinate projection, using a string that PROJ accepts
    # see e.g. https://proj.org/operations/projections/index.html
    source = "+proj=longlat +datum=WGS84"
    dest = "+proj=natearth2"
    trans = Proj4.Transformation(source, dest, always_xy=true)
    ptrans = Makie.PointTrans{2}(trans)

    fig = Figure()
    ax = Axis(fig[1,1], aspect = DataAspect())

    # all input data coordinates are projected using this function
    ax.scene.transformation.transform_func[] = ptrans

    # draw projected grid lines and set limits accordingly
    lons = -180:10:180
    lats = -90:10:90
    field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]
    points = map(CartesianIndices(size(field))) do xy
        x, y = Tuple(xy)
        Point2f0(lons[x], lats[y])
    end
    limits = FRect2D(Makie.apply_transform(ptrans, points))
    limits!(ax, limits)
    wireframe!(ax, lons, lats, field, color=(:gray, 0.2), transparency=true)

    # add black polygons for land area
    url = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"
    land = Downloads.download(url * "ne_110m_land.geojson", IOBuffer())
    land_geo = GeoJSON.read(seekstart(land))
    poly!(ax, land_geo, color="black")

    # add grey dots for populated places
    pop = Downloads.download(url * "ne_10m_populated_places_simple.geojson", IOBuffer())
    pop_geo = GeoJSON.read(seekstart(pop))
    scatter!(ax, GeoMakie.geo2basic(pop_geo), color="lightgrey", markersize=1.2)

    hidedecorations!(ax)
    hidespines!(ax)
    display(fig)
end
