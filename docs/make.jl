using Documenter, DocumenterVitepress, Literate, OhMyCards
using GeoMakie, CairoMakie, Makie, GeoInterfaceMakie

# some strategic imports to avoid world age issues
using FHist

@eval CairoMakie begin
    
function project_line_points(scene, plot::T, positions::AbstractArray{<: Makie.VecTypes{N, FT}}, colors, linewidths) where {T <: Union{Lines, LineSegments}, N, FT <: Real}
    # If colors are defined per point they need to be interpolated like positions
    # at clip planes
    per_point_colors = colors isa AbstractArray
    per_point_linewidths = (T <: Lines) && (linewidths isa AbstractArray)

    space = (plot.space[])::Symbol
    model = (plot.model[])::Mat4d
    # Standard transform from input space to clip space
    points = Makie.apply_transform(transform_func(plot), positions, space)::Vector{Point{N, FT}}
    f32convert = Makie.f32_convert_matrix(scene.float32convert, space)
    transform = Makie.space_to_clip(scene.camera, space) * model * f32convert
    clip_points = map(points) do point
        return transform * to_ndim(Vec4d, to_ndim(Vec3d, point, 0), 1)
    end

    # yflip and clip -> screen/pixel coords
    res = scene.camera.resolution[]

    # clip planes in clip space
    clip_planes = if Makie.is_data_space(space)
        Makie.to_clip_space(scene.camera.projectionview[], plot.clip_planes[])::Vector{Plane3f}
    else
        Makie.Plane3f[]
    end

    # Fix lines with points far outside the clipped region not drawing at all
    # TODO this can probably be done more efficiently by checking -1 ≤ x, y ≤ 1
    #      directly and calculating intersections directly (1D)
    push!(clip_planes,
        Plane3f(Vec3f(-1, 0, 0), -1f0), Plane3f(Vec3f(+1, 0, 0), -1f0),
        Plane3f(Vec3f(0, -1, 0), -1f0), Plane3f(Vec3f(0, +1, 0), -1f0)
    )


    # outputs
    screen_points = sizehint!(Vec2f[], length(clip_points))
    color_output = sizehint!(eltype(colors)[], length(clip_points))
    skipped_color = RGBAf(1,0,1,1) # for debug purposes, should not show
    linewidth_output = sizehint!(eltype(linewidths)[], length(clip_points))

    # Handling one segment per iteration
    if plot isa Lines

        last_is_nan = true
        for i in 1:length(clip_points)-1
            hidden = false
            disconnect1 = false
            disconnect2 = false

            if per_point_colors
                c1 = colors[i]
                c2 = colors[i+1]
            end

            p1 = clip_points[i]
            p2 = clip_points[i+1]
            v = p2 - p1

            # Handle near/far clipping
            if p1[4] <= 0.0
                disconnect1 = true
                p1 = p1 + (-p1[4] - p1[3]) / (v[3] + v[4]) * v
                if per_point_colors
                    c1 = c1 + (-p1[4] - p1[3]) / (v[3] + v[4]) * (c2 - c1)
                end
            end
            if p2[4] <= 0.0
                disconnect2 = true
                p2 = p2 + (-p2[4] - p2[3]) / (v[3] + v[4]) * v
                if per_point_colors
                    c2 = c2 + (-p2[4] - p2[3]) / (v[3] + v[4]) * (c2 - c1)
                end
            end

            for plane in clip_planes
                d1 = dot(plane.normal, Vec3f(p1)) - plane.distance * p1[4]
                d2 = dot(plane.normal, Vec3f(p2)) - plane.distance * p2[4]

                if (d1 < 0.0) && (d2 < 0.0)
                    # start and end clipped by one plane -> not visible
                    hidden = true
                    break;
                elseif (d1 < 0.0)
                    # p1 clipped, move it towards p2 until unclipped
                    disconnect1 = true
                    p1 = p1 - d1 * (p2 - p1) / (d2 - d1)
                    if per_point_colors
                        c1 = c1 - d1 * (c2 - c1) / (d2 - d1)
                    end
                elseif (d2 < 0.0)
                    # p2 clipped, move it towards p1 until unclipped
                    disconnect2 = true
                    p2 = p2 - d2 * (p1 - p2) / (d1 - d2)
                    if per_point_colors
                        c2 = c2 - d2 * (c1 - c2) / (d1 - d2)
                    end
                end
            end

            if hidden && !last_is_nan
                # if segment hidden make sure the line separates
                last_is_nan = true
                push!(screen_points, Vec2f(NaN))
                if per_point_linewidths
                    push!(linewidth_output, linewidths[i])
                end
                if per_point_colors
                    push!(color_output, c1)
                end
            elseif !hidden
                # if not hidden, always push the first element to 1:end-1 line points

                # if the start of the segment is disconnected (moved), make sure the
                # line separates before it
                if disconnect1 && !last_is_nan
                    push!(screen_points, Vec2f(NaN))
                    if per_point_linewidths
                        push!(linewidth_output, linewidths[i])
                    end
                    if per_point_colors
                        push!(color_output, c1)
                    end
                end

                last_is_nan = false
                push!(screen_points, clip2screen(p1, res))
                if per_point_linewidths
                    push!(linewidth_output, linewidths[i])
                end
                if per_point_colors
                    push!(color_output, c1)
                end

                # if the end of the segment is disconnected (moved), add the adjusted
                # point and separate it from from the next segment
                if disconnect2
                    last_is_nan = true
                    push!(screen_points, clip2screen(p2, res), Vec2f(NaN))
                    if per_point_linewidths
                        push!(linewidth_output, linewidths[i+1], linewidths[i+1])
                    end
                    if per_point_colors
                        push!(color_output, c2, c2) # relevant, irrelevant
                    end
                end
            end
        end

        # If last_is_nan == true, the last segment is either hidden or the moved
        # end point has been added. If it is false we're missing the last regular
        # clip_points
        if !last_is_nan
            push!(screen_points, clip2screen(clip_points[end], res))
            if per_point_linewidths
                    push!(linewidth_output, linewidths[end])
            end
            if per_point_colors
                push!(color_output, colors[end])
            end
        end

    else  # LineSegments

        for i in 1:2:length(clip_points)-1
            if per_point_colors
                c1 = colors[i]
                c2 = colors[i+1]
            end

            p1 = clip_points[i]
            p2 = clip_points[i+1]
            v = p2 - p1

            # Handle near/far clipping
            if p1[4] <= 0.0
                p1 = p1 + (-p1[4] - p1[3]) / (v[3] + v[4]) * v
                if per_point_colors
                    c1 = c1 + (-p1[4] - p1[3]) / (v[3] + v[4]) * (c2 - c1)
                end
            end
            if p2[4] <= 0.0
                p2 = p2 + (-p2[4] - p2[3]) / (v[3] + v[4]) * v
                if per_point_colors
                    c2 = c2 + (-p2[4] - p2[3]) / (v[3] + v[4]) * (c2 - c1)
                end
            end

            for plane in clip_planes
                d1 = dot(plane.normal, Vec3f(p1)) - plane.distance * p1[4]
                d2 = dot(plane.normal, Vec3f(p2)) - plane.distance * p2[4]

                if (d1 < 0.0) && (d2 < 0.0)
                    # start and end clipped by one plane -> not visible
                    # to keep index order we just set p1 and p2 to NaN and insert anyway
                    p1 = Vec4f(NaN)
                    p2 = Vec4f(NaN)
                    break;
                elseif (d1 < 0.0)
                    # p1 clipped, move it towards p2 until unclipped
                    p1 = p1 - d1 * (p2 - p1) / (d2 - d1)
                    if per_point_colors
                        c1 = c1 - d1 * (c2 - c1) / (d2 - d1)
                    end
                elseif (d2 < 0.0)
                    # p2 clipped, move it towards p1 until unclipped
                    p2 = p2 - d2 * (p1 - p2) / (d1 - d2)
                    if per_point_colors
                        c2 = c2 - d2 * (c1 - c2) / (d1 - d2)
                    end
                end
            end

            # no need to disconnected segments, just insert adjusted points
            push!(screen_points, clip2screen(p1, res), clip2screen(p2, res))
            if per_point_colors
                push!(color_output, c1, c2)
            end
        end

    end

    return screen_points, ifelse(per_point_colors, color_output, colors),
        ifelse(per_point_linewidths, linewidth_output, linewidths)
end

end

# Set some global settings
# Good quality CairoMakie with PNG
CairoMakie.activate!(px_per_unit = 2, type = :png)
# Rasters should download into the artifacts folder (so they can be cached :D)
raster_data_sources_path = joinpath(first(Base.DEPOT_PATH), "artifacts")
if haskey(ENV, "CI")
    # override the given setting so we don't run into path not created problems.
    ENV["RASTERDATASOURCES_PATH"] = raster_data_sources_path
else
    # on local machine, so respect the given setting if it exists.
    get!(ENV, "RASTERDATASOURCES_PATH", raster_data_sources_path)
end
# invoke some geomakie things to be sure it works
GeoMakie.coastlines()
GeoMakie.earth()

using Literate

examples = String[
    "basic.jl",
    "new.jl",
    "axis_config.jl",
    "italy.jl",
    "histogram.jl",
    "contours.jl",
    "world_population.jl",
    "graph_on_usa.jl",
    "orthographic.jl",
    # "geostationary_image.jl",
    # "multiple_crs.jl",
    "rasters.jl",
    "raster_warping_masking.jl",
    "healpix.jl",
    # "is_it_a_plane.jl",
    joinpath("cartopy", "annotation.jl"),
    joinpath("cartopy", "katrina.jl"),
    joinpath("cartopy", "arrows.jl"),
    # # joinpath("cartopy", "vesta.jl"),
    joinpath("cartopy", "streamplot.jl"),
    joinpath("gmt", "antioquia.jl"),
    "german_lakes.jl",
    "field_and_countries.jl",
    "meshimage.jl",
    # "projections.jl",
    "tissot.jl",
    # "rotating_earth.jl",
]
example_dir = joinpath(dirname(@__DIR__), "examples")
mkpath(example_dir)
for filename in examples
    file = joinpath(example_dir, filename)
    endswith(file, ".jl") || continue
    Literate.markdown(file, joinpath(@__DIR__, "src", "examples", first(splitdir(filename))); documenter = true)
end

Documenter.makedocs(;
    modules=[GeoMakie],
    doctest=false,
    format=DocumenterVitepress.MarkdownVitepress(; 
        repo = "https://github.com/MakieOrg/GeoMakie.jl", 
        deploy_url = "https://geo.makie.org",
        devbranch = "master",
        devurl = "dev",
    ),
    pages=[
        "Introduction" => "introduction.md",
        "Gallery" => "examples.md",
        "Data" => "data.md",
        "Developer documentation" => [
            "Nonlinear transforms" => "nonlinear_transforms.md",
            "Architecture" => "architecture.md",
            "Adding demos" => "adding_demos.md",
        ],
        "Examples" => joinpath.(("examples",), replace.(examples, (".jl" => ".md",))),
    ],
    sitename="GeoMakie.jl",
    authors="Anshul Singhvi and the Makie.jl contributors",
    warnonly = true,
    draft = false,
    plugins = [OhMyCards.ExampleConfig(),],
)

deploydocs(; 
    repo="github.com/MakieOrg/GeoMakie.jl", 
    target="build", 
    push_preview = true, 
    forcepush = true
)
