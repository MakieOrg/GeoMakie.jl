module Gallery
using Base, Markdown

struct Card
    href::String
    src::String
    caption::String
    desc::String
end

Card(; path = "", caption = "", desc = "", cover_ext = ".png") = Card(path, joinpath(splitdir(path)[1], "covers", path * cover_ext), caption, desc)

function Card(name::String)
    element = Main.GALLERY_DICT[name]
    Card(
        #=href   =# element[:Path], # this is must have!!!
        #=src    =# get(element, :Cover, "data:image/svg+xml;charset=utf-8,<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1\" height=\"1\"/>"),
        #=caption=# get(element, :Title, ""),
        #=desc   =# get(element, :Description, ""),
    )
end

function Base.show(io::IO, ::MIME"application/json", card::Card)
    print(io,
    """
    {
        "href": '$(card.href)',
        "src": '$(card.src)',
        "caption": '$(replace(card.caption, "'" => "\\'"))',
        "desc": '$(replace(card.desc, "'" => "\\'"))',
    }""")
end

function Base.show(io::IO, ::MIME"application/json", cards::Vector{Card})
    println(io, "[")
    for card in cards
        show(io, MIME"application/json"(), card)
        println(io, ",")
    end
    println(io, "]")
end

function mdify(cards::Vector{Card}; name = "demos", )
    iob = IOBuffer()
    show(iob, MIME"application/json"(), cards)
    card_json = String(take!(iob))
    return Markdown.MD(
        Markdown.Paragraph(
            ["""
            <script setup lang="ts">
            import Gallery from "./components/Gallery.vue";
            const $name = $card_json
            </script>
            <Gallery :images="$name" />
            """]
        )
    )
end

export Card, mdify
end