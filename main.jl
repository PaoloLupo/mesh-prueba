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

struct CLoad 
    tag::Int
    magnitude::Float64
    direction::Int
    nodes::Vector{Int}
end


write_fmt(n::Node) =  format("node {} {} {} \n", n.tag, n.x, n.y)
write_fmt(e::Element) = format("element {} {} {} {} {} {} {} {} \n", e.name, e.tag, e.node1, e.node2, e.node3, e.node4, e.material, e.thickness)
write_fmt(m::Material) = format("material Elastic2D {} {} {} {} {} \n", m.tag, m.elastic_modulus, m.poisson_ratio, m.density, m.material_type)
write_fmt(c::Constraint) = format("fix2 1 {} {} \n", c.type, join(c.nodes, " "))
write_fmt(cl::CLoad) = format("cload {} 0 {} {} {} \n", cl.tag, cl.magnitude, cl.direction, join(cl.nodes, " ") )

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

function gen_cloads(width::Float64, height::Float64, spacing::Float64, stories::Int, cloads::Vector{Float64})
    vcloads = []
    tag = 1
    n_mat_top = height / spacing + 1
    n_mat_width = width / spacing + 1
    space = height / spacing / stories  
    for i in 1:stories
        initial_node = n_mat_top - (i-1) * space
        nodes = []
        for j in 1:n_mat_width
            push!(nodes, initial_node + (j-1)*n_mat_top )
        end
        push!(vcloads, CLoad(tag, cloads[i], 1, nodes))
        tag += 1
    end
    return vcloads
end

struct Project
    width::Float64
    height::Float64
    spacing::Float64
    nodes::Vector{Node}
    elements::Vector{Element}
    materials::Material
    constrains::Constraint
    loads::Vector{CLoad}

    function Project(width::Float64, height::Float64, num_stories::Int, cloads::Vector{Float64}, spacing::Float64, element::String, thickness::Float64, material::Material)
        material_id = material.tag
        self::Project = new(
            width,
            height,
            spacing,
            gen_mesh(width, height, spacing),
            gen_elements(element, thickness, material_id, width, height, spacing),
            material,
            gen_constraints(width, height, spacing),
            gen_cloads(width, height, spacing, num_stories, cloads)
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

    x_min, x_max = minimum([n.x for n in nodes]), maximum([n.x for n in nodes])
    y_min, y_max = minimum([n.y for n in nodes]), maximum([n.y for n in nodes])
    x_range = range(x_min, x_max, length=grid_size_i)
    y_range = range(y_min, y_max, length=grid_size_j)

    Δx = delta[1, :]
    Δy = delta[2, :]
    max_Δx = maximum(abs.(Δx))
    max_Δy = maximum(abs.(Δy))

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
    fig = Figure( size = (1000, 500))
    gbx = fig[1,3] = GridLayout()
    gby = fig[1,4] = GridLayout()
    ax1 = Axis(fig[1, 1], aspect=DataAspect(), title = "Estructura indeformada")
    ax2 = Axis(fig[1, 2], aspect=DataAspect(), title = "Estructura deformada")
    ax3 = Axis(gbx[1, 1], aspect=DataAspect(), title = format("Desplazamiento x {:3f}", max_Δx))
    ax4 = Axis(gby[1, 1], aspect=DataAspect(), title = format("Desplazamiento y {:3f}", max_Δy))

    scatter!(ax1, xyo, color=:gray)
    for e in project.elements
        elem_nodes = (e.node1, e.node2, e.node3, e.node4)
        coord_pol_elem = xyo[[elem_nodes...]]
        coord_pol_elem_scaled = xyf_scaled[[elem_nodes...]]
        poly!(ax1, coord_pol_elem, color=:transparent, strokecolor=:black, strokewidth=2)
        poly!(ax2, coord_pol_elem, color=:transparent, strokecolor=:gray, strokewidth=1, linestyle=:dash)
        poly!(ax2, coord_pol_elem_scaled, color=:transparent, strokecolor=:black, strokewidth=2)
    end
    co2 = contourf!(ax3, x_range, y_range , data_z_x, levels=20)
    co3 = contourf!(ax4, x_range, y_range , data_z_y, levels=20)
    scatter!(ax2, xyf_scaled, color=:black)
    text!(ax1, xyo, text=string.([n.tag for n in nodes]), color=:black)
    # text!(ax2, xyf_scaled, text=string.([n.tag for n in nodes]), color=:black)
    Colorbar(gbx[1,2], co2)
    Colorbar(gby[1,2], co3)
    display(fig)
    save(format("./plots/mesh{}.svg",spacing), fig)
end

#UNIDADES
# long = mt, fuerza = kgf
width = 3.0
height = 12.0
spacing = 1.0  
num_stories = 4
element = "SGCMQI"
thickness = 0.14
loads = [22850.0, 47420.0, 63800.0, 72000.0]
n_spacing = round(width/spacing + 1)
c_loads = [i/n_spacing for i in loads]
elastic_2d_material = Material(1, 325000000.0, 0.25, 1800, 0)
project = Project(width, height, num_stories, c_loads, spacing, element, thickness, elastic_2d_material)

# run(`just create`) 
fname = "script/mesh_test.sp"
open(fname, "w") do f
    for n in project.nodes
        write(f, write_fmt(n))
    end
    for e in project.elements
        write(f, write_fmt(e))
    end
    for l in project.loads
        write(f, write_fmt(l))
    end
    write(f, write_fmt(project.materials))
    write(f, write_fmt(project.constrains))
    # write(f, "fixedlength2d 2 3 6\n")
    # write(f, "fixedlength2d 3 5 9\n")
    # write(f, "fixedlength2d 4 9 12\n")
    write(f, "step static 1\n")
    write(f, "set ini_step_size 1\n")
    write(f, "set linear_system true\n")
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
plot_mesh(project, nodes_dx, 1)