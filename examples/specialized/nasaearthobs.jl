using GeoMakie, GLMakie
using ProgressMeter # for recording

# acquire data
data_dir = "~/downloads/NASAE"
files = readdir(data_dir; join=true)
filter!(endswith("PNG"), files)
files
path_len = length("/Users/anshul/Downloads/NASAE/MYDAL2_E_CLD_OT_")
dates = map(x -> x[47:end-4], files)


fig = Figure(size = (1000,1000))

ga = GeoAxis(
    fig[1, 1];
    dest = "+proj=moll",

)

ind = Observable(1)

img = lift(ind) do i
    rotr90(FileIO.load(files[i]))
end

on(ind) do i
    ga.title[] = dates[i] * "\n"
end

ga.yticks[] = -90:30:60

# Image does not work with GLMakie in a transformed axis, be sure to use surface!
surface!(ga, LinRange(-180, 180, 3600), LinRange(-90, 90, 1800), ones(3600, 1800); color = img, shading = NoShading)


record(fig, "NASA_Earth_Observations.mp4"; framerate = 60) do io
    @showprogress for i in 1:length(files)
        ind[] = i
        recordframe!(io)
    end
end
