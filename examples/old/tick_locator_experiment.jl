using Pkg
Pkg.activate()
using Revise

# using GLMakie

using GeoMakie
using CairoMakie
using GeoMakie.Proj, GeoMakie.GeoJSON
using Shapefile
using Downloads

# countries_geo = GeoMakie.GeoJSON.read(read(download("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_0_countries.geojson"), String))

# TODO define this in geomakie
Makie.convert_arguments(::Type{<:Combined{Makie.poly}}, geom::GeoInterface.AbstractGeometry) = (geo2basic(geom),)

table = Shapefile.Table("/Users/anshul/Downloads/ne_10m_admin_0_countries/ne_10m_admin_0_countries.shp")
shapes = Shapefile.shapes(table)

relev_inds = [
    findfirst(==("CAN"), table.ADM0_A3),
    findfirst(==("AUS"), table.ADM0_A3),
    findfirst(==("IND"), table.ADM0_A3),
    findfirst(==("CHN"), table.ADM0_A3),
    findfirst(==("ARG"), table.ADM0_A3),
    findfirst(==("SWE"), table.ADM0_A3),
    findfirst(==("MRT"), table.ADM0_A3),
    findfirst(==("KIR"), table.ADM0_A3)
]

function test_tickpad()

    fig = Figure(size = (1600,1600))

    gas_decs = [GeoAxis(fig[i, j]; dest = "+proj=natearth") for i in 1:3, j in 1:4]
    gas = first.(gas_decs)[:]
    decs = last.(gas_decs)[:]

    # set up orthogonal axis
    xlims!(gas[10], -90, 90)
    gas[10].scene.transformation.transform_func[] = Proj.Transformation("+proj=latlong", "+proj=ortho")
    gas[11].scene.transformation.transform_func[] = Proj.Transformation("+proj=latlong", "+proj=wintri")
    gas[12].scene.transformation.transform_func[] = Proj.Transformation("+proj=latlong", "+proj=igh")



    polys = [poly!(gas[i], shapes[relev_inds[i]]) for i in 1:length(relev_inds)]

    datalims!.(gas[1:length(relev_inds)])

    [gas[i].title = table.ADM0_A3[relev_inds[i]] for i in 1:length(relev_inds)]

    fig

    function plot_directional_pads!(ax::Axis, dict::Dict{Symbol, Any})
        topscene = ax.blockscene # we plot here

        xtickplot = dict[:xticklabel]
        ytickplot = dict[:yticklabel]

        # repeat the tick finding process
        limits = ax.finallimits[]
        lmin = minimum(limits)
        lmax = maximum(limits)
        xlimits = (lmin[1], lmax[1])
        ylimits = (lmin[2], lmax[2])

        _xtickvalues, _xticklabels = Makie.get_ticks(LinearTicks(7), identity, GeoMakie.geoformat_ticklabels, xlimits...)
        _ytickvalues, _yticklabels = Makie.get_ticks(LinearTicks(7), identity, GeoMakie.geoformat_ticklabels, ylimits...)

        _xtickpos_in_inputspace = Point2f.(_xtickvalues, ylimits[1])
        _ytickpos_in_inputspace = Point2f.(xlimits[1], _ytickvalues)

        # update but do not notify
        origin_point = Point2f(ax.scene.viewport[].origin)
        xtickpoints = GeoMakie.project_to_pixelspace(ax.scene, _xtickpos_in_inputspace) .+
                      Ref(origin_point)

        ytickpoints = GeoMakie.project_to_pixelspace(ax.scene, _ytickpos_in_inputspace) .+
                      Ref(origin_point)


        xtickpad = GeoMakie.directional_pad.(
            Ref(ax.scene), Ref(limits), Ref(Point2f(0, 1)), _xtickpos_in_inputspace,
            _xticklabels, Ref(Point2f(ax.xticklabelpad[], 0)), ax.xticklabelsize[], ax.xticklabelfont[],
            ax.xticklabelrotation[]; debug = true
        )
        ytickpad = GeoMakie.directional_pad.(
            Ref(ax.scene), Ref(limits), Ref(Point2f(1, 0)), _ytickpos_in_inputspace,
            _yticklabels, Ref(Point2f(ax.yticklabelpad[], 0)), ax.yticklabelsize[], ax.yticklabelfont[],
            ax.yticklabelrotation[]; debug = true
        )

        arrows!(topscene, xtickpoints, xtickpad .* 2; color = :red)
        arrows!(topscene, ytickpoints, ytickpad .* 2; color = :red)

    end

    plot_directional_pads!.(gas, decs)

    save("ticklabel_directions.png", fig; px_per_unit=4)

end

GLMakie.activate!()
display(lines(rand(10)))



# Direction finder - find how to displace the tick so that it is out of the axis
function directional_pad(scene::Scene, limits::Rect2, tickmarkdir::Point2f, tickcoord_in_inputspace::Point2f, ticklabel::AbstractString, tickpad, ticksize, tickfont, tickrotation; ds = 5, debug = false)
    # Define shorthand functions for dev purposes - these can be removed before release
    tfunc = x -> Makie.apply_transform(scene.transformation.transform_func[], x)
    inv_tfunc = x -> Makie.apply_transform(Makie.inverse_transform(scene.transformation.transform_func[]), x)
    # convert tick coordinate to other spaces
    tickcoord_in_pixelspace = project_to_pixelspace(scene, tickcoord_in_inputspace)
    tickcoord_in_dataspace = tfunc(tickcoord_in_inputspace)

    debug && @show tickcoord_in_dataspace tickcoord_in_inputspace tickcoord_in_pixelspace

    δs = Point2f(Makie.project(camera(scene), :pixel, :data, tickcoord_in_pixelspace + tickmarkdir * ds))

    Δs = inv_tfunc(δs) - tickcoord_in_dataspace

    debug && @show Δs

    Σp = inv_tfunc(tickcoord_in_dataspace + Δs)

    tick_end_in_pixelspace = project_to_pixelspace(scene, Σp)

    pixel_Δx, pixel_Δy = tick_end_in_pixelspace - tickcoord_in_pixelspace
    # # determine direction to go in order to stay inbounds.
    # xdir = tickcoord_in_inputspace[1] < 0 ? +1 : -1
    # ydir = tickcoord_in_inputspace[2] > 0 ? +1 : -1
    # Δs = Vec2f(xdir, ydir) .* tickpad ./ sum(tickpad) * ds
    # # find the x and y directions
    # # multiply by the sign in order to have them going outwards at any point
    # Σp = sign(sum(Δs)) * inv_tfunc(tickcoord_in_dataspace + Δs)
    # # project back to pixel space
    # pixel_Δx, pixel_Δy = project_to_pixelspace(scene, Σp) - project_to_pixelspace(scene, tickcoord_in_inputspace)
    # # invert direction - the vectors were previously facing the inside,
    # # now they will face outside .
    # final_xdir = tickcoord_in_inputspace[2] > 0 ? -1 : +1
    # final_ydir = tickcoord_in_inputspace[1] < 0 ? -1 : +1

    dx = -1 * pixel_Δx
    dy = -1 * pixel_Δy

    tx = tickcoord_in_inputspace[1]
    ty = tickcoord_in_inputspace[2]

    # if tx > 0 && ty > 0 # e.g., china
    #     if tickmarkdir[1] == 0 # x tick
    #         tmp = dx
    #         dx = dy
    #         dy = -tmp
    #     else # y tick
    #         dx = -dx
    #     end
    # elseif tx > 0 && ty < 0 # e.g. australia
    #     if tickmarkdir[1] == 0
    #         tmp = dx
    #         dx = -dy
    #         dy = -tmp
    #     else
    #         dx = -dx
    #     end
    # elseif tx < 0 && ty < 0
    #     if tickmarkdir[1] == 0
    #     else
    #     end
    # elseif tx < 0 && ty > 0
    #     if tickmarkdir[1] == 0
    #     else
    #     end
    # end

    # Correct the angle of displacement
    θ = atan(dy/dx)
    # if θ ∈ 0..π && tickpad[1] < tickpad[2]
    #     dy = -dy
    #     dx = -dx
    # elseif θ ∈ -0.5π..0.5π && tickpad[1] > tickpad[2]
    #     dy = -dy
    #     dx = -dx
    # end

    # The vector which is normal to the plot in pixel-space.
    normal_vec = Vec2f((dx, dy)./sqrt(dx^2 + dy^2))

    # We have computed the normal vector - now we have to get tick extents
    extents = text_bbox(
        ticklabel, ticksize,
        tickfont, Vec2f(0), tickrotation,
        0.0, # Makie.to_value(Makie.theme(scene, :justification)),
        0.0, # Makie.to_value(Makie.theme(scene, :lineheight))
    )

    padding_vec = normal_vec .* (LinearAlgebra.norm(extents.widths)/2) - tickpad

    # println("$ticklabel ($(tickpad)) $(rad2deg(θ)) ⟹ $(_sprinti(normal_vec)) ⟹ $(_sprinti(padding_vec)); $(_sprinti(extents.widths)), $(Σp)")


    return padding_vec
end
