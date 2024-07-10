
############################################################
#                                                          #
#     Splitting Of LineString / coast lines                #
#                                                          #
############################################################

#`LineSplitting` module defines a `split` method for vectors of `LineString` objects.
#
#This is needed to fix e.g. coast line displays when lon_0 is not 0 but cutting polygons at lon_0+-180.

"""
    coastlines(ga::GeoAxis)
Split coastline contours when ga.dest includes a "+lon_0" specification.
"""
coastlines(ga::GeoAxis)=split(coastlines(),ga)

module LineSplitting

	import GeometryBasics
	import GeoInterface as GI, GeometryOps as GO
	import Makie: Observable, @lift, lift
	import GeoMakie: GeoAxis

    # Since we're overriding Base.split, we must import it
	import Base.split

	###
	function split(tmp::GeometryBasics.LineString, lon0::Real)
		# lon1 is the "antimeridian" relative to the central longitude `lon0`
		lon1 = lon0 < 0.0 ? lon0+180 : lon0-180 
		# GeometryBasics handles line nodes as polygons.
		linenodes = GeometryBasics.coordinates(tmp)  # get coordinates of line nodes
		# Find nodes that are on either side of lon0
		cond = GI.x.(linenodes) .>= lon1
		# Find interval starts and ends
		end_cond = diff(cond)  # nonzero values denote ends of intervals
		end_inds = findall(!=(0), end_cond)
		start_inds = [firstindex(linenodes);  end_inds .+ 1]  # starts of intervals
		end_inds = [end_inds; lastindex(linenodes)]  # ends of intervals
		# do the splitting (TODO: this needs to inject a point at the appropriate place)
		split_coords = @. view((linenodes,), UnitRange(start_inds, end_inds))  # For each start-end pair, get those coords
		# reconstruct lines from points
		split_lines = GeometryBasics.MultiLineString(GeometryBasics.LineString.(split_coords))
	end

	function split(tmp::AbstractVector{<:GeometryBasics.LineString}, lon0::Real)
		[split(a, lon0) for a in tmp]
	end

	###
	split(tmp::GeometryBasics.LineString,dest::Observable) = @lift(split(tmp, $(dest)))

	function split(tmp::AbstractVector{<:GeometryBasics.LineString}, dest::Observable)
		@lift([split(a, $(dest)) for a in tmp])
	end

	###
	split(tmp::GeometryBasics.LineString, ax::GeoAxis) = split(tmp, ax.dest)
	
	function split(tmp::AbstractVector{<:GeometryBasics.LineString}, ax::GeoAxis)
		lift(ax.scene, ax.dest) do dest
			[split(a, dest) for a in tmp]
		end
	end
	
	###
	function split(tmp::GeometryBasics.LineString, dest::String)
		if occursin("+lon_0",dest)
			tmp1=split(dest)
			tmp2=findall(occursin.(Ref("+lon_0"),tmp1))[1]
			lon_0=parse(Float64,split(tmp1[tmp2],"=")[2])
			split(tmp,lon_0)
		else
			tmp
		end
	end

	function split(tmp::AbstractVector{<:GeometryBasics.LineString},dest::String)
		[split(a,dest) for a in tmp]
	end

	###

#	split(tmp::Vector,dest::Observable) = @lift(split(tmp, $(dest)))
	split(tmp::Observable,dest::Observable) = @lift(split($(tmp), $(dest)))
	split(tmp::Observable,dest::String) = @lift(split($(tmp), (dest)))
	
end
