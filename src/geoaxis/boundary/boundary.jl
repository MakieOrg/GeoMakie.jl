#=
# The boundary of a transformation

`boundary(t, dest)` is the one entry point the axis uses: the domain of `t` as
a region on the sphere, from the analytic table when `identify` recognises the
projection and from the probe otherwise.  A user outline overrides both.
=#

"How many boundaries have been built; the axis builds exactly one per transform."
const BOUNDARY_BUILDS = Ref(0)

"""
    boundary(t, dest; outline = nothing) -> SphereRegion

The domain of the transformation `t` (lon/lat → `dest`).  `outline` may be a
vector of lon/lat points (a closed polygon on the sphere) or `:dest => points`
in projected coordinates, and then replaces the projection's own domain.
"""
function boundary(t, dest; outline = nothing)
    BOUNDARY_BUILDS[] += 1
    outline === nothing || return outline_region(t, outline)
    return build_boundary(t, dest)
end

function build_boundary(t::Proj.Transformation, dest)
    id = identify(t)
    if id === nothing && dest isa AbstractString && occursin("+proj=", dest)
        id = parse_proj_string(dest)
        id.method == :unknown && (id = nothing)
    end
    r = analytic_region(id)
    r === nothing && return probe(t)
    return r
end
build_boundary(t, dest) = probe(t)

"""
    outline_region(t, outline) -> SpherePolygon

A user outline as a region: lon/lat vertices joined by great arcs, the inside
taken to be the side containing the vertices' mean direction.
"""
function outline_region(t, outline)
    pts = outline isa Pair ? _inverse_points(t, outline) : outline
    xyz = Vec3d[lonlat_to_xyz(p[1], p[2]) for p in pts]
    length(xyz) >= 3 || throw(ArgumentError("an outline needs at least three vertices"))
    norm(xyz[1] - xyz[end]) < 1e-12 && pop!(xyz)
    arcs = CircleArc[]
    for i in eachindex(xyz)
        p, q = xyz[i], xyz[mod1(i + 1, length(xyz))]
        angular_distance(p, q) < 1e-12 && continue
        push!(arcs, great_arc(p, q))
    end
    inside = _unit3(sum(xyz))
    return SpherePolygon(arcs, inside)
end

function _inverse_points(t, outline::Pair)
    outline.first == :dest || throw(ArgumentError("outline pair must be `:dest => points`"))
    inv = _inverse_of(t)
    inv === nothing && throw(ArgumentError("cannot invert the transform to interpret a `:dest` outline"))
    return [Makie.apply_transform(inv, Point2d(p[1], p[2])) for p in outline.second]
end
