using GeoMakie, CairoMakie, Test

@testset "Basics" begin
    lons = -180:180
    lats = -90:90
    field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

    fig = Figure()
    ax = GeoAxis(fig[1,1], coastlines=true)
    el = surface!(ax, lons, lats, field; shading = false)
    @test true
    # display(fig)
end

@testset "Examples" begin
    geomakie_path = dirname(dirname(pathof(GeoMakie)))
    examples = readdir(joinpath(geomakie_path, "examples"); join = true)
    filenames = filter(isfile, examples)

    test_path = mkpath(joinpath(geomakie_path, "test_images"))
    cd(test_path) do
        for filename in filenames
            example_name = splitext(splitdir(filename)[2])[1]

            @testset "$example_name" begin
                @test begin
                    include(filename)
                    true
                end
                @test begin
                    savepath = "$example_name.png"
                    CairoMakie.save(savepath, Makie.current_figure(); px_per_unit=2);
                    isfile(savepath) && filesize(savepath) > 1000

                end
                @test begin
                    savepath = "$example_name.pdf"
                    CairoMakie.save(savepath, Makie.current_figure());
                    isfile(savepath) && filesize(savepath) > 1000
                end
            end
        end
    end
end

# Remove all pdfs in the test examples directory
# to cut down on artifact size when uploaded.
if ENV["CI"] == "true"
    image_files = readdir(joinpath(dirname(dirname(pathof(GeoMakie))), "test_images"); join=true)
    pdf_files = filter(image_files, endswith("pdf"))
    rm.(pdf_files)
end
