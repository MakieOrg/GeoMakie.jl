
function sph2plane(p::Point3f)
    return Point3f(
        -1, 
        (atan(p[2], p[1])/(π))*2, 
        -(acos(p[3]/sqrt(sum(p.^2)))/π - 0.5) * 2
    )
end

msh = GeometryBasics.uv_normal_mesh(Sphere(Point3f(0), 1))

using LinearAlgebra
original_positions = msh.position
final_positions = sph2plane.(msh.position)
directions = LinearAlgebra.normalize.(original_positions .- final_positions)
distances = LinearAlgebra.norm.(original_positions .- final_positions)
maximum(distances)
f, a, p = mesh(msh; color = GeoMakie.earth())
p2 = scatter!(a, final_positions; color = :red)
p2.visible = false

distance_slider = Slider(f[2, 1]; range = LinRange(0, maximum(distances), 200), startvalue = 0)
on(distance_slider.value) do val
    new_positions = original_positions .- directions .* val
    new_distances = LinearAlgebra.norm.(original_positions .- new_positions)
    new_positions[new_distances .> distances] .= final_positions[new_distances .> distances]
    _msh = p.args[1][]
    getfield(_msh, :simplices).position .= new_positions
    p.args[1][] = _msh
end

record(f, "test.mp4", LinRange(0, maximum(distances), 200); framerate = 30) do τ
    set_close_to!(distance_slider, τ)
end