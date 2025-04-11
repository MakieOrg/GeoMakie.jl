#=
# GeoTicks

This file contains the implementation of geographic tickfinders.
=#


"""
    geomakie_get_ticklabels(tickfinder, tickformatter, vals, dim)

Find the ticklabels for the given values and return a `Vector{String}` of the same length as `vals`.

This method is meant to be extended for different `tickfinder` and `tickformatter` combinations,
but falls back to `Makie.get_ticklabels(tickformatter, vals)` if no other method is available.
"""
function geomakie_get_ticklabels(tickfinder, tickformatter, vals, dim)
    return Makie.get_ticklabels(tickformatter, vals)
end


function geomakie_get_tickvalues(tickfinder, dmini, dmaxi, mini, maxi)
    return Makie.get_tickvalues(tickfinder, identity, mini, maxi)
end

"""
    GeoTicks(; multiple = 12, threshold = 3, alternate_tickfinder = Makie.WilkinsonTicks(5; k_min = 3))

A tick finder optimized for geographic axes.  

## Keyword arguments

$(Makie.DocStringExtensions.FIELDS)

## Behaviour

The tickfinder has three regimes, defined by the distance between the minimum and maximum values.

- ``|vmax - vmin| < threshold``: Use the `alternate_tickfinder` to find ticks.
- ``!(\\operatorname{isfinite}(vmin) && \\operatorname{isfinite}(vmax))``: `-dvmin:30:dvmax`
- All other cases: Find ticks in the range `mini:step:maxi`, where `step` is the closest multiple of `(maxi-mini)/multiple` to `dmaxi`.
"""
Base.@kwdef struct GeoTicks
    "The number of ticks to keep spaced, with a minimum spacing of 1."
    multiple::Int = 12
    "The minimum distance between ticks, before the `alternate_tickfinder` is used."
    threshold::Float64 = 3
    "The tick finder to use if the range is not large enough to keep the `multiple` ticks."
    alternate_tickfinder = Makie.WilkinsonTicks(5; k_min = 3)
end # This struct is not used yet - everything goes through `geoticks`.

# Satisfy the Makie tick interface
function Makie.get_tickvalues(ticks::GeoTicks, transform_func, vmin, vmax)
    # NOT IMPLEMENTED YET - needs access to the geographic ticks somehow.
end

# Below is the actual implementation for the struct described above:

"""
    geoticks(dmini, dmaxi, mini, maxi; multiple, threshold, alternate_tickfinder)

A tick finder optimized for geographic axes.  

## Keyword arguments

- `multiple::Int = 12`: The number of ticks to keep spaced, with a minimum spacing of 1.
- `threshold::Float64 = 3`: The minimum distance between ticks, before the `alternate_tickfinder` is used.
- `alternate_tickfinder = Makie.WilkinsonTicks(5; k_min = 3)`: The tick finder to use if the range is not large enough to keep the `multiple` ticks.

## Behaviour

The tickfinder has three regimes, defined by the distance between the minimum and maximum values.

- ``|vmax - vmin| < threshold``: Use the `alternate_tickfinder` to find ticks.
- ``!(\\operatorname{isfinite}(vmin) && \\operatorname{isfinite}(vmax))``: `-dvmin:30:dvmax`
- All other cases: Find ticks in the range `mini:step:maxi`, where `step` is the closest multiple of `(maxi-mini)/multiple` to `dmaxi`.
"""
function geoticks(dmini, dmaxi, mini, maxi; multiple = 12, threshold = 3, alternate_tickfinder = Makie.WilkinsonTicks(5; k_min = 3))
    if isfinite(mini) && isfinite(maxi)
            # If the range is sufficiently small, use WilkinsonTicks    
            if abs(maxi - mini) < threshold
                return Makie.get_tickvalues(alternate_tickfinder, identity, mini, maxi)
            else # there's enough space to use a kind of multiples tick
                mini, maxi = min(maxi, mini), max(maxi, mini)
                # Find the closest multiple of `(maxi-mini)/multiple` to `dmaxi`.
                # This is the step size for the ticks.
                step = max(1, closest_multiple((maxi - mini) / multiple, dmaxi))
                return dmini:step:dmaxi
            end
    else # if the range is infinite, we need to place ticks at all lon/lat combinations.
        return dmini:30:dmaxi
    end
end

"""
    closest_multiple(M, N)

Find the closest integer multiple of `M` to `N`.
"""
function closest_multiple(M, N)
    # Step 1: Find the quotient
    quotient = N ÷ M

    # Step 2: Get the multiple of M just less than or equal to N
    lower_multiple = N ÷ quotient

    # Step 3: Check if the next multiple is closer
    upper_multiple = N ÷ (quotient + 1)

    # Determine which multiple is closer to N
    if abs(N - lower_multiple) <= abs(N - upper_multiple)
        return lower_multiple
    else
        return upper_multiple
    end
end
