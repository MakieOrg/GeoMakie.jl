using Makie: GeometryBasics
using Makie.GeometryBasics: StructArrays

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

# These are some efficient methods to transform structarrays in-place,
# so that the transform is as efficient as possible!
function apply_transform!(f, structarray::StructArrays.StructArray{<: VecTypes{N}}, space = :data) where N
    backing_arrays = getproperty.((structarray,), 1:N)
    for i in 1:length(structarray)
        transformed_point = Makie.apply_transform(f, structarray[i], :data)
        for j in 1:N
            backing_arrays[j][i] = transformed_point[j]
        end
    end
    return structarray
end

function apply_transform!(fs::Tuple{<: Function, <: Function}, structarray::StructArrays.StructArray{<: VecTypes{N}}, space = :data) where N
    backing_arrays = getproperty.((structarray,), 1:N)
    backing_arrays[1][:] .= (fs[1]).(backing_arrays[1])
    backing_arrays[2][:] .= (fs[2]).(backing_arrays[2])
    return structarray
end

# This is the recipe implementation.

function Makie.plot!(plot::MeshImage)
    # Initialize some Observables which will hold data.
    # For right now, they point to some undefined place in memory.
    points_observable = Observable{StructArrays.StructArray{Point2{Float64}, 1}}()
    faces_observable = Observable{Vector{Makie.GLTriangleFace}}()#=GeometryBasics.QuadFace{Int}=#
    uv_observable = Observable{Vector{Vec2f}}()
    
    ## lift(plot.npoints; ignore_equal_values = true, priority = 100) do npoints
    ##      # could try GLTriangleFace, but that might not turn out well
    ##     uv = map(x-> Vec2f(1f0 - x[2], 1f0 - x[1]), decompose_uv(rect))
    ##     uvm = GeometryBasics.Mesh(GeometryBasics.meta(ps; uv=uv), faces)
    ##     return GeometryBasics.normal_mesh(uvm)
    ## end
    
    # A sentinel so we can see if `npoints` changed.  If it did, we have to 
    # recreate the mesh, which is slightly time-consuming.  If not, though,
    # then we only have to change the texture (image) which is cheaper.
    old_npoints = typemin(Int)

    # Handle the transformation
    lift(plot[1], plot[2], plot.transformation.transform_func, plot.npoints, plot.space; ignore_equal_values = true) do x_in, y_in, tfunc, npoints, space
        # If `npoints` changed, then re-construct the mesh.
        if npoints != old_npoints
            # We need a new StructArray to hold all the points.
            # TODO: resize the old structarray instead!
            points_observable.val = StructArrays.StructArray{Point2{Float64}}(undef, npoints^2)
            # This constructs an efficient triangulation of a rectangle (all images are rectangles).
            rect = GeometryBasics.Tesselation(Rect2f(0, 0, 1, 1), (npoints, npoints))
            # This decomposes that Tesselation to actual triangles, with integer index values.
            faces_observable[] = GeometryBasics.decompose(
                Makie.GLTriangleFace,#GeometryBasics.QuadFace{Int}, 
                rect
            )
            # This holds the UVs for the mesh.  These are reversed, so that the image is plotted correctly.
            uv_observable[] = map(x-> Vec2f(1f0 - x[2], 1f0 - x[1]), GeometryBasics.decompose_uv(rect))
        end

        # These are the ranges for the points.
        xs = LinRange(extrema(x_in)..., npoints)
        ys = LinRange(extrema(y_in)..., npoints)
        # Since `points_observable` holds a StructArray, we can manipulate this directly,
        # and then notify `points_observable` that its inner value has been updated.

        # We are only getting away with this because it's known that no one else can access this observable.
        # This is not a good pattern to use on user provided things!!
        poval = points_observable.val
        # These are the component vectors.
        pox = getproperty(poval, 1)
        poy = getproperty(poval, 2)

        ## NOTE collect(tuple.(1:2, (1:2)'))[:] works fine
        # First, we update the values of the array to these new values.
        # The array is in a grid, so we have to update them on a grid as well.
        for (linear_ind, cartesian_ind) in enumerate(CartesianIndices((npoints, npoints)))
            pox[linear_ind] = xs[cartesian_ind[1]]
            poy[linear_ind] = ys[cartesian_ind[2]]
        end
        # Now, we apply the transformation to all points.

        # You can override `apply_transform!` to make it effective in certain cases,
        # e.g. if the transformation is known, 
        # OR is linearly separable,
        # OR has a convenient C-api to transform arrays in place.

        # Note that this is our `apply_transform!`, not `Makie.apply_transform` (no bang there).
        space === :data && apply_transform!(tfunc, poval, :data)

        # Finally, we notify the points observable that it has an update.
        notify(points_observable)
        # If the faces were updated, we notify those as well.
        if npoints != old_npoints
            notify(faces_observable)
            old_npoints = npoints
        end
    end

    # TODO: figure out how to mutate a mesh's points in place

    # You may have noticed that nowhere above did we actually create a mesh.  Let's remedy that now!
    final_mesh = lift(points_observable, faces_observable, uv_observable; ignore_equal_values = true#=, priority = -100=#) do points, faces, uv
        return GeometryBasics.normal_mesh(
            GeometryBasics.Mesh(
                GeometryBasics.meta(points; uv=uv), # each point gets a UV, they're interpolated on faces
                faces
            )
        )
    end

    # Finally, we plot the mesh.
    mesh!(plot, final_mesh; color = plot[3], space = :transformed, shading = false)

end

# This is an efficient implementation for data_limits,
# so that we don't have to iterate through each point of the mesh!
function Makie.data_limits(plot::MeshImage)
    mini_maxi = Makie.extrema_nan.((plot[1][], plot[2][]))
    mini = Vec3f(first.(mini_maxi)..., 0)
    maxi = Vec3f(last.(mini_maxi)..., 0)
    return Rect3f(mini, maxi .- mini)
end