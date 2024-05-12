#=
# Projection

This file contains the code that defines the integration between Makie and Proj
for transformations.

=#
############################################################
#                                                          #
#         Proj.Transform as a Makie transformation         #
#                                                          #
############################################################

#= 

This function is a little gnarly.
In Makie, we use NaN as a blank point, i.e. any line
ends at NaN and restarts at the next point.  However, 
if NaN goes somewhere in ℝ² in the projection, this 
utility is lost and the plot will have a bunch of lines
going to transformation(Point2f(NaN)). In order to avoid 
this, we check first if the point is NaN, if so we return NaN. 

Then, and only then, do we transform it.

This does not seem to effect times too adversely, but can be 
removed if necessary.

=#

function Makie.apply_transform(t::Proj.Transformation, pt::V) where V <: VecTypes{N,T} where {N,T}
    if all(isnan.(pt))
        return V(NaN)
    end
    # this is to catch errors - show the point which was invalid
    # and then catch it.
    try
        return V(t(Vec(pt)))
    catch e
        # catch this annoying edge case
        # if pt[2] ≈ 90.0f0 || pt[2] ≈ -90.0f0
        #     println("Caught a 90° latitude")
        #     return Point(t(Vec(pt[1], 90.0f0)) ./ PROJ_RESCALE_FACTOR)
        # end
        return V(NaN)
    end
end

# Converting rectangles requires densifying the edges.
function Makie.apply_transform(f::Proj.Transformation, r::Rect2{T}) where {T}
    xmin, ymin = minimum(r)
    xmax, ymax = maximum(r)

    if isapprox(xmin, -180, rtol = 1e-4)
        xmin - -180e0
    end
    if isapprox(xmax, 180; rtol = 1e-4)
        xmax = 180e0
    end
    if isapprox(ymin, -90; rtol = 1e-4)
        ymin = -90e0
    end
    if isapprox(ymax, 90; rtol = 1e-4)
        ymax = 90e0
    end

    try
        (umin, umax), (vmin, vmax) = Proj.bounds(f, (xmin,xmax), (ymin,ymax))
        return Rect(Vec2(T(umin), T(vmin)), Vec2(T(umax-umin), T(vmax-vmin)))
    catch e
        @show r
        rethrow(e)
    end
end

function Makie.apply_transform(f::Proj.Transformation, r::Rect3{T}) where {T}
    r2 = Rect2{T}(r)
    tr2 = Makie.apply_transform(f, r2)
    return Rect3{T}((tr2.origin..., r.origin[3]), (tr2.widths..., r.widths[3]))
end

# The inverse transformation is pretty simple, but the 
# coordinate order has to be maintained!
function Makie.inverse_transform(trans::Proj.Transformation)
    return Base.inv(trans; always_xy = true)
end

# Some minor type piracy

function (transformation::Proj.Transformation)(coord::Point{N, T}) where {N, T <: Real}
    @assert 2 ≤ N ≤ 4
    return Point{N, T}(transformation(coord.data))
end

function (transformation::Proj.Transformation)(coord::Vec{N, T}) where {N, T <: Real}
    @assert 2 ≤ N ≤ 4
    return Vec{N, T}(transformation(coord.data))
end



############################################################
#                   Creating transforms                    #
############################################################


"""
    create_transform(dest, source)

Creates a transformation going from `source` to `dest` with the 
axis order set to `XYZ`.  This can take in Strings, GFT objects, or Observables,
and the output type mirrors the input type - either a Transformation or an 
Observable{Transformation}.
"""
function create_transform(dest::String, source::String)
    return Proj.Transformation(source, dest; always_xy=true)
end

function create_transform(dest::Observable, source::Observable)
    result = Observable{Any}()
    return map!(create_transform, result, dest, source)
end

########################################
#      GeoFormatTypes integration      #
########################################

# Define methods for GeoFormatTypes CRS objects and all possible combinations thereof.
create_transform(dest::GeoFormatTypes.CoordinateReferenceSystemFormat, source::GeoFormatTypes.CoordinateReferenceSystemFormat) = create_transform(gft2str(dest), gft2str(source))
create_transform(dest::String, source::GeoFormatTypes.CoordinateReferenceSystemFormat) = create_transform(dest, gft2str(source))
create_transform(dest::GeoFormatTypes.CoordinateReferenceSystemFormat, source::String) = create_transform(gft2str(dest), source)

"""
    gft2str(crs)::String

Return a PROJ-compatible string from a GeoFormatTypes CRS object.
"""
function gft2str end
gft2str(crs::GeoFormatTypes.EPSG{1}) = String("EPSG:$(GeoFormatTypes.val(crs))")
GeoFormatTypes2str(crs::GeoFormatTypes.CoordinateReferenceSystemFormat) = string(GeoFormatTypes.val(crs))
