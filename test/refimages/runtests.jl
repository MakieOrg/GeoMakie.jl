# runtests.jl -- the reference-image gallery: record every case, compare
# against the release tarball when one exists, and write the review page.
# Included by test/runtests.jl only when ReferenceTests is available.

using Test

@testset "record" begin
    include("record.jl")
    @test isdir(joinpath(RECORDED_DIR, BACKEND))
    @test all(name -> isfile(image_path(RECORDED_DIR, name)), first.(all_renders()))
end
include("compare.jl")
include("review.jl")
