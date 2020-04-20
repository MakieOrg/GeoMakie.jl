using Documenter, GeoMakie

# use the README as the home page
cp(joinpath(dirname(@__DIR__), "README.md"), joinpath(@__DIR__, "src", "index.md"); force = true)

indexstr = read(joinpath(@__DIR__, "src", "index.md"), String)

replace(indexstr, """<a href = "https://www.github.com/JuliaPlots/Makie.jl"><img src="https://raw.githubusercontent.com/JuliaPlots/Makie.jl/master/assets/logo.png" alt="Makie.jl" height="30" align = "top"></a>""" => "Makie.jl")

write(joinpath(@__DIR__, "src", "index.md"), indexstr)

makedocs(;
    modules=[GeoMakie, AbstractPlotting],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
        "Example" => "example.md"
        "Recipes" => [
            "geoaxis.md",
            "stock.md"
        ],
        "API Reference" => "api.md"
    ],
    repo="https://github.com/JuliaPlots/GeoMakie.jl/blob/{commit}{path}#L{line}",
    sitename="GeoMakie.jl",
    authors="Anshul Singhvi",
)


#struct Local <: Documenter.DeployConfig end

#function Documenter.deploy_folder(cfg::Local;
#        repo, devbranch, push_preview, devurl, kwargs...)
#
#        devurl
#
    # folder = if get(ENV, "PUSH_LOCAL_BUILD", "false") == "true"
    #     @warn("Setting ENV[\"PUSH_LOCAL_BUILD\"] = \"false\", remember to set it to true for the next push.")
    #     ENV["PUSH_LOCAL_BUILD"] = "false"
    #     devurl
    # else
    #     @warn("Set ENV[\"PUSH_LOCAL_BUILD\"] = \"true\" if you want your local build to be pushed to Github Pages.")
    #     nothing
    # end
#end

#Documenter.authentication_method(::Local) = Documenter.SSH

#function Documenter.documenter_key(::Local)
#    open(readchomp, expanduser("~/documenter.geomakie.key")) * '\n'
#end


deploydocs(;
    repo="github.com/JuliaPlots/GeoMakie.jl",
    push_preview = true,
    # deploy_config = Local()
)
