
############################################################
#                                                          #
#     Splitting Of LineString / coast lines                #
#                                                          #
############################################################

#`LineSplitting` module defines a `split` method for vectors of `LineString` objects.
#
#This is needed to fix e.g. coast line displays when lon_0 is not 0 but cutting polygons at lon_0+-180.

Base.split(tmp::Vector{<:LineString},ga::GeoAxis) = @lift(split(tmp,$(ga.dest)))

"""
    coastlines(ga::GeoAxis)
Split coastline contours when ga.dest includes a "+lon_0" specification.
"""
coastlines(ga::GeoAxis)=split(coastlines(),ga)

module LineSplitting

	import GeometryBasics
	import Makie: Observable, @lift
    # Since we're overriding Base.split, we must import it
	import Base.split
	
	function regroup(tmp::Vector)
		coastlines_custom=GeometryBasics.LineString[]
		println(typeof(coastlines_custom))
		for ii in 1:length(tmp)
			push!(coastlines_custom,tmp[ii][:]...)
		end
		coastlines_custom
	end
	
	function split(tmp::Vector{<:GeometryBasics.LineString}, lon0::Real)
		[split(a,lon0) for a in tmp]
	end
	
	getlon(p::GeometryBasics.Point) = p[1]

	function split(tmp::GeometryBasics.LineString, lon0::Real)
		lon0<0.0 ? lon1=lon0+180 : lon1=lon0-180 

		linenodes = GeometryBasics.coordinates(tmp)  # get coordinates of line nodes
		# Find nodes that are on either side of lon0
		cond = getlon.(linenodes) .>= lon1
		# Find interval starts and ends
		end_cond = diff(cond)  # nonzero values denote ends of intervals
		end_inds = findall(!=(0), end_cond)
		start_inds = [firstindex(linenodes);  end_inds .+ 1]  # starts of intervals
		end_inds = [end_inds; lastindex(linenodes)]  # ends of intervals
		# do the splitting
		split_coords = view.(Ref(linenodes), UnitRange.(start_inds, end_inds))  # For each start-end pair, get those coords
		# reconstruct lines from points
		split_lines = GeometryBasics.LineString.(split_coords) 
	end

	split(tmp::Vector,dest::Observable) = @lift(split(tmp, $(dest)))
	split(tmp::Observable,dest::Observable) = @lift(split($(tmp), $(dest)))
	split(tmp::Observable,dest::String) = @lift(split($(tmp), (dest)))

	function split(tmp::Vector{<:GeometryBasics.LineString},dest::String)
		if occursin("+lon_0",dest)
			tmp1=split(dest)
			tmp2=findall(occursin.(Ref("+lon_0"),tmp1))[1]
			lon_0=parse(Float64,split(tmp1[tmp2],"=")[2])
			regroup(split(tmp,lon_0))
		else
			tmp
		end
	end

end
