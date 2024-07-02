using CairoMakie, GeoMakie, Makie
using Makie.Colors

function infer_alphacolor(rgb1, rgb2)
    rgb1 == rgb2 && return RGBAf(rgb1.r, rgb1.g, rgb1.b, 1)
    c1 = Float64.((rgb1.r, rgb1.g, rgb1.b))
    c2 = Float64.((rgb2.r, rgb2.g, rgb2.b))
    alpha = @. 1 - (c1 - c2) * -1 # ( / (0 - 1))
    meanalpha = clamp(sum(alpha) / 3, 0, 1)
    meanalpha == 0 && return RGBAf(0, 0, 0, 0)
    c = @. clamp((c1 / meanalpha), 0, 1)
    return RGBAf(c..., meanalpha)
end

function alpha_colorbuffer(screen::MakieScreen)
    bg = screen.root_scene.backgroundcolor[]
    screen.root_scene.backgroundcolor[] = RGBAf(0, 0, 0, 1)
    b1 = deepcopy(colorbuffer(screen))
    display(b1)
    screen.root_scene.backgroundcolor[] = RGBAf(1, 1, 1, 1)
    b2 = deepcopy(colorbuffer(screen))
    screen.root_scene.backgroundcolor[] = bg
    return map(b1, b2) do b1, b2
        infer_alphacolor(b1, b2)
    end
end



# generate the logo

f, a, p = meshimage(
    -180..180,
    -90..90,
    GeoMakie.earth();
    npoints = 360,
    axis = (; type = GeoAxis, dest = "+proj=igh"),
)
hidedecorations!(a; grid = false)
ip = meshimage!(a, -180..180, -90..90, Makie.logo(); npoints = 1000)
screen = display(f; px_per_unit=2)
img =  alpha_colorbuffer(screen)
save(joinpath(@__DIR__, "src", "assets", "logo.png"), img)
