using GeoMakie, Makie, Proj4, PlotUtils, Glob

# some hacks, PR is up on GLMakie to fix
@eval Makie.GLMakie.GLVisualize begin
    function _default(mesh::TOrSignal{M}, s::Style, data::Dict) where M <: NormalVertexcolorMesh
        @gen_defaults! data begin
            shading = true
            main = mesh
            color = nothing
            shader = GLVisualizeShader(
                "fragment_output.frag", "util.vert", "vertexcolor.vert", "standard.frag",
                view = Dict("light_calc" => light_calc(shading))
            )
        end
    end
end

using ImageMagick: load

# download data - ~140 MB

const DIR = mktempdir()
imgpath = "neo.sci.gsfc.nasa.gov/archive/geotiff/CERES_NETFLUX_M"

cd(DIR) do
    run(`wget --no-parent -r https://$imgpath`)
end

imgdir = joinpath(DIR, imgpath)

img = load(joinpath(imgdir, "CERES_NETFLUX_M_2006-07.TIFF"))

date_regex = r"CERES_NETFLUX_M_(\d{4})-(\d{2}).TIFF"

lons = LinRange(-89, 90, size(img)[1])
lats = LinRange(-179, 180, size(img)[2])

source = WGS84()
dest = Projection("+proj=robin")

points = GeoMakie.transform.(WGS84(), dest, GeoMakie.gridpoints(lats, lons))
faces  = GeoMakie.grid_triangle_faces(lats, lons)

imflip(img) = reverse(vec(transpose(reverse(img; dims=2))))

scene = poly(points, faces; color = imflip(img), show_axis = false);

geoaxis!(scene, -180, 180, -90, 90; crs = (dest = dest,));

titletext = Node("07/2016")

fullsc = title(sc, titletext; fontsize = 40);

save(DataFormat{:PNG}, "d.png", fullsc); lines(rand(10))

record(fullsc, "ceres_netflux.mp4", filter!(x -> uppercase(splitext(x)[2]) == ".TIFF", sort(readdir(imgdir))); framerate = 10) do img

    year, month = match(date_regex, img).captures

    scene.plots[1].color = imflip(ImageMagick.load(joinpath(imgdir,img)))
    titletext[] = "$month/$year"
end

lines(rand(10))
