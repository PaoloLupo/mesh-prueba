using Format
using Interpolations
using CairoMakie
using ReadVTK

struct Material
    tag::Int
    elastic_modulus::Float64
    poisson_ratio::Float64
    density::Float64
    material_type::Int
end

struct Node
    tag::Int
    x::Float64
    y::Float64
end

struct Element
    name::String
    tag::Int
    node1::Int
    node2::Int
    node3::Int
    node4::Int
    material::Int
    thickness::Float64
end

struct Constraint
    type::String
    nodes::Vector{Int}
end


write_fmt(n::Node) =  format("node {} {} {} \n", n.tag, n.x, n.y)
write_fmt(e::Element) = format("element {} {} {} {} {} {} {} {} \n", e.name, e.tag, e.node1, e.node2, e.node3, e.node4, e.material, e.thickness)
write_fmt(m::Material) = format("material Elastic2D {} {} {} {} {}  \n", m.tag, m.elastic_modulus, m.poisson_ratio, m.density, m.material_type)
write_fmt(c::Constraint) = format("fix2 1 {} {} \n", c.type, join(c.nodes, " "))

function gen_mesh(width::Float64, height::Float64, spacing::Float64)
    if round(width % spacing) != 0 && round(height % spacing) != 0
        error("width must be a multiple of spacing")
    end
    grid_size = width / spacing
    grid_size_j = height / spacing
    nodes::Vector{Node} = []
    tag = 1
    for i in 0:grid_size
        for j in 0:grid_size_j
            push!(nodes, Node(tag, i*spacing, j*spacing))
            tag += 1
        end
    end
    return nodes
end

function gen_elements(element::String,thickness::Float64, material_id::Int, width::Float64, height::Float64, spacing::Float64)
    n_mat_top = height / spacing 
    n_mat_width = width / spacing
    elements::Vector{Element} = []
    tag = 1
    for i in 1:n_mat_width
        for j in 1:n_mat_top
            n1 = (n_mat_top + 1) * (i-1) + j 
            n2 = (n_mat_top + 1) * i + j 
            n3 = (n_mat_top + 1) * i + j + 1
            n4 = (n_mat_top + 1) * (i-1) + j + 1
            push!(elements, Element(element, tag, n1, n2, n3, n4, material_id, thickness))
            tag += 1
        end
    end
    return elements
end

function gen_constraints(width::Float64, height::Float64, spacing::Float64)
    nodes = []
    n_mat_top = height / spacing + 1
    n_mat_width = width / spacing + 1
    for i in 1:n_mat_width
        push!(nodes, (n_mat_top) * (i-1) + 1)
    end
    return Constraint("P", nodes)
end


struct Project
    width::Float64
    height::Float64
    spacing::Float64
    nodes::Vector{Node}
    elements::Vector{Element}
    materials::Material
    constrains::Constraint

    function Project(width::Float64, height::Float64, spacing::Float64, element::String, thickness::Float64, material::Material)
        material_id = material.tag
        self::Project = new(
            width,
            height,
            spacing,
            gen_mesh(width, height, spacing),
            gen_elements(element, thickness, material_id, width, height, spacing),
            material,
            gen_constraints(width, height, spacing)
        )
    end
end

set_theme!(theme_latexfonts())
# plot the mesh
function plot_mesh(project::Project, delta::Matrix{Float64}, scale::Int)
    nodes = project.nodes
    spacing = project.spacing
    height = project.height
    width = project.width

    grid_size_i = Int(width / spacing)+ 1 
    grid_size_j = Int(height / spacing)+ 1

    xyo = Point2f.([n.x for n in nodes], [n.y for n in nodes])
    Δxy = Point2f.(delta[1, :], delta[2, :])
    xyf_scaled = xyo + Δxy * scale

    # Crear una malla regular para el contorno
    x_min, x_max = minimum([n.x for n in nodes]), maximum([n.x for n in nodes])
    y_min, y_max = minimum([n.y for n in nodes]), maximum([n.y for n in nodes])
    x_range = range(x_min, x_max, length=grid_size_i)
    y_range = range(y_min, y_max, length=grid_size_j)

    Δx = delta[1, :]
    Δy = delta[2, :]

    reshape_Δx = reshape(Δx, grid_size_j, grid_size_i)
    reshape_Δy = reshape(Δy, grid_size_j, grid_size_i)

    itp_x = interpolate((y_range, x_range), reshape_Δx, Gridded(Constant()))
    itp_y = interpolate((y_range, x_range), reshape_Δy, Gridded(Constant()))


    data_z_x = [itp_x(j, i) for i in x_range, j in y_range]
    data_z_y = [itp_y(j, i) for i in x_range, j in y_range]

    # Generar la malla de coordenadas
    # mesh_x = repeat(collect(x_range), inner=grid_size_j)
    # mesh_y = repeat(collect(y_range)', outer=grid_size_i)

    # # Convertir mesh_x y mesh_y en vectores planos para contourf
    # flat_mesh_x = vec(mesh_x)
    # flat_mesh_y = vec(mesh_y)

    # Asegurar que data_x, data_y y data_z tengan la misma longitud
    # if length(flat_mesh_x) != length(flat_mesh_y) 
    #     error("Los vectores x, y y z deben tener la misma longitud")
    # end

    fig = Figure( size = (1000, 800))
    gb = fig[1,2] = GridLayout()
    ax1 = Axis(fig[1, 1], aspect=DataAspect())
    ax2 = Axis(gb[1, 1], aspect=DataAspect(), title = "Desplazamiento x")

    scatter!(ax1, xyo, color=:red)
    text!(ax1, xyo, text=string.([n.tag for n in nodes]), color=:red)
    co2 = contourf!(ax2, x_range, y_range , data_z_y, levels=20)
    scatter!(ax1, xyf_scaled, color=:green)
    cb2 = Colorbar(gb[1,2], co2, label = "Desplazamiento x")
    display(fig)
    save("./plots/plot.svg", fig)
end

#UNIDADES
# long = mt, fuerza = kgf
width = 3.0
height = 1.0
spacing = 0.5
element = "SGCMQI"
thickness = 0.14
elastic_2d_material = Material(1, 325000000.0, 0.25, 1800, 0)
project = Project(width, height, spacing, element, thickness, elastic_2d_material)

run(`just create`)
fname = "script/mesh_test.sp"
open(fname, "w") do f
    for n in project.nodes
        write(f, write_fmt(n))
    end
    for e in project.elements
        write(f, write_fmt(e))
    end
    write(f, write_fmt(project.materials))
    write(f, write_fmt(project.constrains))
    write(f, "cload 1 0 2000 1 3\n")
    write(f, "step static 1\n")
    write(f, "set ini_step_size 1\n")
    write(f, "set fixed_step_size true\n")
    write(f, "set output_folder ./results\n")
    write(f, "recorder 1 plain Visualisation U\n")
    write(f, "analyze\n")
    # write(f,"plot type S11\n")
    write(f, "save recorder 1\n")
    write(f, "exit")
end

run(`just`)

vtk_file = VTKFile("./results/R1-U-000002.vtu")

point_data = get_point_data(vtk_file)

datas = point_data["U"]

data = get_data(datas)

nodes_dx = data[1:2, 2:size(data, 2)]


# data = get_data(element_ids)
plot_mesh(project, nodes_dx, 100)

