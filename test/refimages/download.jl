# download.jl -- fetch this minor version's reference images from the GitHub
# release `refimages-<major.minor>` into test_images/refimages/reference/.
# The tarball is what upload.jl attaches: a `CairoMakie/<name>.png` tree.

using Downloads, Tar, TOML

isdefined(@__MODULE__, :REFIMAGE_DIR) || include("cases.jl")

"The `major.minor` of GeoMakie's Project.toml, which names the release the reference images live on."
function refimage_version()
    v = VersionNumber(TOML.parsefile(normpath(joinpath(@__DIR__, "..", "..", "Project.toml")))["version"])
    return "$(v.major).$(v.minor)"
end
refimage_tag(version = refimage_version()) = "refimages-$version"
refimage_url(tag = refimage_tag()) = "https://github.com/MakieOrg/GeoMakie.jl/releases/download/$tag/reference_images.tar"

"""
    download_refimages(; tag, dir = REFERENCE_DIR) -> dir or nothing

Download and extract the reference tarball of `tag` into `dir`; `nothing`
(with the reason logged) when it cannot be fetched: no network, or no release
of that tag yet.  `REUSE_IMAGES_TAR=1` keeps a tarball already downloaded.
"""
function download_refimages(; tag = refimage_tag(), dir = REFERENCE_DIR)
    tar = joinpath(dirname(dir), "reference_images.tar")
    reuse = get(ENV, "REUSE_IMAGES_TAR", "0") == "1" && isfile(tar)
    if !reuse
        mkpath(dirname(tar))
        try
            Downloads.download(refimage_url(tag), tar)
        catch e
            @info "Reference images for $tag could not be downloaded from $(refimage_url(tag)): $(sprint(showerror, e))"
            rm(tar; force = true)
            return nothing
        end
    end
    rm(dir; recursive = true, force = true)
    Tar.extract(tar, dir)
    return dir
end
