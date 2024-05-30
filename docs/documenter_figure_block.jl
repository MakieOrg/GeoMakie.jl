abstract type FigureBlocks <: Documenter.Expanders.NestedExpanderPipeline end


Documenter.Selectors.order(::Type{FigureBlocks})  = 8.0 # like @example
Documenter.Selectors.matcher(::Type{FigureBlocks},  node, page, doc) = Documenter.iscode(node, r"^@figure")

module MakieDocsHelpers
    struct AsMIME{M<:MIME,V}
        mime::M
        value::V
    end

    Base.show(io::IO, m::MIME"image/svg+xml", a::AsMIME{MIME"image/svg+xml"}) = show(io,m, a.value)
    Base.show(io::IO, m::MIME"image/png", a::AsMIME{MIME"image/png"}) = show(io,m, a.value)

    struct Image{M <: MIME, V}
        "The contents of the image encoded in base64."
        value::V
        "The desired size of the output image, in pixels."
        size::NTuple{2, Int}
    end

    Base.show(io::IO, m::MIME, a::Image{MIME}) where MIME = show(io, m, a.value)

    const current_figurelike = Ref{Any}(nothing)

end



function Documenter.Selectors.runner(::Type{FigureBlocks}, node, page, doc)
    el = node.element
    infoexpr = Meta.parse(el.info)
    args = infoexpr.args[3:end]
    if !isempty(args) && args[1] isa Symbol
        blockname = string(args[1])
        kwargs = args[2:end]
    else
        blockname = ""
        kwargs = args
    end

    is_continued = false
    # check if any previous code block is an @example block and has the same name (previous @figure blocks are
    # already converted at this point)
    if blockname != ""
        # iterate all the previous siblings
        prev = node.previous
        while prev !== nothing
            if prev.element isa Documenter.MultiOutput && prev.element.codeblock.info == "@example $blockname"
                is_continued = true
                break
            end
            prev = prev.previous
        end
    end

    kwargs = Dict(map(kwargs) do expr
        if !(expr isa Expr) && expr.head !== :(=) && length(expr.args) == 2 && expr.args[1] isa Symbol && expr.args[2] isa Union{String,Number,Symbol}
            error("Invalid keyword arg expression: $expr")
        end
        expr.args[1] => expr.args[2]
    end)
    el.info = "@example $blockname"
    el.code = transform_figure_code(el.code; is_continued, kwargs...)
    Documenter.Selectors.runner(Documenter.Expanders.ExampleBlocks, node, page, doc)
    # interrogate the node, if it is PNG then we replace the png output
    # with an `Image` struct, which houses the base64 string as well as
    # the Figure's size information.
    # This allows images to retain high quality yet be sized appropriately.
    if MakieDocsHelpers.current_figurelike[] isa Makie.FigureLike
        mimesym = get(kwargs, :mime, :png)
        mime = mimesym == :svg ? MIME"image/svg+xml"() : mimesym == :png ? MIME"image/png"() : error("Unknown mimetype $mime")
        image = Image{mime}(MakieDocsHelpers.current_figurelike[], size(MakieDocsHelpers.current_figurelike[]))
        # Obtain the node's multi-output element
        md_output_element = last(node.children) # the node has already been edited here
        md_output_element.element.element[mime] = image
    end
end

function transform_figure_code(code::String; is_continued::Bool, backend::Symbol = :CairoMakie, mime=:png)
    backend in (:CairoMakie, :GLMakie) || error("Invalid backend $backend")
    mimetype = mime == :svg ? "image/svg+xml" : mime == :png ? "image/png" : error("Unknown mimetype $mime")

    (is_continued ? "" : """
    using $backend
    $backend.activate!() # hide
    """) *
    """
    import ..MakieDocsHelpers # hide
    var"#result" = begin # hide
    $code
    end # hide
    if var"#result" isa Makie.FigureLike # hide
        MakieDocsHelpers.current_figurelike[] = var"#result" # hide
    end # hide
    MakieDocsHelpers.AsMIME(MIME"$mimetype"(), var"#result") # hide
    """
end