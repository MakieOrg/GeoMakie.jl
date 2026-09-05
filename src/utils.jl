# # General utility functions

############################################################
#                                                          #
#              Tick and tick label utilities               #
#                                                          #
############################################################

"""
    geoformat_ticklabels(nums::Vector)

A simple formatter for geographic tick labels: append `°` to each value.
The axis' own default, `longitude_format` / `latitude_format`, adds hemisphere
suffixes instead (`110°W`, `45°N`).

This will check whether the ticklabel is an integer value (`round(num) == num`).
If so, label as an Int (1 instead of 1.0) which looks a lot cleaner.

## Example
```julia-repl
julia> geoformat_ticklabels([1.0, 1.1, 2.5, 25])
4-element Vector{String}:
 "1°"
 "1.1°"
 "2.5°"
 "25°"
```
"""
function geoformat_ticklabels(nums)
    labels = fill("", length(nums))
    for i in 1:length(nums)
        labels[i] = if round(nums[i]) == nums[i]
            string(Int(nums[i]), '°')
        else
            string(nums[i], '°')
        end
    end
    return labels
end

function _replace_if_automatic(typ::Type{T}, attribute::Symbol, auto) where T
    default_attr_vals = Makie.default_attribute_values(T, nothing)

    if to_value(get(default_attr_vals, attribute, automatic)) == automatic
        return auto
    else
        return to_value(default_attr_vals[attribute])
    end
end

# Project any point to coordinates in pixel space
function project_to_pixelspace(scene, point::Point{N, T}) where {N, T}
    @assert N ≤ 3
    return Point{N, T}(
        Makie.project(
            # obtain the camera of the Scene which will project to its screenspace
            camera(scene),
            # go from dataspace (transformation applied to inputspace) to pixelspace
            :data, :pixel,
            # apply the transform to go from inputspace to dataspace
            Makie.apply_transform(
                scene.transformation.transform_func[],
                point
            )
        )
    )
end

function project_to_pixelspace(scene, points::AbstractVector{Point{N, T}}) where {N, T}
    Point{N, T}.(
        Makie.project.(
            # obtain the camera of the Scene which will project to its screenspace
            Ref(Makie.camera(scene)),
            # go from dataspace (transformation applied to inputspace) to pixelspace
            Ref(:data), Ref(:pixel),
            # apply the transform to go from inputspace to dataspace
            Makie.apply_transform(
                scene.transformation.transform_func[],
                points
            )
        )
    )
end

function text_bbox(textstring::AbstractString, fontsize::Union{AbstractVector, Number}, font, fonts, align, rotation, justification, lineheight)
    glyph_collection = Makie.layout_text(
            textstring, fontsize,
            string(font), fonts, align, rotation, justification, lineheight,
            RGBAf(0,0,0,0), RGBAf(0,0,0,0), 0f0, 0f0
        )

    return Rect2f(Makie.boundingbox(glyph_collection, Point3f(0), Makie.to_rotation(rotation)))
end

function find_outvec(scene, tickcoord_in_inputspace, tickcoord_in_dataspace, Δs)
end

function rotmat(θ)
    return Mat{2, 2}(cos(θ), sin(θ), -sin(θ), cos(θ))
end
# Direction finder - find how to displace the tick so that it is out of the axis
function directional_pad(scene, limits, tickcoord_in_inputspace, ticklabel::AbstractString, tickpad, ticksize, tickfont, tickrotation; ds = 0.01)
    # Define shorthand functions for dev purposes - these can be removed before release
    tfunc = x -> Makie.apply_transform(scene.transformation.transform_func[], x)
    inv_tfunc = x -> Makie.apply_transform(Makie.inverse_transform(scene.transformation.transform_func[]), x)
    # convert tick coordinate to dataspace
    tickcoord_in_dataspace = tfunc(tickcoord_in_inputspace)
    # determine direction to go in order to stay inbounds.
    xdir = tickcoord_in_inputspace[1] < 0 ? +1 : -1
    ydir = tickcoord_in_inputspace[2] < 0 ? +1 : -1
    Δs = iszero(sum(tickpad)) ? Vec2f(0) : Vec2f(xdir, ydir) .* tickpad ./ (sum(tickpad)) * ds

    # find the x and y directions
    # multiply by the sign in order to have them going outwards at any point
    Σp = sign(sum(Δs)) * inv_tfunc(tickcoord_in_dataspace + Δs)
    # project back to pixel space
    pixel_Δx, pixel_Δy = project_to_pixelspace(scene, Σp) - project_to_pixelspace(scene, tickcoord_in_inputspace)
    # invert direction - the vectors were previously facing the inside,
    # now they will face outside .
    dx = -pixel_Δx
    dy = -pixel_Δy

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
    fonts = theme(scene, :fonts)
    extents = text_bbox(
        ticklabel, ticksize,
        tickfont, fonts, Vec2f(0), tickrotation,
        0.0, # Makie.to_value(Makie.theme(scene, :justification)),
        0.0, # Makie.to_value(Makie.theme(scene, :lineheight))
    )

    padding_vec = normal_vec .* (extents.widths/2) - tickpad

    # println("$ticklabel ($(tickpad)) $(rad2deg(θ)) ⟹ $(_sprinti(normal_vec)) ⟹ $(_sprinti(padding_vec)); $(_sprinti(extents.widths)), $(Σp)")


    return padding_vec
end

"""
    geom_to_bands(geom; height = 100_000, base = 0)::Tuple{Vector{Point3d}, Vector{Point3d}}

Reduce a geometry to a NaN-separated list of points, and
return a pair of vectors of points in the same CRS - 
one with z coordinate `base`, and one at z coordinate
`base +height`.

Returns a tuple of `(lower_band, upper_band)`.

This can be directly splatted into Makie's `band!` recipe,
which will create a 3D band.  Especially useful in [`GlobeAxis`](@ref).


Accepts any GeoInterface-compatible geometry that is composed of curves
(linestrings or linear rings) or a higher level structure composed of such.

So any Polygon, MultiPolygon, LineString, MultiLineString, etc., but also
a vector of those, a table (from Tables.jl), or a feature collection.

## Example
```julia-repl
julia> lb, ub = geom_to_bands(california, 50_000)
julia> band(lb, ub; color = :red)
```
"""
function geom_to_bands(geom; height = 100_000.0, base = 0.0, kwargs...)
    geom_lower = GO.applyreduce(vcat, GO.TraitTarget(GI.AbstractCurveTrait), geom; init = (NaN, NaN, NaN), kwargs...) do geom
        points = GO.forcexyz(geom, base).geom
        push!(points, (NaN, NaN, NaN))
        return points
    end
    geom_upper = map(geom_lower) do point
        if isnan(point[3])
            point
        else
            (point[1], point[2], point[3] + height)
        end
    end
    return (Makie.Point3d.(geom_lower), Makie.Point3d.(geom_upper))
end