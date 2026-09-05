# compare.jl -- score the recorded gallery against the reference images with
# Makie's ReferenceTests (tiled max-mean pixel distance, threshold 0.05), and
# write scores.tsv, new_files.txt, missing_files.txt and a diff image per pair
# for review.jl.  When no reference tarball can be downloaded the comparison
# is skipped with a note, so a run without network or before the first
# release still records and reviews.

using ReferenceTests, Test
using GeoMakie.Makie: FileIO, Colors
using .Colors: RGB

include("download.jl")

const COMPARISON_THRESHOLD = 0.05

"The relative paths (`CairoMakie/<name>.png`) of every recorded image."
recorded_paths() = ReferenceTests.get_all_relative_filepaths_recursively(RECORDED_DIR)

"Write |a - b| per channel as an image beside the recorded one; blank when the sizes differ."
function write_diff(relpath)
    a = FileIO.load(joinpath(RECORDED_DIR, relpath)); b = FileIO.load(joinpath(REFERENCE_DIR, relpath))
    out = joinpath(DIFF_DIR, relpath)
    mkpath(dirname(out))
    size(a) == size(b) || return nothing
    diff = map(a, b) do p, q
        p, q = RGB{Float32}(p), RGB{Float32}(q)
        RGB{Float32}(abs(p.r - q.r), abs(p.g - q.g), abs(p.b - q.b))
    end
    FileIO.save(out, map(c -> RGB{Float32}(1 - c.r, 1 - c.g, 1 - c.b), diff))    # differences dark on white
    return out
end

"""
    compare_refimages(; threshold = COMPARISON_THRESHOLD) -> scores or nothing

Download the references, score every recorded image against its reference,
write the report files, and run `ReferenceTests.test_comparison`.
"""
function compare_refimages(; threshold = COMPARISON_THRESHOLD)
    ref = download_refimages()
    if ref === nothing
        @info "The reference-image comparison is skipped: no reference images for $(refimage_tag()).  " *
            "The gallery this run recorded is under $RECORDED_DIR; review.html shows it.  " *
            "Attach a tarball of that folder to the release `$(refimage_tag())` (test/refimages/upload.jl) to compare against it."
        return nothing
    end
    paths = recorded_paths()
    missing_refs, scores = ReferenceTests.compare(paths, ref, RECORDED_DIR)
    open(joinpath(REFIMAGE_DIR, "new_files.txt"), "w") do io
        foreach(p -> println(io, p), missing_refs)
    end
    open(joinpath(REFIMAGE_DIR, "missing_files.txt"), "w") do io
        refs = ReferenceTests.get_all_relative_filepaths_recursively(ref)
        foreach(p -> println(io, p), setdiff(Set(refs), Set(paths)))
    end
    open(joinpath(REFIMAGE_DIR, "scores.tsv"), "w") do io
        for (path, score) in sort(collect(pairs(scores)); by = last, rev = true)
            println(io, score, '\t', path)
        end
    end
    rm(DIFF_DIR; recursive = true, force = true)
    foreach(write_diff, keys(scores))
    isempty(missing_refs) || @info "$(length(missing_refs)) recorded images have no reference yet (new_files.txt)"
    ReferenceTests.test_comparison(scores; threshold)
    return scores
end

compare_refimages()
