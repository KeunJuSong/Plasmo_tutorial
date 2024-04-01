using Plasmo
using Ipopt, Gurobi, JuMP
using MadNLP, MadNLPHSL

import HSL_jll

include("utils.jl")

path = "/home/kjsong/workspace/Plasmo_tutorial/data/pglib_opf_case9241_pegase.m"
# "/home/kjsong/workspace_skj/Plasmo_tutorial/data/pglib_opf_case9241_pegase.m"
# /home/kjsong/workspace/Plasmo_tutorial/data/pglib_opf_case9241_pegase.m
args = get_data(path)


# 뭐에 대한 parameter?
gamma = 1e5 # the regularization parameter of voltage angle difference. 
oms = [1, 4, 7]
max_iter = 1000
scl = 1

g = args[:g] # LightGraphs type
N_buses = LightGraphs.nv(g) # get the number of nodes in graph.
N_lines = LightGraphs.ne(g) # get the number of edges in graph.
y = args[:y] # get the Y bus matrix 
del = args[:del] # get the voltage angle difference lower bound matrix

powergrid = Plasmo.OptiGraph()

# 여기가 MAIN PART. i.e., power network 최적화 문제를 graph로 어떻게 모델링 하는지.
Plasmo.@optinode(powergrid, buses[1:N_buses]) # create node buses
Plasmo.@optinode(powergrid, lines[1:N_lines]) # create transmission lines <= 일반적으로 power network의 line은 edge로 생각하겠지만, 여기서는 최적화 문제를 graph로 표현할때 line에 대한 variable (branch power flow)이 있기 때문에 node로 모델링.

# 각 bus별로 from bus인지 to bus인지 각 line에 따라 정해져 있는데, 이를 bus 관점에서 line을 바라보는, 즉 어떤 line이 bus에 대해서 들어오는 line인지 아님 나가는 line인지를 볼 수 있는 dict.
node_map_in = Dict((bus, Plasmo.OptiNode[]) for bus in buses) 
node_map_out = Dict((bus, Plasmo.OptiNode[]) for bus in buses)

line_map = Dict() # 각 transmission line에 대해 연결된 bus pair; element type이 graph의 node로 모델링된 최적화 변수들임.
edge_map = Dict() # 각 transmission line이 어떤 bus pair에 해당되어 있는지에 대한 dict.
B = Dict() # 각 transmission line의 susceptance
angle_rate = Dict() # 각 transmission line의 bus pair에 대한 voltage angle difference limit
ngens = Dict()
load_map = Dict()

for (i,edge) in enumerate(LightGraphs.edges(g))
    line = lines[i]
    v_from = edge.src # <= LightGraphs package의 method: edge에 해당하는 node들 중 source node 불러오기
    v_to = edge.dst # <= LightGraphs package의 method: edge에 해당하는 node들 중 destination node 불러오기

    edge_map[(v_from, v_to)] = line

    B[line] = y[v_from,v_to]
    angle_rate[line] = del[v_from,v_to]

    bus_from = buses[v_from]
    bus_to = buses[v_to]
    bus_vec = [bus_from, bus_to] # vector form
    line_map[line] = bus_vec 

    push!(node_map_in[bus_to], line)
    push!(node_map_out[bus_from], line)
end

for i = 1:N_buses
    neighs = LightGraphs.neighbors(g,i)
    bus = buses[i]

    ngens[bus] = args[:ng][i] # 이건 뭘 의미하는건지...
    load_map[bus] = args[:sd][i] # Bus 별 Pd 값 저장

    # Plasmo OptiNode(i.e., power network의 bus 및 line)에 변수 및 제약조건 설정에 필요한 값 할당.
    bus.ext[:c1] = args[:c1][i] 
    bus.ext[:c2] = args[:c2][i]
    bus.ext[:va_lower] = args[:val][i]
    bus.ext[:va_upper] = args[:vau][i]
    bus.ext[:gen_lower] = args[:sl][i]
    bus.ext[:gen_upper] = args[:su][i]
end

for line in lines
    bus_from = line_map[line][1]
    bus_to = line_map[line][2]
    Plasmo.@variable(line, va_i, start=0)
    Plasmo.@variable(line, va_j, start=0)
    Plasmo.@variable(line, flow, start=0) # i.e., branch power flow
    Plasmo.@constraint(line, flow==B[line]*(va_i - va_j)) # power flow equation constraint.
    delta = angle_rate[line]
    Plasmo.@constraint(line, delta <= (va_i - va_j) <= -delta) # voltage angle difference constraint.
    Plasmo.@objective(line, Min, 1/4*gamma*(va_i - va_j)^2) # penalty term of objective function (18a).
end

# dual_links = Plasmo.LinkConstraintRef[] # link constraints들을 저장하고 관리할 수 있는 storage 개념의 리스트.
# primal_links = Plasmo.LinkConstraintRef[]
for (i,bus) in enumerate(buses)
    va_lower = bus.ext[:va_lower]
    va_upper = bus.ext[:va_upper]

    gen_lower = bus.ext[:gen_lower]
    gen_upper = bus.ext[:gen_upper]

    Plasmo.@variable(bus, va_lower <= va <= va_upper, start=0) # voltage angle variable.
    # TODO: 아래 변수가 의미하는 것이 뭔지 이해 필요!
    # 일단 active power인 건 알겠음.. => Gen이 있으면 3종류의 active power, 없으면 2종류의 active power?
    Plasmo.@variable(bus, P[j=1:ngens[bus]], start=0)
    for j=1:length(P)
        Plasmo.set_lower_bound(P[j],gen_lower[j])
        Plasmo.set_upper_bound(P[j],gen_upper[j])
    end
    # NOTE: 위에 loop에서 transmission line node에 대한 변수 및 제약 조건을 설정해줬기 때문에, 자동으로 node_map_in에 있는 value 값들도 동기화가 됨!
    lines_in = node_map_in[bus]
    lines_out = node_map_out[bus]

    # NOTE: DC/AC OPF에서의 link constraints 선언 방식!! <= 다른 방식은 없는지?
    Plasmo.@variable(bus, power_in[1:length(lines_in)])
    Plasmo.@variable(bus, power_out[1:length(lines_out)])

    for (j,line) in enumerate(lines_in)
        link = Plasmo.@linkconstraint(powergrid, bus[:power_in][j] == line[:flow])
        # push!(dual_links,link)
    end
    for (j,line) in enumerate(lines_out)
        link = Plasmo.@linkconstraint(powergrid, bus[:power_out][j] == line[:flow])
        # push!(dual_links,link)
    end


    ## Julia error: sum of the empty vector is not zero...
    if typeof(power_in) == Vector{Any}
        # bus[:power_in] = 0
        power_in = 0
    end
    if typeof(power_out) == Vector{Any}
        # bus[:power_out] = 0
        power_out = 0
    end
    Plasmo.@constraint(bus, power_balance, sum(bus[:P][j] for j=1:ngens[bus]) + sum(power_in) - sum(power_out) - load_map[bus] == 0) # power balance equation constraint.
    Plasmo.@objective(bus, Min, sum(bus.ext[:c1][j]*bus[:P][j] + bus.ext[:c2][j]*bus[:P][j]^2 for j=1:ngens[bus]))
end

Plasmo.@linkconstraint(powergrid, line_coupling_i[line = lines], line[:va_i] == line_map[line][1][:va])
Plasmo.@linkconstraint(powergrid, line_coupling_j[line = lines], line[:va_j] == line_map[line][2][:va])
# primal_links = [line_coupling_i.data ; line_coupling_j.data]


## SOLVE IN THE CENTRALIZED WAY.
Plasmo.set_optimizer(powergrid, Ipopt.Optimizer)
Plasmo.set_optimizer_attribute(powergrid, "hsllib", HSL_jll.libhsl_path)
Plasmo.set_optimizer_attribute(powergrid, "linear_solver", "ma27")

# Plasmo.set_optimizer(powergrid, ()->MadNLP.Optimizer(linear_solver=Ma27Solver))
# Plasmo.set_optimizer(powergrid, Gurobi.Optimizer)

Plasmo.optimize!(powergrid)

