//Author: DavidC
//$Author: DavidC
//$LastChangedBy: DavidC

#ifndef LINKSTATE_H
#define LINKSTATE_H




enum{
	NEIGHBOR_MAX = 50,
	COST_MAX = 100,
	GRAPH_NODE_MAX = 100
};


typedef nx_struct linkstate{
	nx_uint32_t ID;
	nx_uint32_t currMaxNeighbors;
	nx_uint32_t size;
	nx_uint32_t neighbors[NEIGHBOR_MAX];
}linkstate;


#endif
