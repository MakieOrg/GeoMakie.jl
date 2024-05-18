
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

	using GeometryBasics: LineString
	using Makie: Observable, @lift
    # Since we're overriding Base.split, we must import it
	import Base.split
	
	function regroup(tmp::Vector)
		coastlines_custom=LineString[]
		println(typeof(coastlines_custom))
		for ii in 1:length(tmp)
			push!(coastlines_custom,tmp[ii][:]...)
		end
		coastlines_custom
	end
	
	function split(tmp::Vector{<:LineString}, lon0::Real)
		[split(a,lon0) for a in tmp]
	end
	
	function split(tmp::LineString, lon0::Real)
		lon0<0.0 ? lon1=lon0+180 : lon1=lon0-180 
		np=length(tmp)
		tmp2=fill(0,np)
		for p in 1:np
			tmp1=tmp[p]
			tmp2[p]=maximum( [(tmp1[1][1]<=lon1)+2*(tmp1[2][1]>=lon1) , (tmp1[2][1]<=lon1)+2*(tmp1[1][1]>=lon1)] )
		end
		if !any(==(3), tmp2) # no value in tmp2 is equal to 3
			[tmp]
		else # some value in tmp2 is equal to 3
			jj=[0;findall(tmp2.==3)...;np+1]
			[LineString(tmp[jj[ii]+1:jj[ii+1]-1]) for ii in 1:length(jj)-1]
		end
	end

	split(tmp::Vector,dest::Observable) = @lift(split(tmp, $(dest)))
	split(tmp::Observable,dest::Observable) = @lift(split($(tmp), $(dest)))
	split(tmp::Observable,dest::String) = @lift(split($(tmp), (dest)))

	function split(tmp::Vector{<:LineString},dest::String)
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
