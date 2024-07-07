
function _stitch_all_example_blocks(page)
    # Extract all example blocks (this is naturally in order)
    all_example_blocks_in_order = filter(page.mdast.children) do x
        x.element isa MarkdownAST.CodeBlock && Base.occursin("@example", x.element.info)
    end
    # Join all the code blocks into a single string
    result = join(getproperty.(getproperty.(all_example_blocks_in_order, :element), :code), "\n")
    return result
end