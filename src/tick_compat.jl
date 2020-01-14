
"""
    WilkinsonTicks(; kwargs...)

This is basically Wilkinson's ad-hoc scoring method that tries to balance
tight fit around the data, optimal number of ticks, and simple numbers.

This is the function which Plots.jl and Makie.jl use by default.

## Keyword Arguments

$(FIELDS)

## Mathematical details

Wilkinson’s optimization function is defined as the sum of three
components. If the user requests m labels and a possible labeling has
k labels, then the components are `simplicity`, `coverage` and `granularity`.

These components are defined as follows:
```math
\\begin{aligned}
  &\\text{simplicity} = 1 - \\frac{i}{|Q|} + \\frac{v}{|Q|}\\\\
  &\\text{coverage}   = \\frac{x_{max} - x_{min}}{\\mathrm{label}_{max} - \\mathrm{label}_{min}}\\\\
  &\\text{granularity}= 1 - \\frac{\\left|k - m\\right|}{m}
\\end{aligned}
```

and the variables here are:

*  `q`: element of `Q`.
*  `i`: index of `q` in `Q`.
*  `v`: 1 if label range includes 0, 0 otherwise.

"""
Base.@kwdef struct WilkinsonTicks <: MakieLayout.Ticks

    "Determines whether to extend tick computation.  Defaults to `false`."
    extend_ticks::Bool = false
    "True if no ticks should be outside `[x_min, x_max]`.  Defaults to `true`."
    strict_span::Bool = true

    """
    A distribution of nice numbers from which labellings are sampled.
    Stored in the form `(number, score)`.
    """
    Q = [(1.0,1.0), (5.0, 0.9), (2.0, 0.7), (2.5, 0.5), (3.0, 0.2)]

    "The minimum number of ticks."
    k_min::Int   = 2
    "The maximum number of ticks."
    k_max::Int   = 10
    "The ideal number of ticks."
    k_ideal::Int = 5

    """
    Encourages returning roughly the number of labels requested.
    """
    granularity_weight::Float64 = 1/4

    """
    Encourages nicer labeling sequences by preferring step sizes that
    appear earlier in Q.

    Also rewards labelings that include 0 as a way to ground the sequence.
    """
    simplicity_weight::Float64 = 1/6

    """
    Encourages labelings that do not extend far beyond
    the range of the data, penalizing unnecessary whitespace.
    """
    coverage_weight::Float64 = 1/3

    """
    Encourages labellings to produce nice ranges.
    """
    niceness_weight::Float64 = 1/4

end


function MakieLayout.compute_tick_values(ticks::WilkinsonTicks, vmin, vmax, pxwidth)
    # Main.@infiltrate
    return AbstractPlotting.PlotUtils.optimize_ticks(
        vmin, vmax;
        extend_ticks = ticks.extend_ticks,
        Q = ticks.Q,
        k_min = ticks.k_min,
        k_max = ticks.k_max,
        k_ideal = ticks.k_ideal,
        granularity_weight = ticks.granularity_weight,
        simplicity_weight = ticks.simplicity_weight,
        coverage_weight = ticks.coverage_weight,
        niceness_weight = ticks.niceness_weight,
        strict_span = ticks.strict_span
    )[1]
end

function MakieLayout.get_tick_labels(ticks::WilkinsonTicks, tickvalues)

    # take difference of first two values (they are equally spaced anyway)
    dif = diff(view(tickvalues, 1:2))[1]
    # whats the exponent of the difference?
    expo = log10(dif)

    # all difs bigger than one should be integers with the normal step sizes
    dif_is_integer = dif > 0.99999
    # this condition means that the exponent is close to an integer, so the numbers
    # would have a trailing zero with the safety applied
    exp_is_integer = isapprox(abs(expo) % 1 - 1, 0, atol=1e-6)

    safety_expo_int = if dif_is_integer || exp_is_integer
        Int(round(expo))
    else
        safety_expo_int = Int(round(expo)) - 1
    end
    # for e.g. 1.32 we want 2 significant digits, so we invert the exponent
    # and set precision to 0 for everything that is an integer
    sigdigits = max(0, -safety_expo_int)

    strings = map(tickvalues) do v
        Formatting.format(v, precision=sigdigits)
    end
end
