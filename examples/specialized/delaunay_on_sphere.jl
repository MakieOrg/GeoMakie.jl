using DelaunayTriangulation
using GeoMakie, CairoMakie
#
# make cover image #jl
mkpath("covers") #hide
save("covers/$(splitext(basename(@__FILE__))[1]).png", fig) #hide
nothing #hide