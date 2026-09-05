# review.jl -- a static HTML page of the gallery at
# test_images/refimages/review.html: recorded | reference | diff per render,
# sorted by comparison score when compare.jl wrote scores.tsv (worst first),
# in case order otherwise.

include("cases.jl")

"The scores compare.jl wrote, by render name; empty without a comparison."
function read_scores(path = joinpath(REFIMAGE_DIR, "scores.tsv"))
    scores = Dict{String, Float64}()
    isfile(path) || return scores
    for line in eachline(path)
        isempty(strip(line)) && continue
        score, rel = split(line, '\t')
        scores[splitext(basename(rel))[1]] = parse(Float64, score)
    end
    return scores
end

function write_review(path = joinpath(REFIMAGE_DIR, "review.html"))
    mkpath(dirname(path))
    scores = read_scores()
    renders = all_renders()
    order = sortperm([-get(scores, name, -Inf) for (name, _) in renders])
    io = IOBuffer()
    println(io, "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>GeoAxis decorations review</title>")
    println(io, "<style>body{font-family:sans-serif;margin:2em}.case{border:1px solid #ccc;padding:0.5em;margin-bottom:1em}",
        ".case h3{margin:0 0 0.3em 0;font-size:1em}.case code{font-size:0.8em;color:#555}",
        ".row{display:flex;gap:1em}.row div{flex:1}.row img{display:block;max-width:100%}",
        ".score{font-weight:bold}.bad{color:#b00}.ok{color:#080}</style></head><body>")
    println(io, "<h1>GeoAxis decorations: recorded | reference | diff</h1>")
    if isempty(scores)
        println(io, "<p><em>No comparison: no reference images were downloaded (see compare.jl).</em></p>")
    end
    for i in order
        name, _ = renders[i]
        k = findfirst(c -> c.name == name, REFIMAGE_CASES)
        desc = k === nothing ? "extra render" : REFIMAGE_CASES[k].dest *
            (REFIMAGE_CASES[k].limits === nothing ? "" : " limits=" * string(REFIMAGE_CASES[k].limits)) *
            (isempty(REFIMAGE_CASES[k].attrs) ? "" : " " * string(REFIMAGE_CASES[k].attrs))
        println(io, "<div class=\"case\"><h3>", name)
        if haskey(scores, name)
            s = scores[name]
            println(io, " <span class=\"score ", s > 0.05 ? "bad" : "ok", "\">", round(s; digits = 4), "</span>")
        end
        println(io, "</h3><code>", desc, "</code><div class=\"row\">")
        for (dir, label) in ((RECORDED_DIR, "recorded"), (REFERENCE_DIR, "reference"), (DIFF_DIR, "diff"))
            img = relpath(image_path(dir, name), REFIMAGE_DIR)
            println(io, "<div><p>", label, "</p>")
            isfile(joinpath(REFIMAGE_DIR, img)) ? println(io, "<img src=\"", img, "\" alt=\"", name, " ", label, "\">") :
                println(io, "<p><em>none</em></p>")
            println(io, "</div>")
        end
        println(io, "</div></div>")
    end
    println(io, "</body></html>")
    open(path, "w") do f
        write(f, take!(io))
    end
    println("wrote ", path)
    return path
end

write_review()
