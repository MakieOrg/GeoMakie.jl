
using GeoMakie, Proj

using Rasters
using Rasters.DimensionalData.Lookups

import GeoInterface as GI, GeometryOps as GO, GeoFormatTypes as GFT

earth_img = GeoMakie.earth()
yaxis = LinRange(-90 + (180/size(earth_img, 1)), 90, size(earth_img, 1)) |> reverse
xaxis = LinRange(-180, 180 - (360 / size(earth_img, 2)), size(earth_img, 2))
earth_ras = Raster(earth_img, (Y(Projected((yaxis); sampling = Intervals(Start()), crs = EPSG(4326))), X(Projected((xaxis); sampling = Intervals(Start()), crs = EPSG(4326)))))


target_projection = ProjString("+proj=wintri +type=crs")

transf = Proj.Transformation(GI.crs(earth_ras), target_projection; always_xy = true)

original_lookup_values = DimPoints(dims(earth_ras); order = (X, Y))# .|> x -> shiftlocus(Center(), x))

transformed_lookup_values = transf.(original_lookup_values)

xlims = extrema(first, transformed_lookup_values)
ylims = extrema(last, transformed_lookup_values)

xscale = 1 / (xlims[2] - xlims[1])
yscale = 1 / (ylims[2] - ylims[1])

resolution = length.(dims(earth_ras, (X, Y)))

xscale *= resolution[1] - 1
yscale *= resolution[2] - 1

rescale(value, xscale, yscale, xmin, ymin, xtrans, ytrans) = (value .- (xmin, ymin)) .* (xscale, yscale) .+ (xtrans, ytrans) 

rescaled_positions = rescale.(transformed_lookup_values, xscale, yscale, minimum(first, transformed_lookup_values), minimum(last, transformed_lookup_values), 1, 1)


diff_ex = extrema(first, rescaled_positions)
diff_ey = extrema(last, rescaled_positions)

scale_factor = max(diff_ex[2] - diff_ex[1], diff_ey[2] - diff_ey[1])

positions_diff = map(DimIndices(rescaled_positions)) do (y_di, x_di)
    x_ind = val(x_di)
    y_ind = val(y_di)

    x_pos, y_pos = rescaled_positions[y_di, x_di]
    y_pos = -y_pos + size(rescaled_positions, Y) # invert axis for SVG
    y_ind = -y_ind + size(rescaled_positions, Y)

    return ((x_pos, y_pos) .- (x_ind, y_ind)) ./ scale_factor .+ 0.5
end

extrema(first, positions_diff)
extrema(last, positions_diff)


positions_diff_in_color = (x -> RGB(x[1], x[2], 0)).(positions_diff)


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
        scale="$(scale_factor)" 
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
    y_ind = -val(y_di) + size(positions_diff, Y)

    C = positions_diff[y_di, x_di]
    xc = red(C)
    yc = green(C)
    return  (x_ind, y_ind) .+ ((xc, yc) .- 0.5) .* scale_factor
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