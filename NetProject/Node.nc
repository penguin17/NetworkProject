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
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/LinkState.h"

module Node{
   uses interface Boot;

   uses interface Timer<TMilli> as periodicTimer; //Interface that was wired above.

   uses interface SplitControl as AMControl;
   uses interface Receive;
   uses interface List<int> as NeighborList;
   uses interface List<int> as CheckList;
   uses interface List<int> as ExpandedList;
   uses interface List<linkstate> as myMap;

   uses interface Hashmap<int> as Hash;

   uses interface Hashmap<int> as CostMap;

   uses interface Hashmap<int> as RoutingMap;

   uses interface Hashmap<linkstate> as tempMap;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;
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
   void addToTopology(int source, uint8_t *neighbors);
   void printGraph();
   bool containInTopology(int source);

   void printNeighbors()
   {
     int i = 0;

     dbg(NEIGHBOR_CHANNEL,"List of neighbors for node %d\n",TOS_NODE_ID);

     for(i = 0; i < call NeighborList.size(); i++)
     {
        dbg(NEIGHBOR_CHANNEL,"Node: %d\n",call NeighborList.get(i));
     }
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

   	 for(i = 0; i < call myMap.size(); i++)
   	 {
   	 	map = call myMap.get(i);

   	 	call CostMap.insert(map.ID,COST_MAX);
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

   	 for(i = 0; i < call myMap.size(); i++)
   	 {
   	 	map = call myMap.get(i);

   	 	call RoutingMap.insert(map.ID,NEIGHBOR_MAX);
   	 }
   }

   void setupExpandedList()
   {
   	 while(!call ExpandedList.isEmpty())
     {
       call ExpandedList.popfront();
     }
   }

   int loc(int node)
   {
   	 int i = 0;

   	 for (i = 0; i < call myMap.size(); i++)
     {
     	map = call myMap.get(i);

   	 	if (map.ID == node)
   	 		return i;
   	 }

   	 //dbg(GENERAL_CHANNEL,"Location returning negative 1\n");
   	 //dbg(GENERAL_CHANNEL,"Failed at %d\n",node);
   	 //printGraph();
   	 return -1;
   }
   void expand(int node)
   {
   	 int x = loc(node);
   	 int i = 0;

   	 map = call myMap.get(x);

   	 if (map.ID != node && x != -1)
   	 	dbg(GENERAL_CHANNEL,"Location not working\n");

   	 //dbg(GENERAL_CHANNEL,"Size of neighbors at node %d is %d\n",node,map[x].currMaxNeighbors);
   	 for (i = 0; i <= map.currMaxNeighbors; i++)
   	 {
   	 	if (!call CostMap.contains(map.neighbors[i]))
   	 	{
   	 		call ExpandedList.pushfront(map.neighbors[i]);
   	 		continue;
   	 	}
   	 	if (call CostMap.get(map.neighbors[i]) > (call CostMap.get(node) + 1))
   	 	{
   	 		//dbg(GENERAL_CHANNEL,"%d expanded by %d\n",map[x].neighbors[i],node);
   	 		call CostMap.remove(map.neighbors[i]);
   	 		call CostMap.insert(map.neighbors[i],call CostMap.get(node) + 1);

   	 		call RoutingMap.remove(map.neighbors[i]);
   	 		call RoutingMap.insert(map.neighbors[i],node);
   	 	}
   	 }

   	 call ExpandedList.pushfront(node);
   }

   
   bool containsExpanded(int node)
   {
   	 // Fill in
   	 
   	 int i = 0; 

   	 for (i = 0; i < call ExpandedList.size(); i++)
   	 {
   	 	if (call ExpandedList.get(i) == node)
   	 		return TRUE;
   	 }

   	 return FALSE;
   }
   bool fullyExpanded()
   {
   	 // Fill in
   	 
   	 int i = 0;
   	 int j = 0;

   	 for (i = 0; i < call myMap.size(); i++)
   	 {
   	 	map = call myMap.get(i);

   	 	if (call CostMap.get(map.ID) == COST_MAX && !containsExpanded(map.ID))
   	 		return FALSE;
   	 }

   	 return TRUE;
   }
   uint16_t lowestCostNode()
   {
   	 int lowest = COST_MAX;
   	 int lowID = -1;
   	 int i = 0;

   	 for (i = 0; i < call myMap.size(); i++)
   	 {
   	 	map = call myMap.get(i);

   	 	if (call CostMap.get(map.ID) <= lowest && !containsExpanded(map.ID))
   	 	{
   	 		lowest = call CostMap.get(map.ID);
   	 		lowID = map.ID;
   	 	}
   	 }

   	 //if (lowID == -1)
   	 	//dbg(GENERAL_CHANNEL, "Didn't find an ID with low value\n");
   	 return lowID;

   }

   uint16_t portCalc(int node)
   {
   	 // Fill in

   	 if (call RoutingMap.get(node) != TOS_NODE_ID)
   	 	return portCalc(call RoutingMap.get(node));
   	 else
   	 	return node;
   }

   void printCheckList()
   {
    int i = 0;

     dbg(NEIGHBOR_CHANNEL,"Neighbors for node %d\n",TOS_NODE_ID);

     for(i = 0; i < call CheckList.size(); i++)
     {
        dbg(NEIGHBOR_CHANNEL,"Node: %d\n",call CheckList.get(i));
     }
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

  /////////////////////////////////////////////////
  ////////////////////////////////////////////////
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

    //printNeighbors();

  }
  void sendNeighbors()
  {
  	uint8_t derp[1000];
  	uint8_t *der = derp;
  	uint8_t temp[20];
  	int tempSize = 0;
  	int currSize = 0;

  	int i = 0, j = 0;

  	if (neighborChange())
  	{

  		updateNeighbors();

	  	sprintf(temp,"%d*",call NeighborList.size());
	  	tempSize = strlen(temp);

	  	for (i = 0; i < tempSize; i++)
	  	{
	  		derp[currSize+i] = temp[i];
	  	}

	  	currSize = currSize + tempSize;

	  	//dbg(GENERAL_CHANNEL,"%d is sending link state information\n",TOS_NODE_ID);

	  	for (i = 0; i < call NeighborList.size(); i++)
	  	{
	  		sprintf(temp,"%d*",call NeighborList.get(i));
	  		tempSize = strlen(temp);
	  		//dbg(GENERAL_CHANNEL,"-- %s\n",temp);
	  		for(j = 0; j < tempSize; j++)
	  		{
	  			derp[currSize+j] = temp[j];
	  		}

	  		currSize = currSize + tempSize;
	  	}

	  	
	  	addToTopology(TOS_NODE_ID,der);
	}
	else
	{
		sprintf(temp,"%d*",call NeighborList.size());
	  	tempSize = strlen(temp);

	  	for (i = 0; i < tempSize; i++)
	  	{
	  		derp[currSize+i] = temp[i];
	  	}

	  	currSize = currSize + tempSize;

	  	//dbg(GENERAL_CHANNEL,"%d is sending link state information\n",TOS_NODE_ID);

	  	for (i = 0; i < call NeighborList.size(); i++)
	  	{
	  		sprintf(temp,"%d*",call NeighborList.get(i));
	  		tempSize = strlen(temp);
	  		//dbg(GENERAL_CHANNEL,"-- %s\n",temp);
	  		for(j = 0; j < tempSize; j++)
	  		{
	  			derp[currSize+j] = temp[j];
	  		}

	  		currSize = currSize + tempSize;
	  	}
	}

	makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL , PROTOCOL_LINKSTATE, sequence, der, PACKET_MAX_PAYLOAD_SIZE);
	sequence = sequence + 1;
	call Hash.insert(TOS_NODE_ID,sequence);
    call Sender.send(sendPackage, AM_BROADCAST_ADDR);  	
  }

  void printGraph()
  {
  	int i = 0;
  	int j = 0;

  	if (call myMap.size() < 2)
  		dbg(GENERAL_CHANNEL, "*****Nothing much to print for the graph*****\n");

  	//dbg(GENERAL_CHANNEL,"Map for %d with size %d\n",TOS_NODE_ID,currentMaxNode+1);

  	for (i = 0; i < call myMap.size(); i++)
  	{
  		map = call myMap.get(i);

  		dbg(GENERAL_CHANNEL,"	Neighbors for node: %d\n",map.ID);

  		for (j = 0; j <= map.currMaxNeighbors; j++)
  		{
  			dbg(GENERAL_CHANNEL,"	%d\n",map.neighbors[j]);
  		}
  	}
  }
  void addToTopology(int source, uint8_t *neighbors)
  {
  	int count = 0;
  	int size = GRAPH_NODE_MAX;
  	int val = 0;
  	uint8_t *p = neighbors;

  	if (call myMap.size() == GRAPH_NODE_MAX)
  	{
  		dbg(GENERAL_CHANNEL,"***Limit of nodes to add has been reached for graph***\n");
  	}

  	//currentMaxNode = currentMaxNode + 1;

  	//dbg(GENERAL_CHANNEL,"CurrentMaxNode size = %d\n",currentMaxNode);
  	
  	map.ID = source;
  	map.currMaxNeighbors = -1;

  	//map[currentMaxNode].ID = source;
  	//map[currentMaxNode].currMaxNeighbors = -1;

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

		  	map.currMaxNeighbors++;
		  	map.neighbors[map.currMaxNeighbors] = val;

  			//map[currentMaxNode].currMaxNeighbors = map[currentMaxNode].currMaxNeighbors + 1;
  			//map[currentMaxNode].neighbors[map[currentMaxNode].currMaxNeighbors] = val;
  			
  			//dbg(GENERAL_CHANNEL,"%d\n",val);

  			count++;
  		}
  		else
  		{
  			p++;
  		}
  	}

  	call myMap.pushfront(map);
  	//calcShortestRoute();
  }

  void deleteFromTopology(int source)
  {
  	int i = 0;

  	uint32_t *keys;

  	map = call myMap.popfront();

  	while(map.ID != source)
  	{
  		call tempMap.insert(map.ID,map);

  		map = call myMap.popfront();
  	}

  	while(!call tempMap.isEmpty())
   	 {
   	 	keys = call tempMap.getKeys();

   	 	map = call tempMap.get(*keys);

   	 	call myMap.pushfront(map);

   	 	call tempMap.remove(*keys);
   	 }

  }
  bool statusJoin()
  {

  }
  bool containInTopology(int source)
  {
  	int i = 0;

  	for (i = 0; i < call myMap.size(); i++)
  	{
  		map = call myMap.get(i);

  		if (map.ID == source)
  			return TRUE;
  	}

  	return FALSE;
  }
  
  void printCostMap()
  {
  	uint32_t *i;

  	i = call CostMap.getKeys();

  	dbg(GENERAL_CHANNEL,"CostMap size = %d\n",call CostMap.size());
  	while(*i)
  	{
  		dbg(GENERAL_CHANNEL,"For key = %d the value is %d\n",*i,call CostMap.get(*i));
  		i++;
  	}
  }
  
  void calcShortestRoute()
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

  	 expand(TOS_NODE_ID);

  	 //dbg(GENERAL_CHANNEL,"Current max size = %d\n",currentMaxNode + 1);

  	 if (fullyExpanded())
  	 	dbg(GENERAL_CHANNEL,"fully expanded before even entering the for loop\n");

  	 while(!fullyExpanded())
  	 {
  	 	uint16_t n = lowestCostNode();

  	 	if (n == -1)
  	 		break;
  	 	else
  	 		expand(n);
  	 	
  	 	
  	 }

/*
  	 if (TOS_NODE_ID == 1)
  	 {
  	 	int i = 0;
  	 	
  	 	dbg(GENERAL_CHANNEL,"Routing map for node 1\n");

  	 	dbg(GENERAL_CHANNEL,"Current graph size = %d\n",call myMap.size());

  	 	printGraph();
  	 	printCostMap();
  	 
  	 	for(i = 0; i < call myMap.size(); i++)
  	 	{
  	 		map = call myMap.get(i);

  	 		dbg(GENERAL_CHANNEL,"Port for %d is %d\n", map.ID,portCalc(map.ID));
  	 	} 

  	 }
*/
 
  }
  
 ////////////////////////////////////////////
   event void periodicTimer.fired()
    {
      uint8_t wo[2];
      uint8_t * wow = wo;
      wo[0] = 'W';
      wo[1] = 'O';
      
      
      makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL , PROTOCOL_NEIGHBORDISC, 0, wow, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, AM_BROADCAST_ADDR);
      
    /* 
      if (neighborChange())
      {
      	updateNeighbors();
      	//sendNeighbors();
      	//printNeighbors();
      }
    */
      sendNeighbors();

    }
  ////////////////////////////////////////////


   event void AMControl.startDone(error_t err){
      time_t t;
      if(err == SUCCESS){
         srand((unsigned) time(&t));
         dbg(GENERAL_CHANNEL, "Radio On\n");
         call periodicTimer.startPeriodic(rand()%10000);
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){
     printCheckList();
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

         if (!call Hash.contains(myMsg->src))
              call Hash.insert(myMsg->src,-1);

         if (myMsg->protocol == PROTOCOL_NEIGHBORDISC)
         {
         	if (myMsg->dest == TOS_NODE_ID)
         	{
              int size = call CheckList.size();
              int i = 0;
            
            
              for (i = 0; i < size; i++)
              {
                if (call CheckList.get(i) == myMsg->src)
                  return msg;
              }

             
              call CheckList.pushfront(myMsg->src);
            }
            else
            {
            	makePack(&sendPackage, TOS_NODE_ID, myMsg->src, myMsg->TTL, PROTOCOL_NEIGHBORDISC, 0, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
              	call Sender.send(sendPackage, AM_BROADCAST_ADDR);
            }
         }

         if (call Hash.get(myMsg->src) >= myMsg->seq || myMsg->TTL <= 0)
         	return msg;

         call Hash.remove(myMsg->src);
         call Hash.insert(myMsg->src,myMsg->seq);
         
         if (myMsg->protocol == PROTOCOL_PING || myMsg->protocol == PROTOCOL_PINGREPLY)
         {
           // This is what causes the flooding 

            if (myMsg->dest == TOS_NODE_ID)
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
              	call Hash.insert(TOS_NODE_ID,sequence);
              	sequence = sequence + 1;

              	if (myMsg->src == AM_BROADCAST_ADDR)
	          		call Sender.send(sendPackage, AM_BROADCAST_ADDR);
	          	else if (call CostMap.contains(myMsg->src) && !call CostMap.get(myMsg->src) == COST_MAX)
	          	{
	          		dbg(GENERAL_CHANNEL,"Routing being used: %d is passing to %d\n",TOS_NODE_ID,myMsg->src);
	          		call Sender.send(sendPackage, portCalc(myMsg->dest));
	          	}
              
              }

            }
            else
            {
	          	makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);

	          	//dbg(GENERAL_CHANNEL, "Package arrived to possibly be put to sent to a port\n");
	          	
	          	if (myMsg->dest == AM_BROADCAST_ADDR)
	          	{
	          		//dbg(GENERAL_CHANNEL, "Package being sent to %d\n",myMsg->dest);
	          		//printCostMap();
	          		call Sender.send(sendPackage, AM_BROADCAST_ADDR);
	          	}
	          	else if (call CostMap.contains(myMsg->dest) && !call CostMap.get(myMsg->dest) == COST_MAX))
	          	{
	          		dbg(GENERAL_CHANNEL,"Routing being used: %d is passing to %d\n",TOS_NODE_ID,myMsg->dest);
	          		call Sender.send(sendPackage, portCalc(myMsg->dest));
	          	}
            }
         }
         else if (myMsg->protocol == PROTOCOL_LINKSTATE)
         {

         	if(containInTopology(myMsg->src))
         	{
         		deleteFromTopology(myMsg->src);
         		addToTopology(myMsg->src,myMsg->payload);
         		//dbg(GENERAL_CHANNEL,"It's already in topology\n");
         		//dbg(GENERAL_CHANNEL,"%d sent payload:\n%s\n",myMsg->src,myMsg->payload);

         	}
         	else
         	{
         		//dbg(GENERAL_CHANNEL,"Message being received from %d to %d\n",myMsg->src,TOS_NODE_ID);
         		addToTopology(myMsg->src,myMsg->payload);

         		calcShortestRoute();

         		//printGraph();

         		//printCostMap();

         		makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
              	call Sender.send(sendPackage, AM_BROADCAST_ADDR);
         	}
         
         }

         /*
         if (myMsg->dest != AM_BROADCAST_ADDR && call RoutingMap.contains(myMsg->dest))
         {
         	// This is where the main routing would go

         	makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->TTL, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
            call Sender.send(sendPackage, portCalc(myMsg->dest);

         }
         */
         
         
         
         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, sequence, payload, PACKET_MAX_PAYLOAD_SIZE);
      //call Sender.send(sendPackage, AM_BROADCAST_ADDR);
      
      if (destination == AM_BROADCAST_ADDR || !call CostMap.contains(destination) || call CostMap.get(destination) == COST_MAX)
	  	call Sender.send(sendPackage, AM_BROADCAST_ADDR);
	  else
	  {
	   	//dbg(GENERAL_CHANNEL,"Routing being used\n");
	   	call Sender.send(sendPackage, portCalc(destination));
      }
      call Hash.insert(TOS_NODE_ID,sequence);
  
      sequence = sequence + 1;
   }

   event void CommandHandler.printNeighbors()
   {
      printCheckList();
   }

   event void CommandHandler.printRouteTable()
   {
   	 uint32_t *keys = call RoutingMap.getKeys();

   	 dbg(ROUTING_CHANNEL,"Routing table for node : %d",TOS_NODE_ID);

   	 while(*keys)
   	 {
   	 	dbg(ROUTING_CHANNEL,"	For node %d, it has next hop of %d",*keys,call RoutingMap.get(*keys));
   	 	keys++;
   	 }
   }

   event void CommandHandler.printLinkState()
   {
   	 dbg(ROUTING_CHANNEL,"Link map state for node : %d",TOS_NODE_ID);

   	 printGraph();
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
}