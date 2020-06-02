# @macroexpand @recipe(Coastlines) do scene
#     merge(
#         default_theme(scene, Lines),
#         Theme(crs = (source = LonLat(), dest = LonLat()),)
#     )
# end

"""
    coastlines(; kwargs...)

Plot coastlines along the world.
"""
coastlines(; kwargs...) = coastlines!(Scene(); kwargs...)

const Coastlines{ArgType} = AbstractPlotting.Combined{coastlines, ArgType}

(Base).show(var"#34#io"::IO, ::Type{<:Coastlines}) = begin
        #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:154 =#
        AbstractPlotting.print(var"#34#io", "Coastlines", "{...}")
end

function coastlines(var"#39#attributes"...)
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:13 =#
    var"#36#attr" = AbstractPlotting.Attributes(var"#39#attributes")
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:14 =#
    var"#37#kw" = AbstractPlotting.extract_scene_attributes!(var"#36#attr")
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:15 =#
    AbstractPlotting.plot!(AbstractPlotting.Scene(; var"#37#kw"...), Coastlines, var"#36#attr", 1)
end

#= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:19 =#
function coastlines!(; var"#41#attributes"...)
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:20 =#
    AbstractPlotting.plot!(AbstractPlotting.current_scene(), Coastlines, AbstractPlotting.Attributes(var"#41#attributes"), 1)
end
#= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:23 =#
function coastlines!(var"#42#scene"::AbstractPlotting.SceneLike; var"#44#attributes"...)
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:24 =#
    AbstractPlotting.plot!(var"#42#scene", Coastlines, AbstractPlotting.Attributes(var"#44#attributes"), 1)
end
#= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:27 =#
function coastlines(var"#47#attributes"::AbstractPlotting.Attributes, var"#48#args"...; var"#49#kw_attributes"...)
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:28 =#
    var"#45#merged" = AbstractPlotting.merge!(AbstractPlotting.Attributes(var"#49#kw_attributes"), var"#47#attributes")
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:29 =#
    var"#46#kw" = AbstractPlotting.extract_scene_attributes!(var"#45#merged")
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:30 =#
    AbstractPlotting.plot!(AbstractPlotting.Scene(; var"#46#kw"...), Coastlines, var"#45#merged", 1)
end
#= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:33 =#
function coastlines!(var"#50#attributes"::AbstractPlotting.Attributes, var"#51#args"...; var"#52#kw_attributes"...)
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:34 =#
    AbstractPlotting.plot!(AbstractPlotting.current_scene(), Coastlines, AbstractPlotting.merge!(AbstractPlotting.Attributes(var"#52#kw_attributes"), var"#50#attributes"), 1)
end
#= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:37 =#
function coastlines!(var"#53999#scene"::AbstractPlotting.SceneLike, var"#54999#attributes"::AbstractPlotting.Attributes, var"#55999#args"...; var"#56999#kw_attributes"...)
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:38 =#
    AbstractPlotting.plot!(var"#53999#scene", Coastlines, AbstractPlotting.merge!(AbstractPlotting.Attributes(var"#56999#kw_attributes"), var"#54999#attributes"), 1)
end


AbstractPlotting.default_theme(var"#57999#scene", ::Type{<:Coastlines}) = begin
        (((scene,)->begin
                merge(default_theme(scene, Lines), Theme(crs = (source = LonLat(), dest = LonLat())))
            end))(var"#57999#scene")
    end
export Coastlines, coastlines, coastlines!

function AbstractPlotting.plot!(p::Coastlines)

    @extract p (crs,)

    new_linevec = Observable(COASTLINES_LINEVEC)

    lift(crs.source, crs.dest) do source, dest
        new_linevec[] = Proj4.transform.(source, dest, COASTLINES_LINEVEC)
    end

    lines!(p, new_linevec)
end

"""
    earth(; kwargs...)

Plots an image of the Earth in the given projection.
"""
earth(; kwargs...) = earth!(Scene(); kwargs...)

const Earth{ArgType} = AbstractPlotting.Combined{earth, ArgType}

(Base).show(var"#34#io"::IO, ::Type{<:Earth}) = begin
        #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:154 =#
        AbstractPlotting.print(var"#34#io", "Earth", "{...}")
end

function earth(var"#39#attributes"...)
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:13 =#
    var"#36#attr" = AbstractPlotting.Attributes(var"#39#attributes")
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:14 =#
    var"#37#kw" = AbstractPlotting.extract_scene_attributes!(var"#36#attr")
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:15 =#
    AbstractPlotting.plot!(AbstractPlotting.Scene(; var"#37#kw"...), Earth, var"#36#attr", 1)
end

#= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:19 =#
function earth!(; var"#41#attributes"...)
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:20 =#
    AbstractPlotting.plot!(AbstractPlotting.current_scene(), Earth, AbstractPlotting.Attributes(var"#41#attributes"), 1)
end
#= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:23 =#
function earth!(var"#42#scene"::AbstractPlotting.SceneLike; var"#44#attributes"...)
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:24 =#
    AbstractPlotting.plot!(var"#42#scene", Earth, AbstractPlotting.Attributes(var"#44#attributes"), 1)
end
#= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:27 =#
function earth(var"#47#attributes"::AbstractPlotting.Attributes, var"#48#args"...; var"#49#kw_attributes"...)
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:28 =#
    var"#45#merged" = AbstractPlotting.merge!(AbstractPlotting.Attributes(var"#49#kw_attributes"), var"#47#attributes")
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:29 =#
    var"#46#kw" = AbstractPlotting.extract_scene_attributes!(var"#45#merged")
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:30 =#
    AbstractPlotting.plot!(AbstractPlotting.Scene(; var"#46#kw"...), Earth, var"#45#merged", 1)
end
#= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:33 =#
function earth!(var"#50#attributes"::AbstractPlotting.Attributes, var"#51#args"...; var"#52#kw_attributes"...)
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:34 =#
    AbstractPlotting.plot!(AbstractPlotting.current_scene(), Earth, AbstractPlotting.merge!(AbstractPlotting.Attributes(var"#52#kw_attributes"), var"#50#attributes"), 1)
end
#= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:37 =#
function earth!(var"#53999#scene"::AbstractPlotting.SceneLike, var"#54999#attributes"::AbstractPlotting.Attributes, var"#55999#args"...; var"#56999#kw_attributes"...)
    #= /Users/anshul/.julia/dev/AbstractPlotting/src/recipes.jl:38 =#
    AbstractPlotting.plot!(var"#53999#scene", Earth, AbstractPlotting.merge!(AbstractPlotting.Attributes(var"#56999#kw_attributes"), var"#54999#attributes"), 1)
end


AbstractPlotting.default_theme(var"#57999#scene", ::Type{<:Earth}) = begin
        (((scene,)->begin
        merge(
            default_theme(scene, Surface),
            Theme(
                crs = (
                    source = LonLat(),
                    dest = LonLat()
                ),
                shading = false
            )
        )
            end))(var"#57999#scene")
    end
export Earth, earth, earth!

function AbstractPlotting.plot!(p::Earth)

    @extract p (crs,)

    lons = LinRange(-180, 179, size(EARTH_IMG)[2])
    lats = LinRange(89.5, -89.5, size(EARTH_IMG)[1])

    xs = Observable([lon for lat in lats, lon in lons])
    ys = Observable([lat for lat in lats, lon in lons])

    lift(crs.source, crs.dest) do source, dest

        xs.val = [lon for lat in lats, lon in lons]
        ys.val = [lat for lat in lats, lon in lons]
        Proj4.transform!(source, dest, vec(xs.val), vec(ys.val))

        xs[] = xs[]
        ys[] = ys[]
    end

    surface!(p, xs, ys, zeros(size(xs[])); color = EARTH_IMG, shading = false, show_axis = false)
end
