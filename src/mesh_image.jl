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
    MakieCore.mixin_generic_plot_attributes()...
    MakieCore.mixin_colormap_attributes()...
end

# this inherits all conversions for `Image`,
# if no specialized conversion for `MeshImage` is found.
Makie.conversion_trait(::Type{<: MeshImage}) = Makie.ImageLike()
# There really is no difference between this and Image, 
# except the implementation under the hood.

# This is the recipe implementation.

function Makie.plot!(plot::MeshImage)
    # Initialize some Observables which will hold data.
    # For right now, they point to some undefined place in memory.
    points_observable = Observable{Vector{Point3d}}()
    faces_observable = Observable{Vector{Makie.GLTriangleFace}}()#=GeometryBasics.QuadFace{Int}=#
    uv_observable = Observable{Vector{Vec2f}}()

    # A sentinel so we can see if `npoints` changed.  If it did, we have to
    # recreate the mesh, which is slightly time-consuming.  If not, though,
    # then we only have to change the texture (image) which is cheaper.
    old_npoints = Ref(0)

    # Handle the transformation
    onany(plot, plot.converted[1], plot.converted[2], plot.transformation.transform_func, plot.npoints, plot.space, plot.z_level; update=true) do x_in, y_in, tfunc, npoints, space, z_level
        # If `npoints` changed, then re-construct the mesh.
        if npoints != old_npoints[]
            # We need a new StructArray to hold all the points.
            # TODO: resize the old structarray instead!
            points_observable.val = Vector{Point3d}(undef, first(npoints) * last(npoints))
            # This constructs an efficient triangulation of a rectangle (all images are rectangles).
            rect = GeometryBasics.Tesselation(Rect2f(0, 0, 1, 1), (first(npoints), last(npoints)))
            # This decomposes that Tesselation to actual triangles, with integer index values.
            faces_observable.val = GeometryBasics.decompose(Makie.GLTriangleFace, rect)
            # This holds the UVs for the mesh.  These are reversed, so that the image is plotted correctly.
            uv_observable.val = map(x -> Vec2f(x[1], 1f0 - x[2]), GeometryBasics.decompose_uv(rect))
        end

        # These are the ranges for the points.
        # `first` and `last` are used to get the number of points per side, if that's provided as a tuple.
        xs = LinRange(extrema(x_in)..., first(npoints))
        ys = LinRange(extrema(y_in)..., last(npoints))
        poval = points_observable.val
        # The array is in a grid, so we have to update them on a grid as well.
        for (linear_ind, cartesian_ind) in enumerate(CartesianIndices((npoints, npoints)))
            p = Point3d(xs[cartesian_ind[1]], ys[cartesian_ind[2]], z_level)
            poval[linear_ind] = Makie.to_ndim(
                Point3d, 
                Makie.apply_transform(
                    tfunc, 
                    p,
                    space
                ), 
                0.0
            )
        end
        # Finally, we notify the points observable that it has an update.
        notify(points_observable)
        # If the faces were updated, we notify those as well.
        if npoints != old_npoints[]
            notify(faces_observable)
            old_npoints[] = npoints
        end
    end

    # You may have noticed that nowhere above did we actually create a mesh.  
    # Let's remedy that now!
    final_mesh = lift(plot, points_observable, faces_observable, uv_observable; ignore_equal_values = true#=, priority = -100=#) do points, faces, uv
        return GeometryBasics.Mesh(
            GeometryBasics.meta(points; uv=uv), # each point gets a UV, they're interpolated on faces
            faces
        )
    end

    # Finally, we plot the mesh.
    mesh!(
        plot, 
        final_mesh; 
        color = plot.converted[3], # pass on the color directly
        MakieCore.colormap_attributes(plot)..., # pass on all colormap attributes
        shading = NoShading, #
        transformation = Transformation(
            plot.transformation;      # connect up the model matrix to the parent's model matrix
            transform_func = identity # do NOT connect the transform func, since we've already done that.  identity provides a custom transform func, while `nothing` signals that you don't care.
        )
    )
    # TODO: get a `:transformed` space out so we don't need this `transformation` hack
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
