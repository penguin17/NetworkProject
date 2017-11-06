#include "../includes/LinkState.h"

configuration NodeCommunicationC{
	provides interface NodeCommunication;
}
implementation{
	components new NodeCommunicationP() as nodeComp;
	NodeCommunication = nodeComp.NodeCommunication;

	components new HashmapC(uint32_t,100) as HashC1;
    components new HashmapC(uint32_t,100) as HashC2;
    components new HashmapC(uint32_t,100) as HashC3;
    components new HashmapC(linkstate,100) as HashC4;
    components new HashmapC(linkstate,100) as HashC5;
    components new HashmapC(linkstate,100) as HashC6;
    components new HashmapC(uint32_t,100) as HashC7;
    components new HashmapC(uint32_t,100) as HashC8;
    components new HashmapC(uint32_t,100) as HashC9;

    nodeComp.PacketChecker -> HashC1;
    nodeComp.CostMap -> HashC2;
    nodeComp.RoutingMap -> HashC3;
    nodeComp.tempMap -> HashC4;
    nodeComp.linkStateMap -> HashC5;
    nodeComp.transferMap -> HashC6;
    nodeComp.NeighborList -> HashC7;
    nodeComp.CheckList -> HashC8;
    nodeComp.ExpandedList -> HashC9;

    
}