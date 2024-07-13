# GeoMakieDocumenterBlocks

This package implements two Documenter blocks, `@cardmeta` and `@overviewgallery`, which are used to generate DemoCards-like cards but in memory and without file manipulation or external json files, nor any requirement for directory structure.

The package is integrated with Makie but can also be used standalone, with Strings encoding either base64 images or urls.

## Usage

See the GeoMakie docs for usage examples, the idea is that you put a cardmeta block in each example file (it's automagically moved to the end) and put an overviewgallery block in your gallery page if you want one.

You also have to pass the `ExampleFormat` plugin to your `makedocs` function to use these blocks.  This can be a no-arg constructor if you just want defaults.

## How it works

1. The Documenter build step moves all cardmeta blocks to the bottom of the page, and adds a "copy pastable code block" to the top just below the title.
2. The example blocks run and do magical things.
3. The cardmeta block runs and:
    1. Pushes a dict of card metadata
    2. Places the cover image directly below the title, displacing the copy pastable code block 
    3. Nothing else yet but coming soon
4. The overviewgallery block parses this metadata and emits HTML for the gallery blocks and links.