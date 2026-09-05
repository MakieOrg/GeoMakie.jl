# upload.jl -- tar the recorded gallery and attach it to the GitHub release
# `refimages-<major.minor>` as reference_images.tar, creating the release when
# it does not exist and replacing an earlier tarball.  CI runs it after the
# tests on a push to master (the `refimages` job in .github/workflows/ci.yml);
# by hand:
#
#     julia -e 'using Pkg; Pkg.add(["ghr_jll", "TOML"])'   # once, in the environment you run it from
#     GITHUB_TOKEN=$(gh auth token) julia test/refimages/upload.jl [path/to/recorded]
#
# The recorded folder defaults to test_images/refimages/recorded (a
# `CairoMakie/<name>.png` tree, as record.jl leaves it).

using Tar, TOML
using ghr_jll

const REPO_OWNER = "MakieOrg"
const REPO_NAME = "GeoMakie.jl"

function refimage_version()
    v = VersionNumber(TOML.parsefile(normpath(joinpath(@__DIR__, "..", "..", "Project.toml")))["version"])
    return "$(v.major).$(v.minor)"
end

function upload_refimages(recorded = normpath(joinpath(@__DIR__, "..", "..", "test_images", "refimages", "recorded"));
                          tag = "refimages-" * refimage_version(), commit = get(ENV, "GITHUB_SHA", "master"))
    isdir(recorded) || error("no recorded gallery at $recorded; run test/refimages/record.jl first")
    haskey(ENV, "GITHUB_TOKEN") || error("GITHUB_TOKEN is not set (try `gh auth token`)")
    tarball = joinpath(mktempdir(), "reference_images.tar")
    Tar.create(recorded, tarball)
    println("uploading $tarball ($(round(filesize(tarball) / 2^20; digits = 1)) MB) to $REPO_OWNER/$REPO_NAME release $tag")
    run(`$(ghr()) -replace -u $REPO_OWNER -r $REPO_NAME -c $commit -n $tag -b "Reference images for GeoMakie $(refimage_version()); compared by test/refimages/compare.jl" $tag $tarball`)
    return tag
end

upload_refimages((isempty(ARGS) ? () : (ARGS[1],))...)
