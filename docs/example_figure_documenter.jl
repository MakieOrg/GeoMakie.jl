using Documenter
import Documenter: Builder, Expanders, Selectors, MarkdownAST
import Markdown, REPL
import Base64: stringmime
import IOCapture
import Documenter: iscode, droplines, prepend_prompt, remove_sandbox_from_output
import Makie

# First, we define an abstract type which represents the example-figure block.
abstract type ExampleFigureBlocks <: Expanders.ExpanderPipeline end

Selectors.order(::Type{ExampleFigureBlocks})     = 1.0
Selectors.matcher(::Type{ExampleFigureBlocks},     node, page, doc) = iscode(node, r"^@examplefigure")

# Find if there is any format with color output
function _any_color_fmt(doc)
    DocumenterVitepress.MarkdownVitepress in typeof.(doc.user.format) && return true
    idx = findfirst(x -> (x isa Documenter.HTML), doc.user.format)
    idx === nothing && return false
    return doc.user.format[idx].ansicolor
end

function Selectors.runner(::Type{ExampleFigureBlocks}, node, page, doc)
    @assert node.element isa MarkdownAST.CodeBlock
    x = node.element

    matched = match(r"^@examplefigure(?:\s+([^\s;]+))?\s*(;.*)?$", x.info)
    matched === nothing && error("invalid '@examplefigure' syntax: $(x.info)")
    name, kwargs = matched.captures

    # Bail early if in draft mode
    if Documenter.is_draft(doc, page)
        @debug "Skipping evaluation of @examplefigure block in draft mode:\n$(x.code)"
        Documenter.create_draft_result!(node; blocktype="@examplefigure")
        return
    end

    # The sandboxed module -- either a new one or a cached one from this page.
    mod = Documenter.get_sandbox_module!(page.globals.meta, "atexamplefig", name)
    mod_dark = Documenter.get_sandbox_module!(page.globals.meta, "atexamplefig_dark", name)
    sym = nameof(mod)
    lines = Documenter.find_block_in_file(x.code, page.source)

    # "parse" keyword arguments to example
    continued = false
    ansicolor = _any_color_fmt(doc)
    backend = nothing
    format = nothing
    dark_theme = Makie.theme_dark()
    if kwargs !== nothing
        continued = occursin(r"\bcontinued\s*=\s*true\b", kwargs)
        matched = match(r"\bansicolor\s*=\s*(true|false)\b", kwargs)
        if matched !== nothing
            ansicolor = matched[1] == "true"
        end
        matched = match(r"\bbackend\s*=\s*([^\s;]+)", kwargs)
        if matched !== nothing
            if matched[1] in ["GLMakie", "CairoMakie", "WGLMakie", "RPRMakie"]
                backend = matched[1]
            else
                @warn """
                Found invalid backend `$(matched[1])` in @examplefigure block, using default backend.
                Valid backends are: `GLMakie`, `CairoMakie`, `WGLMakie`, `RPRMakie`
                """
            end
        end
        matched = match(r"\bformat\s*=\s*([^\s;]+)", kwargs)
        if matched !== nothing
            if matched[1] in ["svg", "png", "jpeg", "html"]
                format = matched[1]
            else
                @warn """
                Found invalid format `$(matched[1])` in @examplefigure block, using default format.
                Valid formats are: `svg`, `png`, `jpeg`, `html`
                """
            end
        end
        matched = match(r"\bdark_theme\s*=\s*([^;]+)[$;]", kwargs)
        dark_theme = if matched !== nothing
            dark_theme_str = matched[1]
            @info dark_theme_str
            Core.eval(mod, Expr(:global, Expr(:(=), :ans, Meta.parse(dark_theme_str))))
        else
            @info "No dark theme found :()"
            Makie.theme_dark()
        end
    end

    @debug "Evaluating @examplefigure block:\n$(x.code)"
    # Evaluate the code block. We redirect stdout/stderr to `buffer`.

    result, result_dark, buffer = nothing, nothing, IOBuffer()
    if !continued # run the code
        # check if there is any code waiting
        if haskey(page.globals.meta, :ContinuedCode) && haskey(page.globals.meta[:ContinuedCode], sym)
            code = page.globals.meta[:ContinuedCode][sym] * '\n' * x.code
            delete!(page.globals.meta[:ContinuedCode], sym)
        else
            code = x.code
        end
        linenumbernode = LineNumberNode(lines === nothing ? 0 : lines.first,
                                        basename(page.source))
        for (ex, str) in Documenter.parseblock(code, doc, page; keywords = false,
                                              linenumbernode = linenumbernode)
            c = IOCapture.capture(rethrow = InterruptException, color = ansicolor) do
                cd(page.workdir) do
                    Core.eval(mod, ex)
                end
            end
            Core.eval(mod, Expr(:global, Expr(:(=), :ans, QuoteNode(c.value))))
            result = c.value
            print(buffer, c.output)
            if c.error
                bt = Documenter.remove_common_backtrace(c.backtrace)
                Documenter.@docerror(doc, :example_block,
                    """
                    failed to run `@examplefigure` block in $(Documenter.locrepr(page.source, lines))
                    ```$(x.info)
                    $(x.code)
                    ```
                    """, exception = (c.value, bt))
                return
            end
            # Now attend to the dark theme
            c = IOCapture.capture(rethrow = InterruptException, color = ansicolor) do
                cd(page.workdir) do
                    Makie.with_theme(dark_theme) do
                        Core.eval(mod_dark, ex)
                    end
                end
            end
            Core.eval(mod_dark, Expr(:global, Expr(:(=), :ans, QuoteNode(c.value))))
            result_dark = c.value
            print(buffer, c.output)
            if c.error
                bt = Documenter.remove_common_backtrace(c.backtrace)
                Documenter.@docerror(doc, :example_block,
                    """
                    failed to run `@examplefigure` dark-theme block in $(Documenter.locrepr(page.source, lines))
                    ```$(x.info)
                    $(x.code)
                    ```
                    and `dark_theme = $(dark_theme)`
                    """, exception = (c.value, bt))
                return
            end

        end
    else # store the continued code
        CC = get!(page.globals.meta, :ContinuedCode, Dict())
        CC[sym] = get(CC, sym, "") * '\n' * x.code
    end
    # Splice the input and output into the document.
    content = MarkdownAST.Node[]
    input   = Documenter.droplines(x.code)


    output = if result isa Makie.FigureLike 
        if result_dark isa Makie.FigureLike
            backend = get_makie_backend(backend, mod_dark)
            format = isnothing(format) ? "png" : format
            mime_format, fileio_format = if format == "png"
                (MIME"image/png+lightdark"(), Makie.FileIO.format"PNG")
            elseif format == "jpeg"
                (MIME"image/jpeg+lightdark"(), Makie.FileIO.format"JPEG")
            elseif format == "svg"
                (MIME"image/svg+xml+lightdark"(), Makie.FileIO.format"SVG")
            else
                (MIME"text/html+lightdark"(), Makie.FileIO.format"HTML")
            end

            filename = rand('a':'z', 10) 
            Makie.save(joinpath(doc.user.build, "$(filename)_light.$format"), result; backend)
            light_str = read(joinpath(doc.user.build, "$(filename)_light.$format"), String)
            rm(joinpath(doc.user.build, "$(filename)_light.$format"))
            Makie.save(joinpath(doc.user.build, "$(filename)_dark.$format"), result_dark; backend)
            dark_str = read(joinpath(doc.user.build, "$(filename)_dark.$format"), String)
            rm(joinpath(doc.user.build, "$(filename)_dark.$format"))

            
            output = Dict{MIME, Any}()

            output[mime_format] = (light_str, dark_str, backend)
            output
        end
    else

        # Generate different  in different formats and let each writer select
        output = Base.invokelatest(Documenter.display_dict, result, context = :color => ansicolor)
        # Remove references to gensym'd module from text/plain
        m = MIME"text/plain"()
        if haskey(output, m)
            output[m] = remove_sandbox_from_output(output[m], mod)
        end
        output
    end

    # Only add content when there's actually something to add.
    isempty(input) || push!(content, MarkdownAST.Node(MarkdownAST.CodeBlock("julia", input)))
    if result === nothing
        stdouterr = Documenter.sanitise(buffer)
        stdouterr = remove_sandbox_from_output(stdouterr, mod)
        isempty(stdouterr) || push!(content, Node(Documenter.MultiOutputElement(Dict{MIME,Any}(MIME"text/plain"() => stdouterr))))
    elseif !isempty(output)
        push!(content, MarkdownAST.Node(Documenter.MultiOutputElement(output)))
    end
    # ... and finally map the original code block to the newly generated ones.
    node.element = Documenter.MultiOutput(x)
    append!(node.children, content)
end

# Replace references to gensym'd module with Main
function remove_sandbox_from_output(str, mod::Module)
    replace(str, Regex(("(Main\\.)?$(nameof(mod))")) => "Main")
end



function get_makie_backend(backend, mod)
    return if backend == "GLMakie" 
        Core.eval(mod, Expr(:(=), :ans, :GLMakie))
    elseif backend == "CairoMakie" 
        Core.eval(mod, Expr(:(=), :ans, :CairoMakie))
    elseif backend == "WGLMakie" 
        Core.eval(mod, Expr(:(=), :ans, :WGLMakie))
    elseif backend == "RPRMakie" 
        Core.eval(mod, Expr(:(=), :ans, :RPRMakie))
    else
        Makie.current_backend()
    end
end