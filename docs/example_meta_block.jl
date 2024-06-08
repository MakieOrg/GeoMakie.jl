using Documenter

abstract type CardMetaBlocks <: Documenter.Expanders.NestedExpanderPipeline end

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

    meta = Dict{Symbol, Any}()

    global GALLERY_DICT
    GALLERY_DICT[page_link_path] = meta

    # The sandboxed module -- either a new one or a cached one from this page.
    current_mod = Documenter.get_sandbox_module!(page.globals.meta, "atexample", page_name)

    x = node.element
    lines = Documenter.find_block_in_file(x.code, page.source)
    @debug "Evaluating @cardmeta block:\n$(x.code)"
    @infiltrate

    for (ex, str) in Documenter.parseblock(x.code, doc, page)
        # If not `isassign`, this might be a comment, or any code that the user
        # wants to hide. We should probably warn, but it is common enough that
        # we will silently skip for now.
        if Documenter.isassign(ex)
            if !(ex.args[1] in (:Title, :Description, :Cover))
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
    node.element = Documenter.MetaNode(x, page.globals.meta)

end