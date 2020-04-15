using GeoJSON, GeoMakie, Makie, GeometryBasics, EarCut

goa = download("https://raw.githubusercontent.com/datameet/indian_village_boundaries/master/ga/ga.geojson")

gageo = GeoJSON.parse(read(goa, String))

polys = AbstractPlotting.convert_arguments(Poly, gageo)[1]

meshes = GLNormalMesh[]

sizehint!(meshes, length(polys))

@time for polygon in polys

    triangle_faces = triangulate([polygon])

    v = map(x-> Point3f0(x[1], x[2], 0), polygon)

    push!(meshes, GLNormalMesh(vertices=v, faces=triangle_faces))

end

sc = Scene()
for range in (1:length(meshes)÷4, length(meshes)÷4:2length(meshes)÷4, 2length(meshes)÷4:3length(meshes)÷4, 3length(meshes)÷4:length(meshes))
    mesh!(sc, meshes[range], color=rand(RGBAf0))
end
sc
mesh(meshes; color = 1:length(meshes), colormap = :viridis, scale_plot = false)

poly(rand(Point2f0, 3)) # warm up Makie

@time poly(gageo)
