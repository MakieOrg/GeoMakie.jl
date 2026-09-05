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
function build_case(c::DecorationCase; size = (600, 400), coastlines::Bool = true, attrs...)
    fig = Figure(; size)
    kw = c.limits === nothing ? (;) : (; limits = c.limits)
    ax = GeoAxis(fig[1, 1]; dest = c.dest, title = c.name, kw..., attrs...)
    coastlines && lines!(ax, GeoMakie.coastlines())
    Makie.update_state_before_display!(fig)
    return fig, ax
end

"The strings drawn for one family, in drawing order."
drawn_labels(d, family::Symbol) = d.pixels.strings[family]

# Floors: what a case must show at 600 x 400 with the default finder.  Each
# entry maps a case name to a function of the decorations returning a vector
# of (description, pass) pairs.
const SHORT_DECIMAL = r"^\d+(\.\d{1,3})?°[NSEW]?$"
const FLOORS = Dict{String, Function}(
    "robin150" => d -> [
        ("shows 0°", "0°" in drawn_labels(d, :lon)),
        ("shows 180°", "180°" in drawn_labels(d, :lon)),
    ],
    "issue234" => d -> [
        ("x values are exactly 0,1,2,3", d.xtickvalues.values == [0.0, 1.0, 2.0, 3.0]),
        ("y values are exactly 0,1,2,3", d.ytickvalues.values == [0.0, 1.0, 2.0, 3.0]),
        ("x labels", Set(drawn_labels(d, :lon)) == Set(["0°", "1°E", "2°E", "3°E"])),
        ("y labels", Set(drawn_labels(d, :lat)) == Set(["0°", "1°N", "2°N", "3°N"])),
    ],
    "issue388" => d -> [
        ("zero meridian prints 0°", "0°" in drawn_labels(d, :lon)),
        ("no label reads 0.0°", !any(s -> occursin("0.0", s), drawn_labels(d, :lon))),
    ],
    "zoom3" => d -> [
        ("lon labels are short decimals", all(s -> occursin(SHORT_DECIMAL, s), drawn_labels(d, :lon))),
        ("lat labels are short decimals", all(s -> occursin(SHORT_DECIMAL, s), drawn_labels(d, :lat))),
        ("some label carries a decimal", any(s -> occursin('.', s), vcat(drawn_labels(d, :lon), drawn_labels(d, :lat)))),
    ],
)
