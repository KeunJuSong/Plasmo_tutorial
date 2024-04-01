using LightGraphs, Random, LinearAlgebra, Printf, DelimitedFiles, SparseArrays, PowerModels

PowerModels.silence()

function get_data(path)
    data = PowerModels.parse_file(path)
    A = PowerModels.calc_susceptance_matrix(data)

    args = Dict()
    args[:N] = size(A.matrix, 1) # number of buses
    args[:y] = A.matrix
    args[:del] = spzeros(args[:N],args[:N]) # 
    args[:g] = LightGraphs.Graph(args[:N]) # the lightgraph; assign the nodes
    for e in values(data["branch"])
        i = A.bus_to_idx[e["f_bus"]]
        j = A.bus_to_idx[e["t_bus"]]
        LightGraphs.add_edge!(args[:g],i,j) # assign the edges.
        args[:del][i,j] = e["angmin"]
        args[:del][j,i] = e["angmin"]
    end

    # voltage angle limits
    args[:val] = -ones(args[:N])*Inf # lower bound
    args[:vau] = ones(args[:N])*Inf # upper bound
    args[:ref] = A.bus_to_idx[PowerModels.reference_bus(data)["index"]] # reference buses
    args[:val][args[:ref]] = 0; args[:vau][args[:ref]] = 0 # the voltage angle of reference bus is 0.


    gens = PowerModels.bus_gen_lookup(data["gen"], data["bus"]) # bus index 중 generator bus index에 대해서만 관련 PV bus 정보 제공하는 함수. (vg, mbase, source_id, pg, model, shutdown, startup, index, cost, qg)
    # generator cost coefficients
    args[:c1] = [[1e6, -1e6] for i=1:args[:N]]
    args[:c2] = [[.0, .0] for i=1:args[:N]]
    args[:sl] = [[.0,-1e2] for i=1:args[:N]] # generator power min?
    args[:su] = [[1e2,.0] for i=1:args[:N]] # generator power max?
    args[:ng] = 2*ones(Int64,args[:N]) # number of generators? <= TODO: Need to check this.

    for i=1:args[:N] # for each bus
        bus = A.idx_to_bus[i] # return to the bus index from the index of matrix.
        for j=1:length(gens[bus]) # 해당 PV bus에 있는 발전기 개수 별 loop?
            if length(gens[bus][j]["cost"]) != 0
                # push! <= list append와 같은 개념
                push!(args[:c1][i], gens[bus][j]["cost"][1])
                push!(args[:c2][i], gens[bus][j]["cost"][2])
                push!(args[:sl][i], gens[bus][j]["pmin"])
                push!(args[:su][i], gens[bus][j]["pmax"])
                args[:ng][i] += 1
            end
        end
    end

    args[:Ng] = sum(args[:ng]) # <= TODO: Need to check this.

    # PQ bus의 Pd 저장?
    args[:sd] = zeros(args[:N])
    for v in values(data["load"])
        args[:sd][A.bus_to_idx[v["load_bus"]]] = v["pd"]
    end

    return args
end