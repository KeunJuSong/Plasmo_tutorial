# Document for Plasmo.jl

## Overview of primary ```OptiGraph``` construction and query functions
|Function|Description|
|------|---|
|```optiGraph()```|Create a new OptiGraph object|
|```@optinode(g::OptiGraph,expr::Expr)```|Create OptiNodes with macro|
|```@linkconstraint(g::OptiGraph,expr::Expr)```|Create linking constraints with macro|
|```add_subgraph!(g::OptiGraph,sg::OptiGraph)```|Add subgraph sg to graph g|
|```optinodes(g::OptiGraph)```|Return local OptiNodes in g|
|```optiedges(g::OptiGraph)```|Return local OptiEdges in g|
|```linkconstraints(g::OptiGraph)```|Return local linking constraints in g|
|```subgraphs(g::OptiGraph)```|Return local subgraphs in g|
|```all_nodes(g::OptiGraph)```|Return all OptiNodes in g|
|```all_edges(g::OptiGraph)```|Return all OptiEdges in g|
|```all_linkconstraints(g::OptiGraph)```|Return all linking constraints in g|
|```all_subgraphs(g::OptiGraph)```|Return all subgraphs in g|

## Overview of core partitioning and topology functions
|Function|Description|
|------|---|
|```hgraph,proj_map=hyper_graph(g::OptiGraph)```|Create a hypergraph ```hgraph``` from ```g``` and a mapping between their elements|
|```cgraph,proj_map=clique_graph(g::OptiGraph)```|Create a standard graph ```cgraph``` from ```g``` and a mapping between their elements|
|```bgraph,proj_map=bipartite_graph(g::OptiGraph)```|Create a bipartite graph ```bgraph``` from ```g``` and a mapping between their elements|
|```partition=Partition(vertices::Vector{Int},proj_map::ProjectionMap)```|Create a ```Partition``` object using ```vertices``` and the ```ProjectionMap``` object ```proj_map```|
|```apply_partition!(g::OptiGraph,partition::Partition)```|Reform the ```OptiGraph g``` into subgraphs using the ```Partition``` object ```partition```|
|```aggregate!(g::OptiGraph,n_levels::Int)```|Aggregate subgraphs in ```g``` into ```OptiNodes``` such that ```n_levels``` of subgraphs remain|
|```i_edges=incident_edges(g::OptiGraph,nodes::Vector{OptiNode})```|Return the incident ```OptiEdges i_edges``` from the vector of ```nodes``` in ```g```|
|```neigh_nodes=neighborhood(g::OptiGraph,nodes::Vector{OptiNode},d::Int)```|Return the neighborhood ```OptiNodes neigh_nodes``` within distance ```d``` of ```nodes```|
|```expanded_graph=expand(g::OptiGraph,subgraph::OptiGraph,d::Int)```|Create an ```OptiGraph``` from ```g``` containing nodes within distance ```d``` of ```subgraph```|
|```induced_graph=induced_subgraph(g::OptiGraph,nodes::Vector{OptiNode})```|Create a new induced ```OptiGraph``` object from the vector of ```nodes``` in ```g```|