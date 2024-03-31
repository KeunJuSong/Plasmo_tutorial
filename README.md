# Plasmo_tutorial
* Tutorial codes about Plasmo.jl

* Note that Plasmo.jl well represents optimization problem in hypergraph, so it can use graph partitioning method for hypergraph. 
* In this example, KaHyPar.jl is used as one of the famous graph partitioning methods, however, it is not available for window OS. Therefore, Window Subsystem Linux (WSL) can be an alternative solution for this problem.
    * Related issue: https://github.com/kahypar/KaHyPar.jl/issues/26
    * Also, there is very good blog that how to install WSL in Windows and connect to VSCode: https://tech.cloud.nongshim.co.kr/2023/11/14/windows%EC%97%90%EC%84%9C-wsllinux-%EA%B0%9C%EB%B0%9C-%ED%99%98%EA%B2%BD-%EA%B5%AC%EC%B6%95%ED%95%98%EA%B8%B0/ 

## Foods for thought:
* Hierarchical modeling? <= Use aggreagte method in Plasmo.jl to make coarse graph, and then first solve it fastly (in this step, let's check the number of variables and constraints). After that, using the solution of the coarse graph as the warm start to solve the "real" problem.
    * For doing that, we need to consider the decomposition options... (e.g., ADMM, Benders decomposition, Shcwarz decomposition, ... etc.)
* Do we need to consider Multi-Stage or Multi-level optimization for solving large scale problem? 
* Optimization solvers that leveraging GPUs. => MadNLP
* Which part that NN should involve to solve large scale problem?
    1. 이미 상용솔버에서 NR로 풀어서 전력망을 잘 운영하고 있으니 최대한 이걸 활용하는 솔루션
    2. NR 자체를 NN으로 대체하는 솔루션
    3. 분산/병렬최적화 (ADMM 등등) 