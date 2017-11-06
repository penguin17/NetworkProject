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
   uses interface List<int> as ExpandedList;
   uses interface List<linkstate> as myMap;
   uses interface List<int> as SimpleCheck;
   //uses interface List<pack> as savedMessages;

   uses interface Hashmap<int> as Hash;

   uses interface Hashmap<int> as CostMap;

   uses interface Hashmap<int> as RoutingMap;

   uses interface Hashmap<linkstate> as tempMap;

   uses interface Hashmap<linkstate> as transferMap;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   uses interface NodeCommunication as nodeComp;
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
   void printCostMap();
   bool containInTopology(int source);
   void deleteFromTopology(int);

   void mySend(pack* myMsg, uint32_t dest)
   {
      if (!call nodeComp.sendCheck(myMsg,dest))
      {
        if (myMsg->src == TOS_NODE_ID)
          sequence++;
        myMsg->TTL = myMsg->TTL - 1;
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

  	if (containInTopology(TOS_NODE_ID))
  		deleteFromTopology(TOS_NODE_ID);

  	addToTopology(TOS_NODE_ID,der);

	
	makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL , PROTOCOL_LINKSTATE, sequence, der, PACKET_MAX_PAYLOAD_SIZE);
	call Hash.remove(TOS_NODE_ID);
	call Hash.insert(TOS_NODE_ID,sequence);
  call Sender.send(sendPackage, AM_BROADCAST_ADDR);
  sequence = sequence + 1;  
    
  }
    
   event void periodicTimer.fired()
    {
      uint8_t wo[2];
      pack tempPack;
      uint8_t * wow = wo;
      wo[0] = 'W';
      wo[1] = 'O';
      
      
      makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL , PROTOCOL_NEIGHBORDISC, 0, wow, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, AM_BROADCAST_ADDR);
    
      if (neighborChange())
      {
      	updateNeighbors();
      	sendNeighbors();
      	//printGraph();
      }
    
    }

  	event void sendingNeighborsTimer.fired()
  	{
  		sendNeighbors();
  	}

  	event void deleteMapTimer.fired()
  	{
  		while(!call myMap.isEmpty())
  		{
  			call myMap.popfront();
  		}
  	}
   event void AMControl.startDone(error_t err){
      time_t t;
      int myTime;
      int i = 0;

      call SimpleCheck.pushfront(TOS_NODE_ID);

      call NodeCommunication.initializeNode(TOS_NODE_ID);

      if (TOS_NODE_ID == 1)
      	srand(time(NULL));


      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL,"Radio On\n");
         myTime = rand()%(1000 + 1 - 100) + 100;
         
         call periodicTimer.startPeriodic(rand()%(10000 + 1 - 9000) + 9000);
         call sendingNeighborsTimer.startPeriodic(15*myTime);
         call deleteMapTimer.startPeriodic(1000000);
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
        call Sender.send(sendPackage, myMsg->src);
      }
   }

   void pingRegHandle(pack* myMsg)
   {
      makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);

      if (myMsg->dest == AM_BROADCAST_ADDR)
      {
        dbg(GENERAL_CHANNEL, "Package being passed along by %d\n",TOS_NODE_ID);
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
      }
      else if (call RoutingMap.contains(myMsg->dest) && call RoutingMap.get(myMsg->dest) != COST_MAX)
      {
        call Sender.send(sendPackage, portCalc(myMsg->dest));
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

        if (myMsg->src == AM_BROADCAST_ADDR)
        {
          call Sender.send(sendPackage, AM_BROADCAST_ADDR);
          call Hash.remove(TOS_NODE_ID);
          call Hash.insert(TOS_NODE_ID,sequence);
          sequence = sequence + 1;
        }
        else if (call RoutingMap.contains(myMsg->src) && call RoutingMap.get(myMsg->src) != COST_MAX)
        {
          //dbg(GENERAL_CHANNEL,"Routing being used: %d is passing to %d\n",TOS_NODE_ID,myMsg->src);
          call Sender.send(sendPackage, portCalc(myMsg->src));

          call Hash.remove(TOS_NODE_ID);
          call Hash.insert(TOS_NODE_ID,sequence);
          sequence = sequence + 1;
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

         if (!call Hash.contains(myMsg->src))
              call Hash.insert(myMsg->src,-1);

         if(myMsg->TTL <= 0)
         	return msg;

         if (myMsg->protocol == PROTOCOL_NEIGHBORDISC)
         {
         	
            neighborHandle(myMsg);
            return msg;
         }

         if (call Hash.get(myMsg->src) >= myMsg->seq)
         	return msg;

         call Hash.remove(myMsg->src);
         call Hash.insert(myMsg->src,myMsg->seq);
        

         if (myMsg->protocol == PROTOCOL_PING || myMsg->protocol == PROTOCOL_PINGREPLY)
         {
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
            call nodeComp.receiveLinkState(myMsg);

            makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
            call Sender.send(sendPackage, AM_BROADCAST_ADDR);
         }
         
        
      }
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
    dbg(GENERAL_CHANNEL, "PING EVENT \n");
    
    makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, sequence, payload, PACKET_MAX_PAYLOAD_SIZE);
    //call Sender.send(sendPackage, AM_BROADCAST_ADDR);
    
    calcShortestRoute();
    

    if (destination == AM_BROADCAST_ADDR)
  	 call Sender.send(sendPackage, AM_BROADCAST_ADDR);
	  else if (call RoutingMap.contains(destination) && call RoutingMap.get(destination) != COST_MAX)
	  {
	   	dbg(GENERAL_CHANNEL,"Routing being used to send ping\n");
	   	call Sender.send(sendPackage, portCalc(destination));
    }
    else
    {
      dbg(GENERAL_CHANNEL,"Message being dropped before it's even sent\n");
    }
    call Hash.remove(TOS_NODE_ID);
    call Hash.insert(TOS_NODE_ID,sequence);
	  
    sequence = sequence + 1;

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

   event void NodeCommunication.sendPack(pack msg,uint16_t dest)
   {

   }
   event void NodeCommunication.pingNeighbors()
   {

   }
}