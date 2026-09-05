# reftests.jl -- every render of the gallery as a ReferenceTests block.  Included
# by record.jl through `@include_reference_tests`, which records each block's
# figure at px_per_unit = 1 under its name.

for (name, render) in all_renders()
    @eval @reference_test $name $render()
end
