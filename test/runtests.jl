using GeoMakie, MakieGallery, MakieLayout, GLMakie, Test

const OPENGL = GLMakie.WORKING_OPENGL

@show OPENGL

OPENGL && begin @info "OpenGL detected"; using GLMakie; end
OPENGL || begin @warn "No OpenGL detected!  Using CairoMakie instead."; using CairoMakie; CairoMakie.activate!(); end

# Download reference images from master
MakieGallery.current_ref_version[] = "master"

# Load only the GeoMakie examples
MakieGallery.load_database(["geomakie.jl"]);

filter!(MakieGallery.database) do entry
    !(entry.title ∈ ("Air particulates",))
end

tested_diff_path = joinpath(@__DIR__, "tested_different")
test_record_path = joinpath(@__DIR__, "test_recordings")

isdir(tested_diff_path) && rm(tested_diff_path; force = true, recursive = true)
mkpath(tested_diff_path)

isdir(test_record_path) && rm(test_record_path; force = true, recursive = true)
mkpath(test_record_path)

examples = MakieGallery.record_examples(test_record_path)

@test length(examples) == length(database)

# MakieGallery.generate_preview(test_record_path, joinpath(homedir(), "Desktop", "index.html"))
# MakieGallery.generate_thumbnails(test_record_path)
# MakieGallery.gallery_from_recordings(test_record_path, joinpath(test_record_path, "index.html"))

printstyled("Running ", color = :green, bold = true)
println("visual regression tests")

MakieGallery.run_comparison(test_record_path, tested_diff_path)
