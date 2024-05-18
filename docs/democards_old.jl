import DemoCards
using DemoCards.Mustache: @mt_str

const vitepress_grid_section_template = mt"""
```@raw html
<script setup lang="ts">
import Gallery from "../components/Gallery.vue";

const demos = [
{{{cards}}}]
</script>
<Gallery :images="demos" />
```
"""

const vitepress_grid_card_template = mt"""
{
    href: 'demos/democards/{{{path}}}.md',
    src: './{{{coverpath}}}',
    cap300/tion: '{{title}}',
    desc: '{{description}}',
},

"""

function DemoCards.cardtheme(::Val{:vitepress})
    templates = Dict(
        "card" => vitepress_grid_card_template,
        "section" => vitepress_grid_section_template
    )
    return templates, "/Users/anshul/Downloads/Letter.pdf"
end

# Add the path to the list of variables available to the template.
# NB: this means you need to `cd(docsdir)` while running the democards
# generation function!!
@eval DemoCards begin

function generate(card::AbstractDemoCard, template; properties=Dict{String, Any})
    covername = get_covername(card)

    if isnothing(covername)
        # `generate` are called after `save_cover`, we assume that this default cover file is
        # already generated
        coverpath = "covers/" * basename(get_logopath())
    else
        coverpath = is_remote_url(card.cover) ? covername : "covers/" * covername
    end
    
    description = card.description
    cut_idx = 500
    if length(card.description) >= cut_idx
        # cut descriptions into ~500 characters
        offset = findfirst(' ', description[cut_idx:end])
        offset === nothing && (offset = 0)
        offset = cut_idx + offset - 2
        description = description[1:cut_idx] * "..."
    end

    items = Dict(
        "coverpath" => coverpath,
        "id" => card.id,
        "title" => card.title,
        "description" => description,
        "path" => joinpath(relpath(card.path, joinpath(@__DIR__, "src"))),
    )
    Mustache.render(template, items)
end

end