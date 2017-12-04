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
#include "includes/socket.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new HashmapC(int,100) as HashC;
    //components new HashmapC(int,100) as HashC2;
    //components new HashmapC(int,100) as HashC3;
    //components new HashmapC(linkstate,100) as HashC4;
    //components new HashmapC(linkstate,100) as HashC5;
    components new ListC(int,100) as List;
    components new ListC(int,100) as List2;
    components new ListC(int,100) as List3;
    components new ListC(linkstate,GRAPH_NODE_MAX) as List4;
    components new ListC(pack,100) as List5;
    components new ListC(int,100) as List6;
    components new ListC(outstandTCP,100) as List7;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    components new TimerMilliC() as myTimerC; //create a new timer with alias “myTimerC”
    components new TimerMilliC() as myTimerC2;
    components new TimerMilliC() as myTimerC3;
    components new TimerMilliC() as myTimerC4;
    components new TimerMilliC() as myTimerC5;
    components new TimerMilliC() as myTimerC6;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    Node.NeighborList -> List;
    Node.CheckList->List2;
    Node.outstandingMessages->List7;

    Node.periodicTimer -> myTimerC; //Wire the interface to the component
    Node.sendingNeighborsTimer -> myTimerC2;
    Node.deleteMapTimer -> myTimerC3;
    Node.writeTimer -> myTimerC4;
    Node.readTimer -> myTimerC5;
    Node.reliabilityTimer->myTimerC6;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    //components NodeCommunicationC;
    //Node.nodeComp -> NodeCommunicationC;

    components new HashmapC(uint32_t,100) as HashC1;
    components new HashmapC(uint32_t,100) as HashC2;
    components new HashmapC(uint32_t,100) as HashC3;
    components new HashmapC(linkstate,100) as HashC4;
    components new HashmapC(linkstate,100) as HashC5;
    components new HashmapC(linkstate,100) as HashC6;
    components new HashmapC(uint32_t,100) as HashC7;
    components new HashmapC(uint32_t,100) as HashC8;
    components new HashmapC(uint32_t,100) as HashC9;
    components new HashmapC(socket_store_t,100) as HashC10;
    components new HashmapC(socket_t,100) as HashC11;
    components new HashmapC(socket_addr_t,100) as HashC12;
    components new HashmapC(seqInformation,1000) as HashC13;

    Node.PacketChecker -> HashC1;
    Node.CostMap -> HashC2;
    Node.RoutingMap -> HashC3;
    Node.tempMap -> HashC4;
    Node.linkStateMap -> HashC5;
    Node.transferMap -> HashC6;
    Node.ExpandedList -> HashC9;
    Node.socketHash -> HashC10;
    Node.socketIdentifier -> HashC11;
    Node.socketConnections -> HashC12;
    //Node.Derp -> HashC9;
    Node.seqInfo -> HashC13;

    components new TransportC() as Trans;
    components new TestC() as Tester;

    Node.Transport -> Trans;
    Trans.socketHash -> HashC10;
    Trans.periodicTimer -> myTimerC;
    Trans.socketIdentifier -> HashC11;
    Trans.socketConnections -> HashC12;
    //Node.Test -> Tester;
    //Tester.Hash5 -> HashC9;
}