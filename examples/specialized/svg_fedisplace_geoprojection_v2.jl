
using GeoMakie, Proj

using Rasters
using Rasters.DimensionalData.Lookups

import GeoInterface as GI, GeometryOps as GO, GeoFormatTypes as GFT

earth_img = GeoMakie.earth()
yaxis = LinRange(-90 + (180/size(earth_img, 1)), 90, size(earth_img, 1)) |> reverse
xaxis = LinRange(-180, 180 - (360 / size(earth_img, 2)), size(earth_img, 2))
earth_ras = Raster(earth_img, (Y(Projected((yaxis); sampling = Intervals(Start()), crs = EPSG(4326))), X(Projected((xaxis); sampling = Intervals(Start()), crs = EPSG(4326)))))


target_projection = ProjString("+proj=wintri +type=crs")
# target_projection = ProjString("+proj=ortho +type=crs")

transf = Proj.Transformation(GI.crs(earth_ras), target_projection; always_xy = true)

original_lookup_values = DimPoints(dims(earth_ras); order = (X, Y))# .|> x -> shiftlocus(Center(), x))

transformed_lookup_values = transf.(original_lookup_values)

resolution = length.(dims(earth_ras, (X, Y)))

xlims = Makie.distinct_extrema_nan(first.(transformed_lookup_values))
ylims = Makie.distinct_extrema_nan(last.(transformed_lookup_values))

xscale = 1 / (xlims[2] - xlims[1])# * resolution[1]
yscale = 1 / (ylims[2] - ylims[1])# * resolution[2]


xvals = X(LinRange(xlims[1], xlims[2], resolution[1]))
yvals = Y(LinRange(ylims[1], ylims[2], resolution[2]))

points = @d inv(transf; always_xy = true).(xvals, yvals)

rescaled_position_map = map(points) do p
    x, y = p
    x = if -180 <= x <= 180
        x * 0.99
    else
        180 * sign(x)
    end
    y = if -90 <= y <= 90
        y * 0.99
    else
        90 * sign(y)
    end

    return ((x, (-y)) .+ (180, 90)) ./ (360, 360) # rescale to (0, 1) space.
end


diff_ex = extrema(first, rescaled_position_map)
diff_ey = extrema(last, rescaled_position_map)


positions_diff_in_color = (x -> RGB(x[1], x[2], 0)).(rescaled_position_map |> rotl90)


using Base64, ImageIO, FileIO

iob = IOBuffer()
FileIO.save(FileIO.Stream{FileIO.format"PNG"}(iob), positions_diff_in_color)
positions_image_b64 = base64encode(take!(iob))

iob = IOBuffer()
FileIO.save(FileIO.Stream{FileIO.format"PNG"}(iob), earth_img)
earth_image_b64 = base64encode(take!(iob))


# save("positions_data.png", positions_diff_in_color)
# save("positions_data.png", fill(RGBf(0.7, 0.5, 0), axes(positions_diff_in_color)))
# save("earth_data.png", earth_img)

# <feImage          href="positions_data.png"         result="positions_diff"         />

svg_str = """
<svg
width="720"
height="360"
viewBox = "0 0 720 360"
xmlns="http://www.w3.org/2000/svg"
>

<defs>

    <filter id="imageWarp">
        <feImage          
        href="data:image/png;charset=utf-8;base64,$(positions_image_b64)"         
        result="positions_diff"         
        />

        <feDisplacementMap 
        in2="positions_diff" 
        in="SourceGraphic" 
        scale="720" 
        xChannelSelector="R" 
        yChannelSelector="G"
        />

    </filter>

</defs>


<image style="filter:url(#imageWarp)" href="data:image/png;charset=utf-8;base64,$(earth_image_b64)"/>

</svg>
"""


write("test.svg", svg_str)


# diagnostics

reconstructed_positions = map(DimIndices(positions_diff_in_color)) do (y_di, x_di)
    x_ind = val(x_di)
    y_ind = -val(y_di) + size(positions_diff_in_color, Y)

    C = positions_diff_in_color[y_di, x_di]
    xc = red(C)
    yc = green(C)
    
    xcoord, ycoord = (x_ind, y_ind) .+ ((xc, yc) .- 0.5) .* 0.99
end

ei_raw = Raster(earth_img, ( Y(size(earth_img, 1):-1:1), X(1:size(earth_img, 2))))
reconstructed_colors = map(reconstructed_positions) do p
    x, y = p
    return ei_raw[X(Near(x)), Y(Near(y))]
end

extrema(first, reconstructed_positions)
extrema(last, reconstructed_positions)

positions_in_color = (x -> RGB(x[1], x[2], 0)).(reconstructed_positions)


f, a, p = surface(
    first.(rescaled_positions), 
    last.(rescaled_positions), 
    zeros(size(rescaled_positions)); 
    color = earth_ras.data,
    shading = NoShading,
    axis = (; aspect = DataAspect(), title = "Rescaled"),
)

surface(f[1, 2],
    first.(reconstructed_positions), 
    last.(reconstructed_positions), 
    zeros(size(reconstructed_positions)); 
    color = earth_ras.data,
    shading = NoShading,
    axis = (; aspect = DataAspect(), title = "Reconstructed"),
)

meshimage(f[2, 1], earth_ras; axis = (; type = GeoAxis, dest = target_projection, title = "Meshimage + GeoAxis"))

f