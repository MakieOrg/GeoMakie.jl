# review.jl -- a static HTML page of every recorded reference image, at
# test_images/refimages/review.html.

include("cases.jl")

function write_review(path = joinpath(REFIMAGE_DIR, "review.html"))
    mkpath(dirname(path))
    io = IOBuffer()
    println(io, "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>GeoAxis decorations review</title>")
    println(io, "<style>body{font-family:sans-serif;margin:2em}.grid{display:flex;flex-wrap:wrap;gap:1em}",
        ".case{border:1px solid #ccc;padding:0.5em}.case img{display:block;max-width:600px}",
        ".case h3{margin:0 0 0.3em 0;font-size:1em}.case code{font-size:0.8em;color:#555}</style></head><body>")
    println(io, "<h1>GeoAxis decorations: recorded reference images</h1><div class=\"grid\">")
    for (name, _) in all_renders()
        img = joinpath("recorded", name * ".png")
        exists = isfile(joinpath(REFIMAGE_DIR, img))
        i = findfirst(c -> c.name == name, REFIMAGE_CASES)
        desc = i === nothing ? "extra render" : REFIMAGE_CASES[i].dest *
            (REFIMAGE_CASES[i].limits === nothing ? "" : " limits=" * string(REFIMAGE_CASES[i].limits)) *
            (isempty(REFIMAGE_CASES[i].attrs) ? "" : " " * string(REFIMAGE_CASES[i].attrs))
        println(io, "<div class=\"case\"><h3>", name, "</h3><code>", desc, "</code>")
        exists ? println(io, "<img src=\"", img, "\" alt=\"", name, "\">") : println(io, "<p><em>not recorded</em></p>")
        println(io, "</div>")
    end
    println(io, "</div></body></html>")
    open(path, "w") do f
        write(f, take!(io))
    end
    println("wrote ", path)
    return path
end

write_review()
