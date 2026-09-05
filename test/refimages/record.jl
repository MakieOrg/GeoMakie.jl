# record.jl -- render every reference-image case to
# test_images/refimages/recorded/<name>.png.  (ReferenceTests-based comparison
# arrives with the refimage phase; until then this records, and review.jl shows.)

include("cases.jl")

mkpath(RECORDED_DIR)
for (name, render) in all_renders()
    path = joinpath(RECORDED_DIR, name * ".png")
    try
        save(path, render())
        println("recorded ", path)
    catch e
        @error "could not record $name" exception = (e, catch_backtrace())
    end
end
