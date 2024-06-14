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
            if !(ex.args[1] in (:Title, :Description, :Cover, :Authors, :Date))
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
        set_cover_to_png!(meta, page, doc)
        # insert the cover image into the page
        if !isnothing(idx)
            MarkdownAST.insert_after!(elements[idx], MarkdownAST.@ast Documenter.RawNode(:html, "<img src=\"$(meta[:Cover])\"/>"))
        end
    end
 

    # Authors and Date are for the transformer and can be applied within this block, the first four 
    # params need to go to the gallery/card object though.

    node.element = Documenter.MetaNode(x, page.globals.meta)

end

function set_cover_to_png!(meta, page, doc)
    if meta[:Cover] isa Makie.FigureLike
        # convert figure to image
        original_cover_image = Makie.colorbuffer(meta[:Cover])
        ratio = 600 / size(original_cover_image, 1) # get 300px height
        resized_cover_image = ImageTransformations.imresize(original_cover_image; ratio)
        
        # Below is the "inline pipeline"
        iob = IOBuffer()
        ImageIO.save(FileIO.Stream{FileIO.format"PNG"}(iob), resized_cover_image)
        # We could include this inline, but that seems to be causing issues.
        # meta[:Cover] = "data:image/png;base64, " * Base64.base64encode(String(take!(iob)))
        # Instead, we will save to a file and include that.
        bytes = take!(iob)
        filename = string(hash(bytes), base = 62) * ".png"
        write(joinpath(page.workdir, filename), bytes)
        meta[:Cover] = "/" * joinpath(relpath(page.workdir, doc.user.build), filename)
    end
end
