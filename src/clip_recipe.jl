"""
    clip(points)

For vector backends, this recipe encodes a nonlinear clip path defined by
`points`, in dataspace.  Note that this is two-dimensional only.

Currently, it is only implemented for CairoMakie.  If running in any other
backend, it will be disregarded.
"""
@recipe(Clip) do scene
    Attributes(
        inspectable = theme(scene, :inspectable),
    )
end

function Makie.plot!(plot::Clip)
    lines!(plot, plot[1]; visible = false)
end

function CairoMakie.cairo_draw(scene::Scene, screen::CairoScreen, plot::Clip)
    positions = plot[1][]
    model = plot[:model][]
    space = to_value(get(plot, :space, :data))
    projected_positions = Point2{Float64}.(project_position.(Ref(scene), Ref(space), positions, Ref(model)))

    ctx = screen.context
    Cairo.new_path(ctx)

    n = length(positions)
    @inbounds for i in 1:n
        p = positions[i]
        # only take action for non-NaNs
        if !isnan(p)
            # new line segment at beginning or if previously NaN
            if i == 1 || isnan(positions[i-1])
                Cairo.move_to(ctx, p...)
            else
                Cairo.line_to(ctx, p...)
            end
        end
    end

    Cairo.clip(ctx)
    Cairo.new_path(ctx)
    end
end
