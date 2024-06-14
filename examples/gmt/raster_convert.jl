using GMT, Rasters
import GeoFormatTypes as GFT

function trunc_string_at_null(s::String)
    isempty(s) && return s
    idx = findfirst(isequal('\0'), s)
    isnothing(idx) && return s
    return s[1:idx-1]
end

function _get_crs(G::GMT.GMTgrid)
    epsg = G.epsg
    epsg ≤ 0 || return GFT.EPSG(epsg)
    wkt = trunc_string_at_null(G.wkt)
    isempty(wkt) || return GFT.WellKnownText(GFT.CRS(), wkt)
    proj4 = trunc_string_at_null(G.proj4)
    isempty(proj4) || return GFT.ProjString(proj4)
    if G.geog == -1 || G.geog == 1 # yes, is geographic coords
        GFT.EPSG(4326) # default to WGS84
    elseif G.geog == 0 # unknown, not geographic coords
        GFT.EPSG(0) # default to UTM
    end
end

function _get_metadata(G::GMT.GMTgrid)
    
end

function Base.convert(::Type{Raster}, G::GMT.GMTgrid{T, N}) where {T, N}
    crs = _get_crs(G)
    metadata = _get_metadata(G)
    missingval = G.nodata
    sampling = nothing # get this from G.registration
    xs = Rasters.X(G.x)
    ys = Rasters.Y(G.y)
    if N == 3
        # do something with vs
    end
    zs = G.z # reorder!
    
    dims = (xs, ys)
    if N == 3
        dims = (xs, ys, vs)
    end
    
    return Raster(
        zs; 
        dims, crs, metadata, missingval,
    )
end

