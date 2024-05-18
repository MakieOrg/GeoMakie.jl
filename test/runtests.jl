using GeoMakie, GeometryBasics, CairoMakie, Test

Makie.set_theme!(Theme(
    Heatmap = (rasterize = 5,),
    Image   = (rasterize = 5,),
    Surface = (rasterize = 5,),
))

@testset "GeoMakie" begin
    @testset "Basics" begin
        lons = -180:180
        lats = -90:90
        field = [exp(cosd(l)) + 3(y/90) for l in lons, y in lats]

        fig = Figure()
        ax = GeoAxis(fig[1,1])
        el = surface!(ax, lons, lats, field; shading = NoShading)
        @test true
        # display(fig)
    end

    @testset "geo2basic" begin
        @test GeoMakie.coastlines() isa Vector
        @test GeoMakie.coastlines()[1] isa GeometryBasics.LineString
    end

    @testset "Line Splitting" begin
        @test split(GeoMakie.coastlines(),"+lon_0=-160") isa Vector
        ga = GeoAxis(Figure();dest = "+proj=wintri +lon_0=-160")
        @test GeoMakie.coastlines(ga) isa Observable
        @test GeoMakie.coastlines(ga)[][1] isa GeometryBasics.LineString
    end
    
    # @testset "Examples" begin
    #     geomakie_path = dirname(dirname(pathof(GeoMakie)))
    #     examples = readdir(joinpath(geomakie_path, "examples"); join = true)
    #     filenames = filter(x-> isfile(x) && endswith(x, ".jl"), examples)

    #     test_path = mkpath(joinpath(geomakie_path, "test_images"))
    #     cd(test_path) do
    #         for filename in filenames
    #             example_name = splitext(splitdir(filename)[2])[1]
    #             printstyled("Running ", bold = true, color = :cyan)
    #             println(example_name)

    #             @testset "$example_name" begin
    #                 @test begin
    #                     print(rpad("Include: ", 9))
    #                     @time include(filename)
    #                     true
    #                 end
    #                 @test begin
    #                     savepath = "$example_name.png"
    #                     print(rpad("PNG: ", 9))
    #                     @time CairoMakie.save(savepath, Makie.current_figure(); px_per_unit=2);
    #                     isfile(savepath) && filesize(savepath) > 1000

    #                 end
    #                 @test begin
    #                     savepath = "$example_name.pdf"
    #                     print(rpad("PDF: ", 9))
    #                     @time CairoMakie.save(savepath, Makie.current_figure());
    #                     isfile(savepath) && filesize(savepath) > 1000
    #                 end
    #                 haskey(ENV, "CI") && rm("$example_name.pdf")
    #             end
    #         end
    #     end
    # end
end
