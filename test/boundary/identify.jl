# identify: what PROJ tells us about a transformation.

const IDENTIFY_CASES = [
    ("+proj=robin +lon_0=150", :robin, Dict(:lon_0 => 150.0)),
    ("+proj=merc", :merc, Dict()),
    ("EPSG:3857", :merc, Dict()),
    ("EPSG:32633", :utm, Dict(:zone => 33.0)),
    ("ESRI:54030", :robin, Dict()),
    ("+proj=ob_tran +o_proj=moll +o_lon_p=45 +o_lat_p=45 +lon_0=180", :ob_tran, Dict(:o_lon_p => 45.0, :o_lat_p => 45.0, :lon_0 => 180.0)),
    ("+proj=lcc +lat_1=33 +lat_2=45 +lon_0=-96", :lcc, Dict(:lat_1 => 33.0, :lat_2 => 45.0, :lon_0 => -96.0)),
    ("+proj=ortho +lat_0=45 +lon_0=10", :ortho, Dict(:lat_0 => 45.0, :lon_0 => 10.0)),
    ("+proj=stere +lat_0=90", :stere, Dict(:lat_0 => 90.0)),
    ("+proj=laea +lat_0=90 +lon_0=0", :laea, Dict(:lat_0 => 90.0)),
    ("+proj=igh", :igh, Dict()),
    ("+proj=tmerc +lon_0=15", :tmerc, Dict(:lon_0 => 15.0)),
    ("+proj=geos +h=35785831 +lon_0=0", :geos, Dict(:h => 35785831.0)),
    ("+proj=eqearth", :eqearth, Dict()),
    ("+proj=moll +over", :moll, Dict()),
    ("+proj=longlat +datum=WGS84 +type=crs", :longlat, Dict()),
    ("EPSG:4326", :longlat, Dict()),
    ("+proj=aeqd +lat_0=40 +lon_0=-100 +R=6371000", :aeqd, Dict(:lat_0 => 40.0, :lon_0 => -100.0, :R => 6371000.0)),
    ("+proj=wintri +lon_0=-160", :wintri, Dict(:lon_0 => -160.0)),
    ("EPSG:3031", :stere, Dict(:lat_0 => -90.0)),
    ("+proj=webmerc +datum=WGS84", :merc, Dict()),                 # PROJ normalises webmerc to merc
    ("+proj=eqc +lat_ts=30", :eqc, Dict(:lat_ts => 30.0)),
]

@testset "identify" begin
    for (dest, method, params) in IDENTIFY_CASES
        t = GM.create_transform(dest, "+proj=longlat +datum=WGS84")
        id = GM.identify(t)
        @testset "$dest" begin
            @test id !== nothing
            id === nothing && continue
            @test id.method == method
            for (k, v) in params
                @test haskey(id.params, k)
                @test get(id.params, k, NaN) ≈ v atol = 1e-9
            end
            @test id.o_proj == (method == :ob_tran ? :moll : :none)
        end
    end
    t = GM.create_transform("+proj=aeqd +lat_0=40 +lon_0=-100 +R=6371000", "+proj=longlat +datum=WGS84")
    @test GM.identify(t).sphere
    t = GM.create_transform("+proj=merc", "+proj=longlat +datum=WGS84")
    @test !GM.identify(t).sphere
    # an inverted transformation still names the projected side
    @test GM.identify(Makie.inverse_transform(t)).method == :merc
    # things PROJ cannot describe fall to the probe
    t = GM.create_transform("EPSG:22700", "+proj=longlat +datum=WGS84")
    @test GM.identify(t) === nothing
    @test GM.boundary(t, "EPSG:22700") isa GM.SphereRegion
    @test GM.identify(identity) === nothing
end
