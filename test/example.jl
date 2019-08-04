using Makie
using GeoInterface, GeoJSON

states = download("https://raw.githubusercontent.com/PublicaMundi/MappingAPI/master/data/geojson/us-states.json")

states_geo = GeoJSON.parse(read(states, String))

features = states_geo.features

props = getproperty.(features, :properties)

densities = getindex.(props, "density")

cr = let ds = sort(densities); (ds[1], ds[end-1]); end

Base.convert(poly::GeoInterface.Polygon, ::Type{Point2f0}) = Point2f0.(poly.coordinates[1])

using PlotUtils

viridis = cgrad(:viridis; scale = :log10)

convert_arguments(::Poly, poly::Polygon) = Point2f0.(poly.coordinates[1])

# convert_arguments(::Poly, mp::MultiPolygon) =


function plo(sc::Scene, poly::Polygon; kwargs...)
    poly!(sc, convert(poly, Point2f0); kwargs...)
end

function plo(sc, poly::MultiPolygon; kwargs...)
    # map(x -> poly!(sc, Point2f0.(x[1]); kwargs...), poly.coordinates)
    data = map(x -> Point2f0.(x[1]), poly.coordinates)
    poly!(sc, data; kwargs...)
    sc
end

Point2{T}(a::Vector{T}) where T = Point2(a[1], a[2])

toPointVecs(poly::Polygon) = Vector{Point2}[Point2.(poly.coordinates[1])]
toPointVecs(mp::MultiPolygon) = map(x -> Point2.(x[1]), mp.coordinates)

sc = Scene()

normalize(val::Real; min = cr[1], max = cr[2]) = (val - min) / (max - min)

for (i, feature) in enumerate(features)
    println(i)
    try
        plo(sc, feature.geometry, color = viridis[normalize(feature.properties["density"])])
    catch err
        @warn("Feature had dimension zero!")
        print(err)
        pop!(sc.plots)
    end
    # display(sc)
end

save("usa-pop-density-log.png", sc)






###############

_getsize(::Polygon) = 1
_getsize(mp::MultiPolygon) = length(mp.coordinates)
_getsize(feature::Feature) = _getsize(f.geometry)
_getsize(fc::FeatureCollection) = sum(_getsize.(fc.features))

cs = Vector{Point2f0}[]
props = Dict[]

for feature in statesgj.features
    coords = toPointVecs(feature.geometry)
    l = length(coords)
    for coord in coords
        push!(cs, coord)
        push!(props, feature.properties)
    end
end

zerodiff(pt::GeometryTypes.Point{2, T}) where {T} = pt[1] != zero(T) && pt[2] != zero(T)

function imprecise(arr)
    dif = Point2{Float32}.(arr) |> diff
    return !any(zerodiff.(dif))
end

inds = findall(imprecise, cs)

if inds != nothing
    @warn("Imprecise points!")
end

deleteat!(cs, inds)
deleteat!(props, inds)
