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

   uses interface Hashmap<int> as Hash;

   uses interface Hashmap<int> as CostMap;

   uses interface Hashmap<int> as NeighborMap;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;
}

implementation{
   pack sendPackage;
   uint16_t sequence = 0;
   bool printTime = FALSE;
   bool first = TRUE;
   linkstate map[GRAPH_NODE_MAX];
   uint16_t currentMaxNode = -1;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   void calcShortestRoute();
   void addToTopology(int source, uint8_t *neighbors);

   void printNeighbors()
   {
     int i = 0;

     dbg(NEIGHBOR_CHANNEL,"List of neighbors for node %d\n",TOS_NODE_ID);

     for(i = 0; i < call NeighborList.size(); i++)
     {
        dbg(NEIGHBOR_CHANNEL,"Node: %d\n",call NeighborList.get(i));
     }
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

  	for (i = 0; i < 20; i++)
  		derp[i] = '*';

  	dbg(GENERAL_CHANNEL,"%d is sending link state information\n",TOS_NODE_ID);

  	for (i = 0; i < call NeighborList.size(); i++)
  	{
  		sprintf(temp,"%d*",call NeighborList.get(i));
  		tempSize = strlen(temp);
  		dbg(GENERAL_CHANNEL,"-- %s\n",temp);
  		for(j = 0; j < tempSize; j++)
  		{
  			derp[currSize+j] = temp[j];
  		}

  		currSize = currSize + tempSize;

  		if (TOS_NODE_ID == 19)
  			dbg(GENERAL_CHANNEL,"tempSize = %d for i = %d\n",tempSize,i);
  	}

  	dbg(GENERAL_CHANNEL,"The derp message being sent = %s\n",derp);

  	addToTopology(TOS_NODE_ID,der);

	makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL , PROTOCOL_LINKSTATE, sequence, der, PACKET_MAX_PAYLOAD_SIZE);
	sequence = sequence + 1;
    call Sender.send(sendPackage, AM_BROADCAST_ADDR);  	
  }

  void printGraph()
  {
  	int i = 0;
  	int j = 0;

  	if (currentMaxNode == -1)
  	{
  		return;
  	}

  	for (i = 0; i <= currentMaxNode; i++)
  	{
  		dbg(GENERAL_CHANNEL,"Neighbors for node: %d\n",map[i].ID);

  		for (j = 0; j <= map[i].currMaxNeighbors; j++)
  		{
  			dbg(GENERAL_CHANNEL,"%d\n",map[i].neighbors[j]);
  		}
  	}
  }
  void addToTopology(int source, uint8_t *neighbors)
  {
  	int arr[NEIGHBOR_MAX];
  	int count = 0;
  	int val = 0;
  	uint8_t *p = neighbors;

  	if (currentMaxNode == GRAPH_NODE_MAX)
  	{
  		dbg(GENERAL_CHANNEL,"***Limit of nodes to add has been reached for graph***\n");
  	}

  	currentMaxNode = currentMaxNode + 1;

  	map[currentMaxNode].ID = source;
  	map[currentMaxNode].currMaxNeighbors = -1;

  	while(*p)
  	{
  		if(isdigit(*p))
  		{
  			val = strtol(p,&p,10);

  			if (map[currentMaxNode].currMaxNeighbors == GRAPH_NODE_MAX)
		  	{
		  		dbg(GENERAL_CHANNEL,"***Limit of nodes to add has been reached for neighbors***\n");
		  	}

  			map[currentMaxNode].currMaxNeighbors = map[currentMaxNode].currMaxNeighbors + 1;
  			map[currentMaxNode].neighbors[map[currentMaxNode].currMaxNeighbors] = val;
  			
  			//dbg(GENERAL_CHANNEL,"%d\n",val);
  		}
  		else
  		{
  			p++;
  		}
  	}

  	//calcShortestRoute();
  }

  void deleteFromTopology(int source)
  {

  }
  bool containInTopology(int source)
  {

  }
  void calcShortestRoute()
  {

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
      
     
      if (neighborChange())
      {
      	updateNeighbors();
      	sendNeighbors();
      }

    }
  ////////////////////////////////////////////


   event void AMControl.startDone(error_t err){
      time_t t;
      if(err == SUCCESS){
         srand((unsigned) time(&t));
         dbg(GENERAL_CHANNEL, "Radio On\n");
         call periodicTimer.startPeriodic(rand()%100000);
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
         /////////////////////////////////////////////////////////////////////////////////
         myMsg->TTL = myMsg->TTL - 1;

         if (!call Hash.contains(myMsg->src))
              call Hash.insert(myMsg->src,-1);

         /*
         if (myMsg->dest != AM_BROADCAST_ADDR && call NeighborMap.contains(myMsg->dest))
         {
         	// This is where the main routing would go

         	makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->TTL, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
            call Sender.send(sendPackage, call NeighborMap.get(myMsg->dest));

         }
         */
         if (call Hash.get(myMsg->src) < myMsg->seq && myMsg->protocol != PROTOCOL_NEIGHBORDISC)
         {
           // This is what causes the flooding 

            call Hash.remove(myMsg->src);
            call Hash.insert(myMsg->src,myMsg->seq);

            if (myMsg->dest == TOS_NODE_ID)
            {

              if (myMsg->protocol == PROTOCOL_PINGREPLY)
              {
              	dbg(FLOODING_CHANNEL, "Message Acceptance from %d received\n",myMsg->src);
              }
              else
              {
              	dbg(FLOODING_CHANNEL, "Packet has finally flooded to correct location, from:to, %d:%d\n", myMsg->src,myMsg->dest);
              	dbg(FLOODING_CHANNEL, "Package Payload: %s\n", myMsg->payload);
              	dbg(FLOODING_CHANNEL, "Message being sent to %d for aknowledgement of message received by %d\n",myMsg->src,myMsg->dest);
              	makePack(&sendPackage, myMsg->dest, myMsg->src, myMsg->TTL, PROTOCOL_PINGREPLY, sequence, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
              	call Hash.insert(TOS_NODE_ID,sequence);
              	sequence = sequence + 1;
              	call Sender.send(sendPackage, AM_BROADCAST_ADDR);
              }

            }
            else
            {
              if (myMsg->TTL <= 0)
              	return msg;
              else
              {
              	makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
              	call Sender.send(sendPackage, AM_BROADCAST_ADDR);
              }
            }
         }
         else if (myMsg->protocol == PROTOCOL_NEIGHBORDISC)
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
         else if (myMsg->protocol == PROTOCOL_LINKSTATE && call Hash.get(myMsg->src) < myMsg->seq)
         {
         /*
         	if(containInTopology(myMsg->src))
         	{
         		deleteFromTopology(myMsg->src);
         		addToTopology(myMsg->src,myMsg->payload);
         	}
         	else
         	{
         		addToTopology(myMsg->src,myMsg->payload);
         	}
         */
         }
         
         return msg;
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, sequence, payload, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, AM_BROADCAST_ADDR);
      
      call Hash.insert(TOS_NODE_ID,sequence);
  
      sequence = sequence + 1;
   }

   event void CommandHandler.printNeighbors()
   {
      printCheckList();
   }

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

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