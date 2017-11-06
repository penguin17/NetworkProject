/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
 // Stuff to Check
 // Appropriate channels are being called and that more flooding isn't occurring
 
#include <Timer.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/LinkState.h"

module Node{
   uses interface Boot;

   uses interface Timer<TMilli> as periodicTimer; //Interface that was wired above.
   uses interface Timer<TMilli> as sendingNeighborsTimer;
   uses interface Timer<TMilli> as deleteMapTimer;

   uses interface SplitControl as AMControl;
   uses interface Receive;
   uses interface List<int> as NeighborList;
   uses interface List<int> as CheckList;
   //uses interface List<pack> as savedMessages;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   //uses interface NodeCommunication as nodeComp;

   uses interface Hashmap<uint32_t> as PacketChecker;
   uses interface Hashmap<uint32_t> as CostMap;
   uses interface Hashmap<uint32_t> as RoutingMap;
   uses interface Hashmap<uint32_t> as ExpandedList;
   uses interface Hashmap<linkstate> as transferMap;
   uses interface Hashmap<linkstate> as tempMap;
   uses interface Hashmap<linkstate> as linkStateMap;
}

implementation{
   pack sendPackage;
   uint16_t sequence = 0;
   bool printTime = FALSE;
   bool first = TRUE;
   linkstate map;
   uint16_t currentMaxNode = -1;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   //void calcShortestRoute();
   //void addToTopology(int source, uint8_t *neighbors);
   void printGraph();
   void printCostMap();
   bool containInTopology(int source);
   void deleteFromTopology(int);
   void linkStateChange();

   void printGraph()
  {
    int i = 0;
    int j = 0;
    uint32_t* keys = call linkStateMap.getKeys();

    map = call linkStateMap.get(TOS_NODE_ID);

    dbg(GENERAL_CHANNEL, "Map for node: %d with size = %d\n",TOS_NODE_ID, call linkStateMap.size());

    for(i = 0; i < call linkStateMap.size(); i++)
    {
      map = call linkStateMap.get(*keys);

      dbg(GENERAL_CHANNEL, "\tNode %d contains:\n",map.ID);

      for (j = 0; j < map.currMaxNeighbors; j++)
      {
        dbg(GENERAL_CHANNEL, "\t\tNode %d\n",map.neighbors[j]);
      }

      keys++;
    }
  }
  void printCostMap()
  {
    int i = 0;
    uint32_t* keys = call CostMap.getKeys();

    dbg(GENERAL_CHANNEL,"CostMap for node %d\n",TOS_NODE_ID);

    for (i = 0; i < call CostMap.size(); i++)
    {
      dbg(GENERAL_CHANNEL,"\tNode %d has cost value %d\n",*keys,call CostMap.get(*keys));
      keys++;
    }
  }
  void printPacketChecker()
  {
    int i = 0;
    uint32_t* keys = call PacketChecker.getKeys();
    dbg(GENERAL_CHANNEL,"Node %d\n",TOS_NODE_ID);

    for (i = 0; i < call PacketChecker.size(); i++)
    {
      dbg(GENERAL_CHANNEL,"\tNode %d has seq value %d\n",*keys,call PacketChecker.get(*keys));
      keys++;
    }
  }
  void expand(uint32_t node)
  {
     int i = 0;
     map = call linkStateMap.get(node);
       
    
       //dbg(GENERAL_CHANNEL,"Size of neighbors at node %d is %d\n",node,map[x].currMaxNeighbors);
       
       for (i = 0; i < map.currMaxNeighbors; i++)
       {
        if (!call CostMap.contains(map.neighbors[i]))
        {
          call CostMap.insert(map.neighbors[i],COST_MAX);
          call RoutingMap.insert(map.neighbors[i],COST_MAX);

          //call CostMap.insert(map.neighbors[i],COST_MAX);

        }
        if (call CostMap.get(map.neighbors[i]) > (call CostMap.get(node) + 1))
        {
          //dbg(GENERAL_CHANNEL,"%d expanded by %d\n",map[x].neighbors[i],node);
          call CostMap.remove(map.neighbors[i]);
          call CostMap.insert(map.neighbors[i],call CostMap.get(node) + 1);

          call RoutingMap.remove(map.neighbors[i]);
          call RoutingMap.insert(map.neighbors[i],node);
        }
        else if (call CostMap.get(node) > (call CostMap.get(map.neighbors[i]) + 1))
        {
          call CostMap.remove(node);
          call CostMap.insert(node,call CostMap.get(map.neighbors[i]) + 1);

          call RoutingMap.remove(node);
          call RoutingMap.insert(node,map.neighbors[i]);
        }
       }

       call ExpandedList.insert(node,0);
  }

  void setupCostMap()
    {
       int i = 0;
       uint32_t *keys;

       while(!call CostMap.isEmpty())
       {
        keys = call CostMap.getKeys();

        call CostMap.remove(*keys);
       }

       keys = call linkStateMap.getKeys();

       for(i = 0; i < call linkStateMap.size(); i++)
       {
        map = call linkStateMap.get(*keys);

        call CostMap.insert(map.ID,COST_MAX);

        keys++;
       }
    }

    void setupRoutingMap()
    {
       int i = 0;
       uint32_t *keys;

       while(!call RoutingMap.isEmpty())
       {
        keys = call RoutingMap.getKeys();

        call RoutingMap.remove(*keys);
       }

       keys = call linkStateMap.getKeys();

       for(i = 0; i < call linkStateMap.size(); i++)
       {
        map = call linkStateMap.get(*keys);

        call RoutingMap.insert(map.ID,COST_MAX);

        keys++;
       }
    }

    void setupExpandedList()
    {
       uint32_t *keys;

       while(!call ExpandedList.isEmpty())
       {
        keys = call ExpandedList.getKeys();

        call ExpandedList.remove(*keys);
       }
    }

    bool fullyExpanded()
    {
       bool search = FALSE;
       int i = 0;
       int j = 0;

       if (call ExpandedList.size() != call linkStateMap.size())
        return FALSE;

       for (i = 0; i < call linkStateMap.size(); i++)
       {
        map = call linkStateMap.get(i);

        if (call ExpandedList.contains(map.ID))
          search = TRUE;
        
        if(!search)
          return FALSE;

        search = FALSE;
       }

       return TRUE;
    }

    uint32_t lowestCostNode()
    {
       int lowest = COST_MAX;
       int lowID = COST_MAX;
       int i = 0;
       int j = 0;
       uint32_t *keys;

       for (i = 0; i < call linkStateMap.size(); i++)
       {
        map = call linkStateMap.get(i);

        if (call CostMap.get(map.ID) <= lowest && !call ExpandedList.contains(map.ID))
        {
          lowest = call CostMap.get(map.ID);
          lowID = map.ID;

          if (lowest == COST_MAX)
          {
            for (j = 0; j < map.currMaxNeighbors; j++)
            {
              if (call CostMap.get(map.neighbors[j]) < lowest)
              {
                lowest = call CostMap.get(map.neighbors[j]);
                lowID = map.ID;
              }
            }
          }
        }
       }

       return lowID;
    }

    void addToTopology(uint32_t source, uint8_t *neighbors)
    {
      int count = 0;
      int size = GRAPH_NODE_MAX;
      int val = 0;
      uint8_t *p = neighbors;

      if (call linkStateMap.size() == GRAPH_NODE_MAX)
      {
        dbg(GENERAL_CHANNEL,"***Limit of nodes to add has been reached for graph***\n");
      }

      
      map.ID = source;
      map.currMaxNeighbors = 0;
      map.size = 0;


      while(count < size)
      {
        if(isdigit(*p) && count == 0)
        {
          size = strtol(p,&p,10);

          size = size + 1;

          count++;
        }
        else if(isdigit(*p))
        {
          val = strtol(p,&p,10);

          if (map.currMaxNeighbors == GRAPH_NODE_MAX)
          {
            dbg(GENERAL_CHANNEL,"***Limit of nodes to add has been reached for neighbors***\n");
          }

          map.neighbors[map.currMaxNeighbors] = val;
          map.currMaxNeighbors++;

          count++;
        }
        else
        {
          p++;
        }
      }

      call linkStateMap.insert(map.ID,map);
    }

    uint32_t portCalc(uint32_t node)
    {
       if (call RoutingMap.get(node) == TOS_NODE_ID)
        return node;
       else if (call RoutingMap.get(node) == COST_MAX)
        return COST_MAX;
       else 
        portCalc(call RoutingMap.get(node));
    }

  bool sendCheck(pack* msg)
  {
    if ((msg->protocol == PROTOCOL_PING || msg->protocol == PROTOCOL_PINGREPLY) && TOS_NODE_ID == 2)
    {
      //printPacketChecker();
      //dbg(GENERAL_CHANNEL,"Current seq = %d\n",msg->seq);
    }
    if (call PacketChecker.contains(msg->src) && call PacketChecker.get(msg->src) < msg->seq && msg->TTL > 0)
    { 
      call PacketChecker.remove(msg->src);
      call PacketChecker.insert(msg->src,msg->seq);
      return TRUE;
    }

    return FALSE;
  }
  
  void receiveLinkStateProtocol(pack* msg)
  {
    //dbg(GENERAL_CHANNEL, "Node %d is sending linkstate\n",NODE_ID);
    if (call linkStateMap.contains(msg->src))
    {
      call linkStateMap.remove(msg->src);
      addToTopology(msg->src,msg->payload);
      //linkStateChange();
    }
    else
    {
      addToTopology(msg->src,msg->payload);
      //linkStateChange();
    }

  }
  
  void sendLinkState(uint32_t node, uint8_t *neighbors)
  {
    //dbg(GENERAL_CHANNEL, "Node %d is sending linkstate\n",NODE_ID);
    if (call linkStateMap.contains(node))
    {
      call linkStateMap.remove(node);
    }

    addToTopology(node,neighbors);
  }
  
  void calcRoute()
  {
    //dbg(GENERAL_CHANNEL,"Calculating Shortest Route getting called\n");
       int count = 0;
       setupCostMap();
       setupRoutingMap();
       setupExpandedList();

       call CostMap.remove(TOS_NODE_ID);
       call CostMap.insert(TOS_NODE_ID,0);

       call RoutingMap.remove(TOS_NODE_ID);
       call RoutingMap.insert(TOS_NODE_ID,TOS_NODE_ID);

       //dbg(GENERAL_CHANNEL,"Derp\n");
       while(!fullyExpanded())
       {
        uint32_t n = lowestCostNode();

        if (n == COST_MAX)
          break;
        else
          expand(n);
        
        
       }


      
       //printGraph();
       //printCostMap();
  }
  
  bool containsRouting(uint32_t node)
  {
    if (call RoutingMap.contains(node) && call RoutingMap.get(node) != COST_MAX)
      return TRUE;
    return FALSE;
  }

   void deleteCheckList()
   {
     while(!call CheckList.isEmpty())
     {
       call CheckList.popfront();
     }
   }
   void deleteNeighborList()
   {
     while(!call NeighborList.isEmpty())
     {
       call NeighborList.popfront();
     }
   }

   event void Boot.booted(){
      call AMControl.start();
      dbg(GENERAL_CHANNEL, "Booted\n");
   }
  void printNeighbors()
  {
    int i = 0;

    dbg(GENERAL_CHANNEL, "For node %d:\n",TOS_NODE_ID);

    for (i = 0; i < call NeighborList.size(); i++)
    {
      dbg(GENERAL_CHANNEL,"\tNode: %d\n",call NeighborList.get(i));
    }
  }
  bool neighborChange()
  {
    int i = 0,j = 0;
    bool found = FALSE;

	for(i = 0; i < call NeighborList.size(); i++)
	{	
		for (j = 0; j < call CheckList.size(); j++)
		{
			if(call NeighborList.get(i) == call CheckList.get(j))
			{
				found = TRUE;
				break;
			}
		}

		if (!found)
			return TRUE;
	}
	
	for (i = 0; i < call CheckList.size(); i++)
	{
		for (j = 0; j < call NeighborList.size(); j++)
		{
			if(call NeighborList.get(i) == call CheckList.get(j))
			{
				found = TRUE;
				break;
			}
		}

		if (!found)
			return TRUE;
	}

    return FALSE;
  }

  void updateNeighbors()
  {
  	int i = 0;

  	deleteNeighborList();

  	for (i = 0; i < call CheckList.size(); i++)
    {
      call NeighborList.pushfront(call CheckList.get(i));
    }
    
    deleteCheckList();

  }
  void sendNeighbors()
  {
  	uint8_t derp[1000];
  	uint8_t *der = derp;
  	uint8_t temp[20];
  	int tempSize = 0;
  	int currSize = 0;

  	int i = 0, j = 0;

  	if (call NeighborList.size() == 0)
  		return;

  
  	sprintf(temp,"%d*",call NeighborList.size());
  	
  	tempSize = strlen(temp);

  	for (i = 0; i < tempSize; i++)
  	{
  		derp[currSize+i] = temp[i];
  	}

  	currSize = currSize + tempSize;

  	for (i = 0; i < call NeighborList.size(); i++)
  	{
  		sprintf(temp,"%d*",call NeighborList.get(i));
  		tempSize = strlen(temp);
  		
  		for(j = 0; j < tempSize; j++)
  		{
  			derp[currSize+j] = temp[j];
  		}

  		currSize = currSize + tempSize;
  	}


    sendLinkState(TOS_NODE_ID,der);

	
	  makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL , PROTOCOL_LINKSTATE, sequence, der, PACKET_MAX_PAYLOAD_SIZE);

    call PacketChecker.remove(TOS_NODE_ID);
    call PacketChecker.insert(TOS_NODE_ID,sequence);
    call Sender.send(sendPackage,AM_BROADCAST_ADDR);
    sequence++;
  }
    
   event void periodicTimer.fired()
    {
      uint8_t wo[2];
      pack tempPack;
      uint8_t * wow = wo;
      wo[0] = 'W';
      wo[1] = 'O';
      
      
      makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL , PROTOCOL_NEIGHBORDISC, 0, wow, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage,AM_BROADCAST_ADDR);
    
      if (neighborChange())
      {
      	updateNeighbors();
      	sendNeighbors();
        printNeighbors();
      }
    
    }

  	event void sendingNeighborsTimer.fired()
  	{
  		sendNeighbors();
  	}

  	event void deleteMapTimer.fired()
  	{
  		calcRoute();
  	}
   event void AMControl.startDone(error_t err){
      time_t t;
      int myTime;
      int i = 0;

      //call nodeComp.initializeNode(TOS_NODE_ID);

      if (TOS_NODE_ID == 1)
      	srand(time(NULL));


      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL,"Radio On\n");
         myTime = rand()%(1000 + 1 - 100) + 100;
         
         call periodicTimer.startPeriodic(rand()%(10000 + 1 - 9000) + 9000);
         call sendingNeighborsTimer.startPeriodic(15*myTime);
         call deleteMapTimer.startPeriodic(10000000);
         call deleteMapTimer.startOneShot(3*myTime);
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){
    
   }

   void neighborHandle(pack* myMsg)
   {
      if (myMsg->dest == TOS_NODE_ID)
      {
          int size = call CheckList.size();
          int i = 0;
        
        
          for (i = 0; i < size; i++)
          {
            if (call CheckList.get(i) == myMsg->src)
              return;
          }

         
          call CheckList.pushfront(myMsg->src);
      }
      else
      {
        makePack(&sendPackage, TOS_NODE_ID, myMsg->src, myMsg->TTL, PROTOCOL_NEIGHBORDISC, 0, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage,myMsg->src);
      }
   }

   void pingRegHandle(pack* myMsg)
   {
      makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);

      //calcRoute();
      
      if (myMsg->dest == AM_BROADCAST_ADDR)
      {
        call Sender.send(sendPackage,AM_BROADCAST_ADDR);
      }
      else if (containsRouting(myMsg->dest))
      {
        dbg(GENERAL_CHANNEL,"Routing being used: %d is passing to %d\n",TOS_NODE_ID,myMsg->dest);
        call Sender.send(sendPackage,portCalc(myMsg->dest));
      }
      else
      {
        dbg(GENERAL_CHANNEL,"Packet is being dropped\n");
      }
   }

   void pingDestHandle(pack* myMsg)
   {
      if (myMsg->protocol == PROTOCOL_PINGREPLY)
      {
        dbg(FLOODING_CHANNEL, "Message Acceptance from %d received\n",myMsg->src);
      }
      else
      {
        dbg(FLOODING_CHANNEL, "Packet has finally gone to correct location, from:to, %d:%d\n", myMsg->src,myMsg->dest);
        dbg(FLOODING_CHANNEL, "Package Payload: %s\n", myMsg->payload);
        dbg(FLOODING_CHANNEL, "Message being sent to %d for aknowledgement of message received by %d\n",myMsg->src,myMsg->dest);

        makePack(&sendPackage, myMsg->dest, myMsg->src, myMsg->TTL, PROTOCOL_PINGREPLY, sequence, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
        sequence++;
        //calcRoute();

        if (myMsg->src == AM_BROADCAST_ADDR)
        {
          call Sender.send(sendPackage,AM_BROADCAST_ADDR);
        }
        else if (containsRouting(myMsg->src))
        {
        call PacketChecker.remove(TOS_NODE_ID);
    call PacketChecker.insert(TOS_NODE_ID,sequence);
          call Sender.send(sendPackage,portCalc(myMsg->src));
        }
        else
        {
          dbg(GENERAL_CHANNEL,"Packet is being dropped\n");
        }
      
      }
   }

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){

      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;

         /////////////////////////////////////////////////////////////////////////////////
         // - Something to take note is when to check if you've seen the message already
         // - Also how to check when destination has next hop choice
         // - Also make it so that you implement port calc to make utilization of the routing table
         /////////////////////////////////////////////////////////////////////////////////
         
         myMsg->TTL = myMsg->TTL - 1;

         if (myMsg->protocol == PROTOCOL_NEIGHBORDISC)
         {
         	
            neighborHandle(myMsg);
            return msg;
         }

        
         if (!call PacketChecker.contains(myMsg->src))
            call PacketChecker.insert(myMsg->src,myMsg->seq);
         else if (call PacketChecker.get(myMsg->src) < myMsg->seq)
         {
            call PacketChecker.remove(myMsg->src);
            call PacketChecker.insert(myMsg->src,myMsg->seq);
         }
         else if (myMsg->TTL <= 0)
            return msg;
         else
            return msg;


         if (myMsg->protocol == PROTOCOL_PING || myMsg->protocol == PROTOCOL_PINGREPLY)
         {
            if (call CostMap.get(myMsg->src) <= 1)
              calcRoute();

            if (myMsg->dest == TOS_NODE_ID)
            {
                pingDestHandle(myMsg);
            }
            else
            {
	          	  pingRegHandle(myMsg);
            }
           
         }
  
         if (myMsg->protocol == PROTOCOL_LINKSTATE)
         {
            receiveLinkStateProtocol(myMsg);

            makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
            
            call Sender.send(sendPackage,AM_BROADCAST_ADDR);

            if (TOS_NODE_ID == 2)
            {
              //dbg(GENERAL_CHANNEL,"LinkState from %d\n",myMsg->src);
              //dbg(GENERAL_CHANNEL,"Sequence # = %d\n",myMsg->seq);
              //printGraph();
            }
         }
    
        
      }
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
    dbg(GENERAL_CHANNEL, "PING EVENT for destination = %d\n",destination);
    
    makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, sequence, payload, PACKET_MAX_PAYLOAD_SIZE);

    call PacketChecker.remove(TOS_NODE_ID);
    call PacketChecker.insert(TOS_NODE_ID,sequence);
    sequence++;
    calcRoute();
    
    if (destination == AM_BROADCAST_ADDR)
      call Sender.send(sendPackage,AM_BROADCAST_ADDR);
	  else if (containsRouting(destination))
	  {
	   	dbg(GENERAL_CHANNEL,"Routing being used to send ping\n");
      call Sender.send(sendPackage,portCalc(destination));
    }
    else
    {
      dbg(GENERAL_CHANNEL,"Message being dropped before it's even sent\n");
    }

   }

   event void CommandHandler.printNeighbors()
   {
      
   }

   event void CommandHandler.printRouteTable()
   {
   	 
   }

   event void CommandHandler.printLinkState()
   {
   	 
   }

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
   void linkStateChange()
   {
    calcRoute();
   }
}