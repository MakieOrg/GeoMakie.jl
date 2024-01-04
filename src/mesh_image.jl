using Makie: GeometryBasics

"""
    meshimage([xs, ys,] zs)
    meshimage!(ax, [xs, ys,] zs)

Plots an image on a mesh.

Useful for nonlinear transforms where a large
image would take too long to transform usefully,
but a smaller mesh can still represent the inherent
nonlinearity of the space.

This basically plots a mesh with uv coordinates, and textures it by
the provided image.  Its conversion trait is `Image` (TODO: change this to DiscreteSurfaceLike).

For now, it only accepts RGB images.  This could be changed in the future.

## Attributes
$(Makie.ATTRIBUTES)
"""
@recipe(MeshImage) do scene
    Attributes(
        npoints = 100,
        space = :data,
    )
end

# this inherits all conversions for `Image`,
# if no specialized conversion for `MeshImage` is found
Makie.conversion_trait(::Type{<: MeshImage}) = Image

# This is the recipe implementation.

function Makie.plot!(plot::MeshImage)
    # Initialize some Observables which will hold data.
    # For right now, they point to some undefined place in memory.
    points_observable = Observable{Vector{Point2f}}()
    faces_observable = Observable{Vector{Makie.GLTriangleFace}}()#=GeometryBasics.QuadFace{Int}=#
    uv_observable = Observable{Vector{Vec2f}}()

    # A sentinel so we can see if `npoints` changed.  If it did, we have to
    # recreate the mesh, which is slightly time-consuming.  If not, though,
    # then we only have to change the texture (image) which is cheaper.
    old_npoints = Ref(0)

    # Handle the transformation
    onany(plot, plot[1], plot[2], plot.transformation.transform_func, plot.npoints, plot.space; update=true) do x_in, y_in, tfunc, npoints, space
        # If `npoints` changed, then re-construct the mesh.
        if npoints != old_npoints[]
            # We need a new StructArray to hold all the points.
            # TODO: resize the old structarray instead!
            points_observable.val = Vector{Point2f}(undef, npoints^2)
            # This constructs an efficient triangulation of a rectangle (all images are rectangles).
            rect = GeometryBasics.Tesselation(Rect2f(0, 0, 1, 1), (npoints, npoints))
            # This decomposes that Tesselation to actual triangles, with integer index values.
            faces_observable.val = GeometryBasics.decompose(Makie.GLTriangleFace, rect)
            # This holds the UVs for the mesh.  These are reversed, so that the image is plotted correctly.
            uv_observable.val = map(x -> Vec2f(x[1], 1f0 - x[2]), GeometryBasics.decompose_uv(rect))
        end

        # These are the ranges for the points.
        xs = LinRange(extrema(x_in)..., npoints)
        ys = LinRange(extrema(y_in)..., npoints)
        poval = points_observable[]
        # The array is in a grid, so we have to update them on a grid as well.
        for (linear_ind, cartesian_ind) in enumerate(CartesianIndices((npoints, npoints)))
            p = Point2f(xs[cartesian_ind[1]], ys[cartesian_ind[2]])
            poval[linear_ind] = Makie.apply_transform(tfunc, p, space)
        end
        # Finally, we notify the points observable that it has an update.
        notify(points_observable)
        # If the faces were updated, we notify those as well.
        if npoints != old_npoints[]
            notify(faces_observable)
            old_npoints[] = npoints
        end
    end

    # TODO: figure out how to mutate a mesh's points in place

    # You may have noticed that nowhere above did we actually create a mesh.  Let's remedy that now!
    final_mesh = lift(points_observable, faces_observable, uv_observable; ignore_equal_values = true#=, priority = -100=#) do points, faces, uv
        return GeometryBasics.Mesh(
            GeometryBasics.meta(points; uv=uv), # each point gets a UV, they're interpolated on faces
            faces
        )
    end

    # Finally, we plot the mesh.
    mesh!(plot, final_mesh; color = plot[3], transformation = Transformation(), shading = NoShading)
end

# This is an efficient implementation for data_limits,
# so that we don't have to iterate through each point of the mesh!
function Makie.data_limits(plot::MeshImage)
    mini_maxi = Makie.extrema_nan.((plot[1][], plot[2][]))
    mini = Vec3f(first.(mini_maxi)..., 0)
    maxi = Vec3f(last.(mini_maxi)..., 0)
    return Rect3f(mini, maxi .- mini)
end
