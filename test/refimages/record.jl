# record.jl -- render every gallery case to test_images/refimages/recorded/CairoMakie/<name>.png.
#
# With Makie's ReferenceTests available the renders go through
# `@include_reference_tests` (px_per_unit = 1, seeded RNG, one testset per
# render); without it they are saved plainly at the same scale, so review.jl
# has pictures either way.

using Test
include("cases.jl")

function record_all()
    if Base.find_package("ReferenceTests") !== nothing
        record_with_referencetests()
    else
        record_plainly()
    end
    return RECORDED_DIR
end

function record_with_referencetests()
    @eval using ReferenceTests
    @eval using ReferenceTests: @reference_test
    # @include_reference_tests records under `dirname(@__FILE__)/reference_images`
    # and empties that folder first; the result is moved under test_images/
    theme = Makie.current_default_theme()
    attempted, staging = try
        @eval @include_reference_tests CairoMakie $(joinpath(@__DIR__, "reftests.jl"))
    finally
        Makie.set_theme!(theme)     # @reference_test replaces the theme
    end
    rm(RECORDED_DIR; recursive = true, force = true)
    mkpath(dirname(RECORDED_DIR))
    mv(joinpath(staging, "recorded"), RECORDED_DIR)
    rm(staging; recursive = true, force = true)
    println("recorded $(length(attempted)) renders under $RECORDED_DIR")
    return
end

function record_plainly()
    rm(RECORDED_DIR; recursive = true, force = true)
    mkpath(joinpath(RECORDED_DIR, BACKEND))
    for (name, render) in all_renders()
        path = image_path(RECORDED_DIR, name)
        try
            save(path, render(); px_per_unit = 1)
            println("recorded ", path)
        catch e
            @error "could not record $name" exception = (e, catch_backtrace())
        end
    end
    return
end

record_all()
