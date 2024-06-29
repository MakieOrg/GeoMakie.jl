#=
# The `cardmeta` pipeline

Cardmeta blocks add metadata to a demo file.  

The pipeline has two parts:
- The actual cardmeta block which moves things around
- The initial transformer which moves all cardmeta blocks to the end of the page

The reason we need to move the block to the end is so that it is evaluated
after all other blocks in the page.
=#

using Documenter
using ImageTransformations, ImageIO, Base64, FileIO # for resize
import Documenter: MarkdownAST

abstract type CardMetaBlocks <: Documenter.Expanders.ExpanderPipeline end

# Order doesn't really matter, because the expansion is done based on page location first.
Documenter.Selectors.order(::Type{CardMetaBlocks}) = 12.0
Documenter.Selectors.matcher(::Type{CardMetaBlocks}, node, page, doc) = Documenter.iscode(node, r"^@cardmeta")

GALLERY_DICT = Dict{String, Any}()

function Documenter.Selectors.runner(::Type{CardMetaBlocks}, node, page, doc)
    # Bail early if in draft mode
    if Documenter.is_draft(doc, page)
        @debug "Skipping evaluation of @example block in draft mode:\n$(x.code)"
        Documenter.create_draft_result!(node; blocktype="@example")
        return
    end

    # Literate.jl uses the page filename as an "environment name" for the example block,
    # so we need to extract that from the page.  The code in the meta block has
    # to be evaluated in the same module in order to have access to local variables.
    page_name = first(splitext(last(splitdir(page.source))))
    page_link_path = first(splitext(relpath(page.build, doc.user.build)))

    global GALLERY_DICT
    meta = get!(GALLERY_DICT, page_name, Dict{Symbol, Any}())
    meta[:Path] = page_link_path
    # The sandboxed module -- either a new one or a cached one from this page.
    current_mod = Documenter.get_sandbox_module!(page.globals.meta, "atexample", page_name)

    x = node.element
    lines = Documenter.find_block_in_file(x.code, page.source)
    @debug "Evaluating @cardmeta block:\n$(x.code)"
    # @infiltrate

    for (ex, str) in Documenter.parseblock(x.code, doc, page)
        # If not `isassign`, this might be a comment, or any code that the user
        # wants to hide. We should probably warn, but it is common enough that
        # we will silently skip for now.
        if Documenter.isassign(ex)
            if !(ex.args[1] in (:Title, :Description, :Cover, :Authors, :Date, :Tags))
                source = Documenter.locrepr(page.source, lines)
                @warn(
                    "In $source: `@cardmeta` block has an unsupported " *
                    "keyword argument: $(ex.args[1])",
                )
            end
            try
                meta[ex.args[1]] = Core.eval(current_mod, ex.args[2])
            catch err
                Documenter.@docerror(doc, :meta_block,
                    """
                    failed to evaluate `$(strip(str))` in `@cardmeta` block in $(Documenter.locrepr(page.source, lines))
                    ```$(x.info)
                    $(x.code)
                    ```
                    """, exception = err)
            end
        end
    end

    # TODO: get defaults
    # How?
    # Title: get the first heading node on the page as DocumenterVitepress does
    # Description: empty string as default
    # Cover: no image as default
    # Author: Default should be hardcoded to `["Anshul Singhvi"](https://github.com/asinghvi17)`
    # Date: nothing, don't include it if nothing

    # Title
    # If no name is given, find the first header in the page,
    # and use that as the name.
    elements = collect(page.mdast.children)
    # elements is a vector of Markdown.jl objects,
    # you can get the MarkdownAST stuff via `page.mdast`.
    # I f``
    idx = findfirst(x -> x.element isa Union{MarkdownAST.Heading, Documenter.AnchoredHeader}, elements)
    title = if isnothing(idx)
        splitext(page)[1]
    else
        Documenter.MDFlatten.mdflatten(elements[idx])
    end
    get!(meta, :Title, title)


    # Cover - check for e.g. `fig`, `f`, `figure`
    if !haskey(meta, :Cover) # no default was assigned
        for potential_name in (:fig, :f, :figure)
            contents = nothing
            try
                _c = Core.eval(current_mod, potential_name)
                contents = _c
            catch e
                if e isa UndefVarError
                    continue
                else
                    rethrow(e)
                end
            end
            
            if contents isa Makie.FigureLike
                meta[:Cover] = contents
                break
            end
        end
    end

    if haskey(meta, :Cover)

        cover_img_bytes, mime = get_image_and_mime(meta[:Cover])

        if !isnothing(idx)
            MarkdownAST.insert_after!(elements[idx], MarkdownAST.@ast Documenter.RawNode(:html, image_node(cover_img_bytes, mime)))
        end

        set_cover_to_image!(meta, meta[:Cover], cover_img, mime, page, doc)
        # insert the cover image into the page
        
    end

    # Authors and Date are for the transformer and can be applied within this block, the first four 
    # params need to go to the gallery/card object though.

    node.element = Documenter.MetaNode(x, page.globals.meta)

end


function image_node(cover_bytes, ::MIME"file")
    return """<img src="$cover_bytes"/>"""
end



get_image_and_mime(fap::Makie.FigureLike) = get_image_and_mime(Makie.get_scene(fap))
get_image_and_mime(scene::Makie.Scene) = get_image_and_mime(Makie.getscreen(scene))
function get_image_and_mime(screen::Makie.MakieScreen)
    MIMES_IN_ORDER = [
        MIME"image/svg+xml"(),
        # MIME"application/pdf"(),
        # MIME"application/postscript"(),
        MIME"image/png"()
    ]
    iob = IOBuffer()
    for mime in MIMES_IN_ORDER
        if Makie.backend_showable(screen, mime)
            Makie.backend_show(screen, iob, mime, getfield(screen, :scene))
            bytes = String(take!(iob))
            return (bytes, mime)
        end
    end
end


function set_cover_to_image!(meta, cover, cover_img, mime::MIME, page, doc)
    image = 123
end
function set_cover_to_image!(meta, cover::Makie.FigureLike, cover_img, mime::MIME"image/png", page, doc)
    # convert figure to image
    original_cover_image = FileIO.load
    ratio = 600 / size(original_cover_image, 1) # get 300px height
    resized_cover_image = ImageTransformations.imresize(original_cover_image; ratio)
    
    # Below is the "inline pipeline"
    iob = IOBuffer()
    FileIO.save(FileIO.Stream{FileIO.format"PNG"}(iob), resized_cover_image)
    # We could include this inline, but that seems to be causing issues.
    # meta[:Cover] = "data:image/png;base64, " * Base64.base64encode(String(take!(iob)))
    # Instead, we will save to a file and include that.
    bytes = take!(iob)
    filename = string(hash(bytes), base = 62) * ".png"
    write(joinpath(page.workdir, filename), bytes)
    meta[:Cover] = "/" * joinpath(relpath(page.workdir, doc.user.build), filename)
end

function set_cover_to_image!(meta, cover::Makie.FigureLike, cover_img, mime::MIME"image/svg+xml", page, doc)
    filename = string(hash(cover_img), base = 62) * ".svg"
    write(joinpath(page.workdir, filename), bytes)
    meta[:Cover] = "/" * joinpath(relpath(page.workdir, doc.user.build), filename)
end

abstract type MoveCardMeta <: Documenter.Builder.DocumentPipeline end

Documenter.Selectors.order(::Type{MoveCardMeta}) = 1.2 # after doctest, before expand templates.

function _is_cardmeta_block(x)
    return x.element isa MarkdownAST.CodeBlock && Base.occursin("@cardmeta", x.element.info)
end

function Documenter.Selectors.runner(::Type{MoveCardMeta}, doc::Documenter.Document)
    # Main.@infiltrate
    for (filename, page) in doc.blueprint.pages
        cardmeta_blocks = filter(_is_cardmeta_block, collect(page.mdast.children))
        if !isempty(cardmeta_blocks) # some cardmeta block was detected
            # move the cardmeta block from wherever it is to the end of the page.
            MarkdownAST.insert_after!(last(page.mdast.children), first(cardmeta_blocks))
        elseif Base.occursin("examples", splitdir(page.build)[1]) # only inject cardmeta if in examples dir
            # do nothing for now - potentially inject an extra cardmeta block at the end
            # of every page.
            MarkdownAST.insert_after!(last(page.mdast.children), MarkdownAST.@ast MarkdownAST.CodeBlock("@cardmeta", ""))
        end
    end
end