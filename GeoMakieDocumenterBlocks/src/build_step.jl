"""
    ExampleProcessing <: Documenter.Builder.DocumenterPipeline

What does this do?

- Moves Cardmeta blocks
- Adds a quick example block (in Vitepress syntax) if requested in the pipeline and a cardmeta block is found
- Adds badges to the page if necessary
"""
abstract type ExampleProcessing <: Documenter.Builder.DocumentPipeline end

Documenter.Selectors.order(::Type{ExampleProcessing}) = 1.2 # after doctest, before expand templates.

function _is_cardmeta_block(x)
    return x.element isa MarkdownAST.CodeBlock && Base.occursin("@cardmeta", x.element.info)
end

function Documenter.Selectors.runner(::Type{ExampleProcessing}, doc::Documenter.Document)
    # Main.@infiltrate
    for (filename, page) in doc.blueprint.pages
        cardmeta_blocks = filter(_is_cardmeta_block, collect(page.mdast.children))
        is_examples_page = Base.occursin("examples", splitdir(page.build)[1]) || !isempty(cardmeta_blocks)
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
