module LineSplitting

	import GeoMakie.LineString

	function LineRegroup(tmp::Vector)
		coastlines_custom=LineString[]
		for ii in 1:length(tmp)
			push!(coastlines_custom,tmp[ii][:]...)
		end
		coastlines_custom
	end
	
	function LineSplit(tmp::Vector,lon0=-160.0)
		[LineSplit(a,lon0) for a in tmp]
	end
	
	function LineSplit(tmp::LineString,lon0=-160.0)
		lon0<0.0 ? lon1=lon0+180 : lon1=lon0-180 
		np=length(tmp)
		tmp2=fill(0,np)
		for p in 1:np
			tmp1=tmp[p]
			tmp2[p]=maximum( [(tmp1[1][1]<=lon1)+2*(tmp1[2][1]>=lon1) , (tmp1[2][1]<=lon1)+2*(tmp1[1][1]>=lon1)] )
		end
		if sum(tmp2.==3)==0
			[tmp]
		else
			jj=[0;findall(tmp2.==3)...;np+1]
			[LineString(tmp[jj[ii]+1:jj[ii+1]-1]) for ii in 1:length(jj)-1]
		end
		
	#old method (simpler but insufficient)
	#		tmp3a=LineString([tmp[ii][1] for ii in findall(tmp2.==1)])
	#		tmp3b=LineString([tmp[ii][1] for ii in findall(tmp2.==2)])
	#		[tmp3a,tmp3b]
	end
end
