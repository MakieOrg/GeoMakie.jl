using Documenter
using ImageTransformations, ImageIO, Base64, FileIO # for resize
import Documenter.DOM: escapehtml
import Documenter: MarkdownAST

abstract type OverviewGalleryBlocks <: Documenter.Expanders.ExpanderPipeline end

# Order doesn't really matter, because the expansion is done based on page location first.
Documenter.Selectors.order(::Type{OverviewGalleryBlocks}) = 12.0
Documenter.Selectors.matcher(::Type{OverviewGalleryBlocks}, node, page, doc) = Documenter.iscode(node, r"^@overviewgallery")

function Documenter.Selectors.runner(::Type{OverviewGalleryBlocks}, node, page, doc)
    @assert node.element isa MarkdownAST.CodeBlock
    x = node.element
    @assert Base.contains(x.info, "@overviewgallery")
    @assert !isempty(chomp(x.code)) "The `@overviewgallery` block must have at least one page name."
    # Main.@infiltrate
    # Bail early if in draft mode
    if Documenter.is_draft(doc, page)
        @debug "Skipping evaluation of @example block in draft mode:\n$(x.code)"
        Documenter.create_draft_result!(node; blocktype="@example")
        return
    end
    gallery_dict = doc.plugins[findfirst(x -> x isa ExampleConfig, doc.plugins)].gallery_dict

    not_found = String[]
    entries = String[]
    # find the blocks and use them as strings
    for pagename in split(x.code, '\n')
        if !haskey(gallery_dict, pagename)
            push!(not_found, pagename)
            continue
        end
        # obtain the element
        element = gallery_dict[pagename]
        # obtain properties from the element, with defaults if not found from the cardmeta blocks
        href    = element[:Path] # this is must have!!!
        src     = get(element, :Cover, "data:image/svg+xml;charset=utf-8,<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1\" height=\"1\"/>")
        caption = get(element, :Title, "")
        desc    = get(element, :Description, "")
        # now, create the necessary HTML for this:
        push!(entries, """
        <div class="grid-item">
            <div class="gallery-image">
                <div class="img-box">
                    <a href="$(escapehtml(href))">
                        <img src="$(src)" height="150px" alt="$(escapehtml(href))"/>
                        <div class="transparent-box1">
                            <div class="caption">
                                <h2>$(escapehtml(caption))</h2>
                            </div>
                        </div>
                        <div class="transparent-box2">
                            <div class="subcaption">
                                <p class="opacity-low">$(escapehtml(desc))</p>
                            </div>
                        </div>
                    </a>
                </div>
            </div>
        </div>""")
    end

    main_str = """
    <div class="grid-container">
    $(join(entries, "\n"))
    </div>
    """
    node.element = Documenter.RawNode(:html, main_str)

    if !isempty(not_found)
        @warn "The following pages were not found in the gallery:\n$(join(not_found, "\n"))"
    end
end