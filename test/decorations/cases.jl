# cases.jl -- the named axis cases the decorations are judged on: the twelve
# research baselines, the two issue reproductions, and the first thirty
# projections of examples/most_projections.jl.

struct DecorationCase
    name::String
    dest::String
    limits::Any            # `nothing` or ((lon0, lon1), (lat0, lat1))
end

const BASELINE_CASES = DecorationCase[
    DecorationCase("eqearth", "+proj=eqearth", nothing),
    DecorationCase("robin150", "+proj=robin +lon_0=150", nothing),
    DecorationCase("merc_reg", "+proj=merc", ((-10, 30), (35, 60))),
    DecorationCase("ortho", "+proj=ortho +lon_0=-20 +lat_0=30", nothing),
    DecorationCase("laea_polar", "+proj=laea +lat_0=90 +lon_0=0", ((-180, 180), (60, 90))),
    DecorationCase("laea_polar_nolimits", "+proj=laea +lat_0=90 +lon_0=0", nothing),
    DecorationCase("moll", "+proj=moll", nothing),
    DecorationCase("ob_tran", "+proj=ob_tran +o_proj=eqc +o_lat_p=35 +o_lon_p=0 +lon_0=20", nothing),
    DecorationCase("zoom3", "+proj=merc", ((10, 12), (45, 47))),
    DecorationCase("stere_polar", "+proj=stere +lat_0=90 +lat_ts=70", ((-180, 180), (50, 90))),
    DecorationCase("lcc", "+proj=lcc +lon_0=-96 +lat_1=33 +lat_2=45", ((-125, -65), (23, 52))),
    DecorationCase("igh", "+proj=igh", nothing),
]

const ISSUE_CASES = DecorationCase[
    DecorationCase("issue234", "+proj=eqearth", ((0, 3), (0, 3))),
    DecorationCase("issue388", "+proj=tmerc +lon_0=15", ((-5, 35), (55, 73))),
]

const MOST_PROJECTION_CASES = DecorationCase[
    DecorationCase("most_" * replace(split(dest)[1][7:end], r"[^a-z0-9_]" => "_"), dest, nothing)
    for dest in MOST_PROJECTIONS
]

const DECORATION_CASES = vcat(BASELINE_CASES, ISSUE_CASES, MOST_PROJECTION_CASES)

decoration_case(cases::Vector{DecorationCase}, name::AbstractString) = cases[findfirst(c -> c.name == name, cases)]

"A figure and a GeoAxis for the case, with coastlines plotted."
function build_case(c::DecorationCase; size = (600, 400), coastlines::Bool = true)
    fig = Figure(; size)
    kw = c.limits === nothing ? (;) : (; limits = c.limits)
    ax = GeoAxis(fig[1, 1]; dest = c.dest, title = c.name, kw...)
    coastlines && lines!(ax, GeoMakie.coastlines())
    return fig, ax
end
