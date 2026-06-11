#=
# MeshImage

This file contains the implementation of the `MeshImage` recipe.
=#

using Makie: GeometryBasics

"""
    meshimage([xs, ys,] img)
    meshimage!(ax, [xs, ys,] img)

Plots an image on a mesh.

Useful for nonlinear transforms where a large
image would take too long to transform usefully,
but a smaller mesh can still represent the inherent
nonlinearity of the space.

This basically plots a mesh with uv coordinates, and textures it by
the provided image.  Its conversion trait is `ImageLike`.

!!! tip
    You can control the density of the mesh by the `npoints` attribute.

"""
@recipe MeshImage (x, y, img) begin
    """
    The number of points the mesh should have per side.  
    Can be an Integer or a 2-tuple of integers representing number of points per side.
    """
    npoints = 100
    "The z-coordinate given to each mesh point.  Useful in 3D transformations."
    z_level = 0.0
    "Sets the lighting algorithm used. Options are `NoShading` (no lighting), `FastShading` (AmbientLight + PointLight) or `MultiLightShading` (Multiple lights, GLMakie only). Note that this does not affect RPRMakie."
    shading = NoShading
    """
    Sets a transform for uv coordinates, which controls how the image is mapped to its rectangular area. The attribute can be `I`,
    `scale::VecTypes{2}`, `(translation::VecTypes{2}, scale::VecTypes{2})`, any of `:rotr90`, `:rotl90`, `:rot180`, `:swapxy`/`:transpose`, `:flip_x`, `:flip_y`, `:flip_xy`, or
    most generally a `Makie.Mat{2, 3, Float32}` or `Makie.Mat3f` as returned by `Makie.uv_transform()`. They can also be changed by passing a tuple `(op3, op2,
    op1)`.
    """
    uv_transform = Makie.LinearAlgebra.I
    mixin_generic_plot_attributes()...
    mixin_colormap_attributes()...
end

# this inherits all conversions for `Image`,
# if no specialized conversion for `MeshImage` is found.
Makie.conversion_trait(::Type{<: MeshImage}) = Makie.ImageLike()
# There really is no difference between this and Image, 
# except the implementation under the hood.

# We also define that `meshimage` needs tight limits when plotted...
Makie.needs_tight_limits(::MeshImage) = true

# This is the recipe implementation.

# Great-circle midpoint of a lon/lat edge (degrees).
function _gc_midpoint(lo1, la1, lo2, la2)
    x1 = cosd(la1) * cosd(lo1); y1 = cosd(la1) * sind(lo1); z1 = sind(la1)
    x2 = cosd(la2) * cosd(lo2); y2 = cosd(la2) * sind(lo2); z2 = sind(la2)
    mx = x1 + x2; my = y1 + y2; mz = z1 + z2; n = sqrt(mx^2 + my^2 + mz^2)
    n < 1.0e-12 && return ((lo1 + lo2) / 2, (la1 + la2) / 2)
    return (atand(my, mx), asind(clamp(mz / n, -1.0, 1.0)))
end

# Drop mesh faces that straddle the projection's discontinuity. Edge LENGTH alone can't tell a
# real tear from heavy projection distortion, so we test each edge for a DISCONTINUITY: project
# the edge's great-circle midpoint and compare it to the midpoint of the two projected
# endpoints. A continuous (even badly distorted) edge keeps the two close; a tear
# (antimeridian / horizon / interrupted lobe / oblique seam) makes them jump apart. `latlon`
# is the per-vertex lon/lat parallel to the projected `points`. No-op under an identity
# transform except for genuine antimeridian wrap-around.
function _visible_faces(points, latlon, faces, tfunc, z; factor = 0.3)
    isempty(faces) && return faces
    _fin(p) = isfinite(p[1]) && isfinite(p[2])
    function proj(lo, la)
        try
            p = Makie.apply_transform(tfunc, Point3d(lo, la, z))
            return (Float64(p[1]), Float64(p[2]))
        catch
            return (NaN, NaN)
        end
    end
    function crosses(i1, i2)
        p1 = points[i1]; p2 = points[i2]
        (_fin(p1) && _fin(p2)) || return true
        l1 = latlon[i1]; l2 = latlon[i2]
        m = _gc_midpoint(l1[1], l1[2], l2[1], l2[2])
        pm = proj(m[1], m[2])
        _fin(pm) || return true
        ex = (p1[1] + p2[1]) / 2; ey = (p1[2] + p2[2]) / 2
        el = hypot(p1[1] - p2[1], p1[2] - p2[2])
        return hypot(pm[1] - ex, pm[2] - ey) > factor * el + 1.0e-9
    end
    keep = eltype(faces)[]
    @inbounds for f in faces
        (crosses(f[1], f[2]) || crosses(f[2], f[3]) || crosses(f[3], f[1])) || push!(keep, f)
    end
    return keep
end

function Makie.plot!(plot::MeshImage)
    # Initialize some Ref's that can hold references
    # to pre-defined arrays.
    points_buffer = Ref{Vector{Point3d}}(Point3d[])
    faces_buffer = Ref{Vector{Makie.GLTriangleFace}}(Makie.GLTriangleFace[])#=GeometryBasics.QuadFace{Int}=#
    uv_buffer = Ref{Vector{Vec2f}}(Vec2f[])

    # A sentinel so we can see if `npoints` changed.  If it did, we have to
    # recreate the mesh, which is slightly time-consuming.  If not, though,
    # then we only have to change the texture (image) which is cheaper.
    old_npoints = Ref{Tuple{Int, Int}}((0, 0))

    Makie.map!(
        plot,
        [:x, :y, :transform_func, :npoints, :space, :z_level],
        [:mesh]
    ) do x_in, y_in, tfunc, npoints, space, z_level
        # If `npoints` changed, then re-construct the buffers.
        if (first(npoints), last(npoints)) != old_npoints[]
            # We need a new StructArray to hold all the points.
            # TODO: resize the old structarray instead!
            points_buffer[] = Vector{Point3d}(undef, first(npoints) * last(npoints))
            # This constructs an efficient triangulation of a rectangle (all images are rectangles).
            rect = GeometryBasics.Tesselation(Rect2f(0, 0, 1, 1), (first(npoints), last(npoints)))
            faces_buffer[] = GeometryBasics.decompose(Makie.GLTriangleFace, rect)
            uv_buffer[] = map(x -> Vec2f(x[1], 1f0 - x[2]), GeometryBasics.decompose_uv(rect))
            old_npoints[] = (first(npoints), last(npoints))
        end
        nx, ny = old_npoints[]

        # These are the ranges for the points.
        # `first` and `last` are used to get the number of points per side, if that's provided as a tuple.
        xs = LinRange(extrema(x_in)..., nx)
        ys = LinRange(extrema(y_in)..., ny)

        points = points_buffer[]
        faces = faces_buffer[]
        uvs = uv_buffer[]

        latlon = Vector{Point2d}(undef, nx * ny)   # lon/lat parallel to `points`, for the tear test
        for (linear_ind, cartesian_ind) in enumerate(CartesianIndices((nx, ny)))
            lo = xs[cartesian_ind[1]]; la = ys[cartesian_ind[2]]
            latlon[linear_ind] = Point2d(lo, la)
            points[linear_ind] = Makie.to_ndim(
                Point3d,
                Makie.apply_transform(
                    tfunc,
                    Point3d(lo, la, z_level),
                ),
                0.0
            )
        end

        return (GeometryBasics.Mesh(
                points,
                # drop faces straddling the projection discontinuity
                _visible_faces(points, latlon, faces, tfunc, z_level);
                uv = uvs, # each point gets a UV, they're interpolated on faces
            ),)
    end

    # Finally, we plot the mesh.
    # This auto forwards all shared attributes from the compute graph.
    mesh!(
        plot, 
        plot.attributes,
        plot.mesh; 
        color = plot.img, # pass on the color directly
        transformation = Makie.Transformation(
            plot.transformation;      # connect up the model matrix to the parent's model matrix
            transform_func = identity # do NOT connect the transform func, since we've already done that.  identity provides a custom transform func, while `nothing` signals that you don't care.
        ),
    )
end

# This is an efficient implementation for data_limits,
# so that we don't have to iterate through each point of the mesh!
function Makie.data_limits(plot::MeshImage)
    mini_maxi = Makie.extrema_nan.((plot[1][], plot[2][]))
    mini = Vec3f(first.(mini_maxi)..., 0)
    maxi = Vec3f(last.(mini_maxi)..., 0)
    return Rect3f(mini, maxi .- mini)
end
# Boundingbox needs to iterate though, so it's fine to not override that.
