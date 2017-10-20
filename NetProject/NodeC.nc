/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"
#include "includes/LinkState.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new HashmapC(int,100) as HashC;
    components new HashmapC(int,100) as HashC2;
    components new HashmapC(int,100) as HashC3;
    components new HashmapC(linkstate,100) as HashC4;
    components new HashmapC(linkstate,100) as HashC5;
    components new ListC(int,100) as List;
    components new ListC(int,100) as List2;
    components new ListC(int,100) as List3;
    components new ListC(linkstate,GRAPH_NODE_MAX) as List4;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    components new TimerMilliC() as myTimerC; //create a new timer with alias “myTimerC”
    components new TimerMilliC() as myTimerC2;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    Node.Hash -> HashC;
    Node.CostMap -> HashC2;
    Node.RoutingMap -> HashC3;
    Node.tempMap -> HashC4;
    Node.transferMap -> HashC5;
    Node.ExpandedList -> List3;
    Node.NeighborList -> List;
    Node.CheckList->List2;
    Node.myMap -> List4;

    Node.periodicTimer -> myTimerC; //Wire the interface to the component
    Node.sendingNeighborsTimer -> myTimerC2;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;
}