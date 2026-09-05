# record.jl -- render every reference-image case to
# test_images/refimages/recorded/<name>.png.  (ReferenceTests-based comparison
# arrives with the refimage phase; until then this records, and review.jl shows.)

include("cases.jl")

mkpath(RECORDED_DIR)
for c in REFIMAGE_CASES
    path = joinpath(RECORDED_DIR, c.name * ".png")
    try
        save(path, render_case(c))
        println("recorded ", path)
    catch e
        @error "could not record $(c.name)" exception = (e, catch_backtrace())
    end
end
