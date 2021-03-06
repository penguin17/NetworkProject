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
#include "includes/socket.h"

module Node{
   uses interface Boot;

   uses interface Timer<TMilli> as periodicTimer; //Interface that was wired above.
   uses interface Timer<TMilli> as sendingNeighborsTimer;
   uses interface Timer<TMilli> as deleteMapTimer;
   uses interface Timer<TMilli> as writeTimer;
   uses interface Timer<TMilli> as readTimer;
   uses interface Timer<TMilli> as reliabilityTimer;

   uses interface SplitControl as AMControl;
   uses interface Receive;
   uses interface List<int> as NeighborList;
   uses interface List<int> as CheckList;
   //uses interface List<pack> as savedMessages;
   uses interface List<outstandTCP> as outstandingMessages;

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
   uses interface Hashmap<socket_store_t> as socketHash;
   uses interface Transport;
   uses interface Hashmap<socket_t> as socketIdentifier;
   uses interface Hashmap<socket_addr_t> as socketConnections;
   uses interface Hashmap<seqInformation> as seqInfo;
   //uses interface Hashmap<uint32_t> as Derp;
   //uses interface Test;
}

implementation{
   pack sendPackage;
   uint16_t sequence = 0;
   bool printTime = FALSE;
   bool first = TRUE;
   linkstate map;
   uint16_t currentMaxNode = -1;
   uint16_t currentCount;
   uint16_t maxDataTransfer;


   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   //void calcShortestRoute();
   //void addToTopology(int source, uint8_t *neighbors);
   void printGraph();
   void printCostMap();
   bool containInTopology(int source);
   void deleteFromTopology(int);
   void linkStateChange();
   void calcRoute();
   uint32_t portCalc(uint32_t node);

   event void reliabilityTimer.fired()
   {
   		outstandTCP temp;
   		uint32_t i = 0;
   		uint32_t size = call outstandingMessages.size();
   		seqInformation seqIn;
   		socket_store_t socket;
/*
   		dbg(GENERAL_CHANNEL,"==============================\n");
   		dbg(GENERAL_CHANNEL,"Should be getting called a lot at time = %u\n",call reliabilityTimer.getNow());
   		dbg(GENERAL_CHANNEL,"==============================\n");
*/
   		for (i = 0; i < size; i++)
   		{
   			temp = call outstandingMessages.popback();
   			seqIn = call seqInfo.get(temp.fd);
   			socket = call socketHash.get(temp.fd);

   			if (temp.seqNum >= seqIn.currAck && temp.expectedTime > call reliabilityTimer.getNow())
   			{
   				//dbg(GENERAL_CHANNEL,"++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
   				//dbg(GENERAL_CHANNEL,"Message is being put back into list\n");
   				call outstandingMessages.pushfront(temp);
   				continue;
   			}
   			else if (temp.seqNum >= seqIn.currAck && temp.expectedTime <= call reliabilityTimer.getNow())
   			{

   			dbg(GENERAL_CHANNEL,"==============================\n");
   			dbg(GENERAL_CHANNEL,"Message being resent at time = %u\n",call reliabilityTimer.getNow());
   			dbg(GENERAL_CHANNEL,"==============================\n");
   			/*
   				dbg(GENERAL_CHANNEL, "===============================Reliability timer found a message that hasn't been received yet**********\n");
   				dbg(GENERAL_CHANNEL,"temp.seqNum = %u\n",temp.seqNum);
   				dbg(GENERAL_CHANNEL,"seqIn.currAck = %u\n",seqIn.currAck);
   				dbg(GENERAL_CHANNEL,"expectedTime = %u\n",temp.expectedTime);
   				dbg(GENERAL_CHANNEL,"Current time = %u\n",call reliabilityTimer.getNow());
   			 */
   				calcRoute();
   				temp.currPack.seq = sequence;
   				sequence++;
   				call Sender.send(temp.currPack,portCalc(temp.currPack.dest));
   				temp.expectedTime = 2*socket.RTT + call reliabilityTimer.getNow();
   				call outstandingMessages.pushfront(temp);
   			}
   			else
   			{/*
   				dbg(GENERAL_CHANNEL,"++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
   				dbg(GENERAL_CHANNEL,"Message getting dropped contains:\n");
   				dbg(GENERAL_CHANNEL,"temp.seqNum = %u\n",temp.seqNum);
   				dbg(GENERAL_CHANNEL,"seqIn.currAck = %u\n",seqIn.currAck);
   				dbg(GENERAL_CHANNEL,"expectedTime = %u\n",temp.expectedTime);
   				dbg(GENERAL_CHANNEL,"Current time = %u\n",call reliabilityTimer.getNow());
   				dbg(GENERAL_CHANNEL,"++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
   			*/
   			}


   		}
   }

   TCPpack translateMsg(uint8_t* payload)
  {
    uint8_t arr[20];
    TCPpack derp;
    uint8_t temp8;
    uint16_t temp16;
    uint32_t temp32;

    memcpy(arr,payload,20);

    derp.srcPort = 0;
    derp.srcPort = arr[0]<<8;
    derp.srcPort = derp.srcPort|arr[1];


    derp.destPort = 0;
    derp.destPort = arr[2]<<8;
    derp.destPort = derp.destPort|arr[3];

    derp.flags[0] = arr[4];
    derp.flags[1] = arr[5];

    derp.seq = 0;
    derp.seq = arr[6]<<24;
    derp.seq = derp.seq|(arr[7]<<16);
    derp.seq = derp.seq|(arr[8]<<8);
    derp.seq = derp.seq|arr[9];

    derp.ack = 0;
    derp.ack = arr[10]<<24;
    derp.ack = derp.ack|(arr[11]<<16);
    derp.ack = derp.ack|(arr[12]<<8);
    derp.ack = derp.ack|arr[13];

    derp.advertisedWindow = arr[14]<<16;
    derp.advertisedWindow = derp.advertisedWindow|arr[15];

    memcpy(derp.data,arr+16,4);

    dbg(GENERAL_CHANNEL,"Time = %u\n",call periodicTimer.getNow());
    dbg(GENERAL_CHANNEL,"Pack Received information (From NODE FILE):\n");
    dbg(GENERAL_CHANNEL,"\tSource Port = %d\n",derp.srcPort);
    dbg(GENERAL_CHANNEL,"\tDestination Port = %d\n",derp.destPort);
    dbg(GENERAL_CHANNEL,"\tFlag 0 = %d and Flag 1 = %d\n",derp.flags[0],derp.flags[1]);
    dbg(GENERAL_CHANNEL,"\tSeq = %u\n",derp.seq);
    dbg(GENERAL_CHANNEL,"\tAck = %u\n",derp.ack);
    dbg(GENERAL_CHANNEL,"\tAdvertised Window = %d\n",derp.advertisedWindow);
    dbg(GENERAL_CHANNEL,"\tData = %s\n",derp.data);

    return derp;

  }
  void setupSeqInformation(socket_t fd, uint32_t seq, uint32_t ack)
  {
    seqInformation derp;

    derp.lastAck = seq;
    derp.lastSent = seq;

    derp.lastRcvd = seq;
    derp.nextExpected = seq+1;

    derp.currSeq = seq;
    derp.currAck = ack;

    call seqInfo.insert(fd,derp);
  }
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
      socket_t fd;
      socket_addr_t addr;
      socket_store_t socket;

      call AMControl.start();
      dbg(GENERAL_CHANNEL, "Booted\n");

      if(TOS_NODE_ID == 1)
      {
	      dbg(GENERAL_CHANNEL,"Server on node %d being called with port value %d\n",TOS_NODE_ID,41);

	      fd = call Transport.socket();

	      socket = call socketHash.get(fd);
	      socket.RTT = 20000;

	      call socketHash.remove(fd);
	      call socketHash.insert(fd,socket);

	      addr.port = 41;
	      addr.addr = TOS_NODE_ID;

	      call Transport.bind(fd,&addr);

	      call Transport.listen(fd);
	  }
   }
  void printNeighbors()
  {
    int i = 0;

    dbg(GENERAL_CHANNEL, "For node %d: Time = %u\n",TOS_NODE_ID,call periodicTimer.getNow());

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
    void setupTCPpacket(socket_t fd, uint8_t* data)
    {
      int i = 0;
      socket_store_t socket = call socketHash.get(fd);
      seqInformation seqIn = call seqInfo.get(fd);

      //dbg(GENERAL_CHANNEL,"BEFORE\n");
      //dbg(GENERAL_CHANNEL,"\tlastSent = %u\n",socket.lastSent);

      for (i = 0; i < 4; i++)
      {
        if (socket.lastSent == socket.lastWritten)
        {
          // Be aware that changed data[i] = 0 to = socket.sendBuff[socket.lastSent];
            
          dbg(GENERAL_CHANNEL,"For some reason it's inside the lastsent == lastWritten\n");
          dbg(GENERAL_CHANNEL,"AFTER\n");
      	  dbg(GENERAL_CHANNEL,"\tlastSent = %u\n",socket.lastSent);

          
          data[i] = 0;
          call seqInfo.remove(fd);
          call seqInfo.insert(fd,seqIn);

          call socketHash.remove(fd);
          call socketHash.insert(fd,socket);

          return;
        }
        else if ((socket.lastSent+1) == 128)
        {
          data[i] = socket.sendBuff[0];
          socket.lastSent = 0;
          seqIn.lastSent++;

          //dbg(GENERAL_CHANNEL,"Send buff contents\n");
          
          //dbg(GENERAL_CHANNEL,"%s\n",socket.sendBuff);
          
          //dbg(GENERAL_CHANNEL,"Checking to see if this is even being called\n");
        }
        else
        {
          socket.lastSent++;
          data[i] = socket.sendBuff[socket.lastSent];

          seqIn.lastSent++;
        }

        if (socket.lastSent >= 128)
          socket.lastSent = 0;
      }

      // Why is this even here??
      if (data[4] == 0)
        data[4] = 0;

        //dbg(GENERAL_CHANNEL,"Send buff contents\n");
        //dbg(GENERAL_CHANNEL,"%s\n",socket.sendBuff);
      dbg(GENERAL_CHANNEL,"The ending string == %s\n",data);
      //dbg(GENERAL_CHANNEL,"AFTER\n");
      //dbg(GENERAL_CHANNEL,"\tlastSent = %u\n",socket.lastSent);
      call seqInfo.remove(fd);
      call seqInfo.insert(fd,seqIn);

      call socketHash.remove(fd);
      call socketHash.insert(fd,socket);
    }
    uint8_t writeAble(socket_t fd)
    {
      socket_store_t socket = call socketHash.get(fd);

      if (socket.lastWritten == (socket.lastAck - 1) || (socket.lastWritten == 127 && socket.lastAck == 0))
        return 0;

      //dbg(GENERAL_CHANNEL,"SocketlastAck = %u\n",socket.lastAck);
      //dbg(GENERAL_CHANNEL,"SocketlastWritten = %u\n",socket.lastWritten);

      if (socket.lastWritten > socket.lastAck)
        return SOCKET_BUFFER_SIZE - socket.lastWritten + socket.lastAck;
      else if (socket.lastWritten < socket.lastAck)
        return (socket.lastAck - socket.lastWritten - 1);
      else
        return SOCKET_BUFFER_SIZE;
    }
    bool ackSocket(socket_t fd, uint32_t ack)
    {
      socket_store_t socket = call socketHash.get(fd);
      seqInformation seqIn = call seqInfo.get(fd);
 
      

      if (ack >= 128)
      {
        dbg(GENERAL_CHANNEL, "***********ackSocket has ack coming in with ack value equal to or greater than 128\n");
        return FALSE;
      }

      

      if (socket.lastSent > socket.lastAck)
      {
        if (ack > socket.lastAck && ack  < socket.lastSent)
        {
          seqIn.lastAck += ack - socket.lastAck - 1;
          socket.lastAck = ack -1;

          call seqInfo.remove(fd);
          call seqInfo.insert(fd,seqIn);

          call socketHash.remove(fd);
          call socketHash.insert(fd,socket);

          

          return TRUE;
        }
        else if (ack == (socket.lastSent + 1) || (ack == 0 && socket.lastSent == 127))
        {
          seqIn.lastAck += ack - socket.lastAck - 1;
          socket.lastAck = ack-1;
          //socket.lastSent = ack-1;

          call seqInfo.remove(fd);
          call seqInfo.insert(fd,seqIn);

          call socketHash.remove(fd);
          call socketHash.insert(fd,socket);

          

          return TRUE;
        }
        else
        {
          dbg(GENERAL_CHANNEL,"Encountered scenario in lastSent > lastAck that didn't account for\n");
          dbg(GENERAL_CHANNEL,"ack = %u\n",ack);
          dbg(GENERAL_CHANNEL,"socket.lastSent = %u\n",socket.lastSent);
          dbg(GENERAL_CHANNEL,"socket.lastAck = %u\n",socket.lastAck);
        }
      }
      else if (socket.lastAck > socket.lastSent)
      {
        if ((ack == (socket.lastSent + 1) || (ack == 0 && socket.lastSent == 127)) && ack < socket.lastAck)
        {

          while (socket.lastAck != socket.lastSent)
          {
            socket.lastAck++;
            seqIn.lastAck++;

            if (socket.lastAck >= 128)
              socket.lastAck = 0;
          }

          call seqInfo.remove(fd);
          call seqInfo.insert(fd,seqIn);

          call socketHash.remove(fd);
          call socketHash.insert(fd,socket);

          
          return TRUE;
        }
        else if (ack > socket.lastAck && ack > socket.lastSent)
        {
          seqIn.lastAck += ack - socket.lastAck - 1;
          socket.lastAck = ack;

          call seqInfo.remove(fd);
          call seqInfo.insert(fd,seqIn);
          call socketHash.remove(fd);
          call socketHash.insert(fd,socket);

          

          return TRUE;
        }
        else if (ack < socket.lastSent && ack < socket.lastAck)
        {
          uint32_t oneBefore = 0;

          if (ack == 0)
            oneBefore = 127;
          else
            oneBefore = ack - 1;

          while(socket.lastAck != oneBefore)
          {
            socket.lastAck++;
            seqIn.lastAck++;

            if(socket.lastAck >= 128)
            {
              socket.lastAck = 0;
            }
          }


          call seqInfo.remove(fd);
          call seqInfo.insert(fd,seqIn);

          call socketHash.remove(fd);
          call socketHash.insert(fd,socket);

          
          return TRUE;
        }
        

        
      }
    
    	dbg(GENERAL_CHANNEL,"ACKSOCKET DIDN'T GO IN ANY OF OPTIONS\n");
        return FALSE;

    }
    uint32_t processData(socket_t fd, uint8_t* data, uint32_t seq)
    {
      int i = 0;
      uint32_t count = 0;
      socket_store_t socket = call socketHash.get(fd);
      seqInformation seqIn = call seqInfo.get(fd);



    
  	  if (seq != socket.nextExpected)
      {
        dbg(GENERAL_CHANNEL,"Not the right expected seq value\n");
        dbg(GENERAL_CHANNEL,"Seq = %u\n",seq);
        dbg(GENERAL_CHANNEL,"nextExpected = %u\n",socket.nextExpected);
        return 0;
      }
      else if (seq == socket.nextExpected)
      {
      	//dbg(GENERAL_CHANNEL,"seq = socket.nextExpected\n");
      }

      //dbg(GENERAL_CHANNEL,"BEGINNING:\n");
      //dbg(GENERAL_CHANNEL,"\tnextExpected = %u\n",socket.nextExpected);
      //dbg(GENERAL_CHANNEL,"\tlastRcvd = %u\n",socket.lastRcvd);

      for (i = 0; i < 4; i++)
      {
        if (socket.nextExpected == socket.lastRead)
        {
          //dbg(GENERAL_CHANNEL,"processData going somewhere it shouldn't be going\n");
          //dbg(GENERAL_CHANNEL,"ENDINGING:\n");
      	  //dbg(GENERAL_CHANNEL,"\tnextExpected = %u\n",socket.nextExpected);
      	  //dbg(GENERAL_CHANNEL,"\tlastRcvd = %u\n",socket.lastRcvd);

          call seqInfo.remove(fd);
          call seqInfo.insert(fd,seqIn);

          call socketHash.remove(fd);
          call socketHash.insert(fd,socket);
          return count;
        }
        else
        {
          if (data[i] == 0)
          {
            //dbg(GENERAL_CHANNEL,"======= Returning count at i = %d because data[i] = 0",i);
            //socket.nextExpected++;
            //dbg(GENERAL_CHANNEL,"ENDINGING:\n");
      	  //dbg(GENERAL_CHANNEL,"\tnextExpected = %u\n",socket.nextExpected);
      	  //dbg(GENERAL_CHANNEL,"\tlastRcvd = %u\n",socket.lastRcvd);
            call seqInfo.remove(fd);
            call seqInfo.insert(fd,seqIn);

            call socketHash.remove(fd);
            call socketHash.insert(fd,socket);
            return count;
          } 
          socket.rcvdBuff[socket.nextExpected] = data[i];
          
          socket.nextExpected++;
          seqIn.nextExpected++;
          socket.lastRcvd++;
          seqIn.lastRcvd++;

          if (socket.nextExpected >= 128)
            socket.nextExpected = 0;
          else if (socket.lastRcvd >= 128)
            socket.lastRcvd = 0;
          count++;
        }
      }

      //dbg(GENERAL_CHANNEL,"ENDINGING:\n");
      	  //dbg(GENERAL_CHANNEL,"\tnextExpected = %u\n",socket.nextExpected);
      	  //dbg(GENERAL_CHANNEL,"\tlastRcvd = %u\n",socket.lastRcvd);
      call seqInfo.remove(fd);
      call seqInfo.insert(fd,seqIn);

      call socketHash.remove(fd);
      call socketHash.insert(fd,socket);

      return count;
    }
    event void readTimer.fired()
    {
      uint8_t buff[128];
      uint32_t* keys = call socketHash.getKeys();

      while(*keys)
      {
        socket_store_t socket = call socketHash.get(*keys);
        uint32_t size = call Transport.read(*keys,buff,128);
        
        if(size != 0)
        {
          dbg(GENERAL_CHANNEL,"Socket %u from node %u has just read %s\n",*keys,TOS_NODE_ID,buff);
        }
        keys++;
      }

    }
    event void writeTimer.fired()
    {
      uint8_t buff[128];
      uint32_t* keys = call socketHash.getKeys();

      while(*keys)
      {
        socket_store_t socket = call socketHash.get(*keys);
        
        if (writeAble(*keys) != 0)
        {
          uint8_t allowableSize = writeAble(*keys);
          uint8_t currSize = 0;
          uint8_t size = 0;

          while(currSize < allowableSize && currentCount < maxDataTransfer)
          {
            size = sprintf(buff + currSize, "%u,",currentCount);

            if ((currSize + size) <= allowableSize)
            {  
              currentCount++;
              currSize += size;
            }
            else
              break;

          }

          if (currSize != 0)
          {uint16_t writeSize = 0;
            dbg(GENERAL_CHANNEL,"String being sent to written ======  %s\n",buff);
            dbg(GENERAL_CHANNEL,"currSize = %u\n",currSize);
            dbg(GENERAL_CHANNEL,"currentCount = %u\n",currentCount);
            dbg(GENERAL_CHANNEL,"LASTACK = %u\n",socket.lastAck);
            dbg(GENERAL_CHANNEL,"LASTSENT = %u\n",socket.lastSent);
            dbg(GENERAL_CHANNEL,"LASTWRITTEN = %u\n",socket.lastWritten);
            writeSize = call Transport.write(*keys,buff,currSize);

            socket = call socketHash.get(*keys);
            
            dbg(GENERAL_CHANNEL,"LASTACK = %u\n",socket.lastAck);
            dbg(GENERAL_CHANNEL,"LASTSENT = %u\n",socket.lastSent);
            dbg(GENERAL_CHANNEL,"LASTWRITTEN = %u\n",socket.lastWritten);
            dbg(GENERAL_CHANNEL,"AMOUNT THAT WAS SUCCESSFULLY WRITTEN = %u\n",writeSize);
            dbg(GENERAL_CHANNEL,"STRING OF WRITE BUFFER = %s\n",socket.sendBuff);
          }
        }

        keys++;
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
         myTime = rand()%(30000 + 1 - 10000) + 10000;

         dbg(GENERAL_CHANNEL,"Node %d\n",TOS_NODE_ID);
         dbg(GENERAL_CHANNEL,"  myTime = %d\n",myTime);
         
         call periodicTimer.startPeriodic(myTime);
         call sendingNeighborsTimer.startPeriodic(0.5*myTime);
         //call deleteMapTimer.startPeriodic(10000000);
         //call deleteMapTimer.startOneShot(3*myTime);
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

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
        //dbg(GENERAL_CHANNEL,"Routing being used: at %u\n",call periodicTimer.getNow());
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
   error_t x;
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         
         myMsg->TTL = myMsg->TTL - 1;

         if (myMsg->protocol == PROTOCOL_NEIGHBORDISC)
         {
         	
            neighborHandle(myMsg);
            return msg;
         }

        //dbg(GENERAL_CHANNEL,"Making sure that this isn't being called for some reason\n");
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


         if (myMsg->protocol == PROTOCOL_PING || myMsg->protocol == PROTOCOL_PINGREPLY || (myMsg->protocol == PROTOCOL_TCP && myMsg->dest != TOS_NODE_ID))
         {
            if (call CostMap.get(myMsg->src) <= 1)
              calcRoute();

            if (myMsg->dest == TOS_NODE_ID)
            {
                dbg(GENERAL_CHANNEL,"Channel has been received at time %d\n", call periodicTimer.getNow());
                pingDestHandle(myMsg);
            }
            else
            {
	          	  pingRegHandle(myMsg);
            }
           
         }
         else if (myMsg->protocol == PROTOCOL_TCP && myMsg->dest == TOS_NODE_ID)
         {
            TCPpack derp = translateMsg(myMsg->payload);
            outstandTCP out;
            uint16_t temp = 0;
            socket_t fd = call socketIdentifier.get(derp.destPort);
            socket_store_t addr = call socketHash.get(call socketIdentifier.get(derp.destPort));
            uint32_t timeSent = 0;
            socket_addr_t connect;
            seqInformation seqIn = call seqInfo.get(fd);

            if (!call socketHash.contains(call socketIdentifier.get(derp.destPort)))
            {
              dbg(GENERAL_CHANNEL, "Socket is trying to connect to socket that doesn't even exist\n");
            }

            //dbg(GENERAL_CHANNEL,"First Fd = %d\n",fd);

            if (derp.destPort != 41)
            {
	            if (call Transport.receive(myMsg) == FAIL)
	            {
	              dbg(GENERAL_CHANNEL, "There was an error coming from receive function\n");
	            }
            }

            temp = derp.destPort;

            derp.destPort = derp.srcPort;
            derp.srcPort = temp;


            if (derp.flags[0] == FLAG_SYN && derp.flags[1] == FLAG_NONE && addr.state == LISTEN)
            {
              socket_addr_t address;
		      socket_store_t socket;

              derp.flags[0] = FLAG_SYN;
              derp.flags[1] = FLAG_ACK;

              if (derp.srcPort == 41)
              {
              	  uint16_t port = 1;

              	  while(call socketIdentifier.contains(port))
              	  	port++;

			      dbg(GENERAL_CHANNEL,"Server on node %d being called with port value %d\n",TOS_NODE_ID,derp.destPort);

			      fd = call Transport.socket();

			      socket = call socketHash.get(fd);
			      socket.RTT = 20000;
			      socket.state = SYN_RCVD;

			      call socketHash.remove(fd);
			      call socketHash.insert(fd,socket);

			      address.port = port;
			      address.addr = TOS_NODE_ID;

			      call Transport.bind(fd,&address);

			      addr = call socketHash.get(fd);

			      derp.srcPort = port;
		      }

              setupSeqInformation(fd,0,derp.seq + 1);
              seqIn = call seqInfo.get(fd);
              derp.ack = addr.nextExpected;
              derp.seq = 0;
              derp.ack = 1;
            }
            else if (derp.flags[0] == FLAG_SYN && derp.flags[1] == FLAG_ACK && addr.state == SYN_SENT)
            {
              uint32_t currTime;
              derp.flags[0] = FLAG_ACK;
              derp.flags[1] = FLAG_NONE;
              connect.port = derp.destPort;
              connect.addr = myMsg->dest;

              call Transport.connect(fd,&connect);

              if (seqIn.currSeq < derp.ack)
              {
              	seqIn.currAck = derp.ack;
              	call seqInfo.remove(fd);
              	call seqInfo.insert(fd,seqIn);
              }
              else
              {
              	dbg(GENERAL_CHANNEL,"This is a message that was already acknowledged\n");
              	return msg;
              }

              //setupSeqInformation(fd,derp.seq,derp.ack);

              addr = call socketHash.get(fd);

              addr.RTT = call periodicTimer.getNow() - addr.RTT;

              derp.seq = 1;
              derp.ack = 1;

              dbg(GENERAL_CHANNEL, "RTT time is equal to = %u\n",addr.RTT);
              call socketHash.remove(fd);
              call socketHash.insert(fd,addr);

              makePack(&sendPackage,myMsg->dest,myMsg->src,MAX_TTL,myMsg->protocol,sequence,&derp,PACKET_MAX_PAYLOAD_SIZE);
              sequence++;
              calcRoute();
              call Sender.send(sendPackage,portCalc(myMsg->src));

              currTime = clock();

              while(clock() < addr.RTT + currTime)
              {
                //dbg(GENERAL_CHANNEL,"Wowzers found culprit?\n");
              }

              derp.flags[0] = FLAG_NONE;
              derp.flags[1] = FLAG_NONE;
              derp.seq = 1;
              derp.ack = 1;

              setupTCPpacket(fd,derp.data);


              makePack(&sendPackage,myMsg->dest,myMsg->src,MAX_TTL,myMsg->protocol,sequence,&derp,PACKET_MAX_PAYLOAD_SIZE);
              sequence++;
              
              out.currPack = sendPackage;
              out.expectedTime = 2*addr.RTT + call reliabilityTimer.getNow();
              out.seqNum = 1;
              out.fd = fd;
              call outstandingMessages.pushfront(out);

              calcRoute();
              call Sender.send(sendPackage,portCalc(myMsg->src));

              return msg;
            }
            else if (derp.flags[0] == FLAG_ACK && derp.flags[1] == FLAG_NONE && addr.state == SYN_RCVD)
            {
              
              connect.port = derp.destPort;
              connect.addr = myMsg->dest;

              call socketConnections.insert(fd,connect);

              call Transport.accept(fd);
              call readTimer.startPeriodic(10000);
              return msg;
            }
            else if (derp.flags[0] == FLAG_NONE && derp.flags[1] == FLAG_NONE && addr.state == ESTABLISHED)
            {
              uint8_t buff[128];
              uint32_t size = 0;
              uint32_t modSeq = 0;
              seqIn = call seqInfo.get(fd);
              addr = call socketHash.get(fd);

              //dbg(GENERAL_CHANNEL,"\tnextExpected = %u\n",addr.nextExpected);
              //dbg(GENERAL_CHANNEL,"\t\tit's seq number = %u\n",seqIn.nextExpected);

              if (seqIn.nextExpected == derp.seq && derp.seq < 128)
                modSeq = addr.nextExpected;
              else if (seqIn.nextExpected == derp.seq && derp.seq >=128)
              {
              	modSeq = seqIn.nextExpected - 128;

              	while(modSeq >= 128)
              		modSeq = modSeq-128;
              }
              else
                dbg(GENERAL_CHANNEL,"Got a problem here\n");

              processData(fd,derp.data,modSeq);
              
              seqIn = call seqInfo.get(fd);
              //dbg(GENERAL_CHANNEL,"()()()()()()()\n");
              //dbg(GENERAL_CHANNEL,"BEFORE:\n");
              //dbg(GENERAL_CHANNEL,"Last read = %u\n",addr.lastRead);
            /*
              size = call Transport.read(fd,buff,128);

              if (size <= 4)
              dbg(GENERAL_CHANNEL,"-==========---Data is this = %s\n",buff);
              else if (size > 4)
              dbg(GENERAL_CHANNEL,"========================================================================Read more than wanted = %s\n",buff);
            */  
              derp.seq = 1;

              addr = call socketHash.get(fd);
              derp.ack = seqIn.nextExpected;
              //dbg(GENERAL_CHANNEL,"()()()()()()()\n");
              //dbg(GENERAL_CHANNEL,"AFTER:\n");
              //dbg(GENERAL_CHANNEL,"Last read = %u\n",addr.lastRead);
              
              dbg(GENERAL_CHANNEL,"*****************************\n");
              dbg(GENERAL_CHANNEL,"Server sending tcp pack with:\n");
              dbg(GENERAL_CHANNEL,"\tSeq = %u\n",derp.seq);
              dbg(GENERAL_CHANNEL,"\tAck = %u\n",derp.ack);
              dbg(GENERAL_CHANNEL,"-----------------------------\n");
              dbg(GENERAL_CHANNEL,"\tnextExpected = %u\n",addr.nextExpected);
              dbg(GENERAL_CHANNEL,"\t\tit's seq number = %u\n",seqIn.nextExpected);
              dbg(GENERAL_CHANNEL,"\tlastReceived = %u\n",addr.lastRcvd);
              dbg(GENERAL_CHANNEL,"\t\tit's seq number = %u\n",seqIn.lastRcvd);
              dbg(GENERAL_CHANNEL,"\tString = %s\n",derp.data);
              dbg(GENERAL_CHANNEL,"*****************************\n");
              
              
              derp.flags[0] = FLAG_ACK;
              derp.flags[1] = FLAG_NONE;
          

              seqIn = call seqInfo.get(fd);

              makePack(&sendPackage,myMsg->dest,myMsg->src,MAX_TTL,myMsg->protocol,sequence,&derp,PACKET_MAX_PAYLOAD_SIZE);

              if (derp.ack == 140)
              {
              	dbg(GENERAL_CHANNEL,"This is to see what's up with the translation...\n");
              	translateMsg(sendPackage.payload);
              }
              sequence++;
              calcRoute();
              call Sender.send(sendPackage,portCalc(myMsg->src));

              return msg;

               
            }
            else if (derp.flags[0] == FLAG_ACK && derp.flags[1] == FLAG_NONE && addr.state == ESTABLISHED)
            {
              uint32_t modAck = 0;
              seqIn = call seqInfo.get(fd);
              addr = call socketHash.get(fd);

              if (derp.ack < seqIn.lastAck)
              {
                dbg(GENERAL_CHANNEL,"*((*(*(*(*(*(*Received ack that was less than last ack\n");
              }
              else if (derp.ack >= seqIn.lastAck)
                modAck = derp.ack - seqIn.lastAck;

              if ((modAck + addr.lastAck) >= 128)
              {
                uint32_t temp = 127 - addr.lastAck;

                modAck = modAck - temp - 1;

                while((modAck+addr.lastAck) >= 128)
                {
                	modAck = modAck - temp - 1;
                }
              }
              else
                modAck = modAck + addr.lastAck;

              if (seqIn.currSeq < derp.ack)
              {
              	seqIn.currAck = derp.ack;
              	call seqInfo.remove(fd);
              	call seqInfo.insert(fd,seqIn);
              }
              else
              {
              	dbg(GENERAL_CHANNEL,"This is a message that was already acknowledged\n");
              	return msg;
              }

              dbg(GENERAL_CHANNEL,"This is the modack going into ackSocket = %u\n",modAck);
              if(ackSocket(fd,modAck))
              {
                derp.flags[0] = FLAG_NONE;
                derp.flags[1] = FLAG_NONE;
                setupTCPpacket(fd,derp.data);
                seqIn = call seqInfo.get(fd);
                addr = call socketHash.get(fd);
                derp.seq = seqIn.lastAck + 1;
                seqIn.currSeq = derp.seq;
                call seqInfo.remove(fd);
                call seqInfo.insert(fd,seqIn);
                derp.ack = 1;

                //setupTCPpacket(fd,derp.data);
              }
              else
              {
                dbg(GENERAL_CHANNEL,"-------Ack socket didn't work\n");
                return msg;
              }

              /*
              dbg(GENERAL_CHANNEL,"*****************************\n");
              dbg(GENERAL_CHANNEL,"Client sending tcp pack with:\n");
              dbg(GENERAL_CHANNEL,"\tSeq = %u\n",derp.seq);
              dbg(GENERAL_CHANNEL,"\tAck = %u\n",derp.ack);
              //dbg(GENERAL_CHANNEL,"-----------------------------\n");
              dbg(GENERAL_CHANNEL,"\tlastSent = %u\n",addr.lastSent);
              dbg(GENERAL_CHANNEL,"\t\tit's seq number = %u\n",seqIn.lastSent);
              //dbg(GENERAL_CHANNEL,"\tlastAck = %u\n",addr.lastAck);
              //dbg(GENERAL_CHANNEL,"\t\tit's seq number = %u\n",seqIn.lastAck);
              dbg(GENERAL_CHANNEL,"\tString = %s\n",derp.data);
              dbg(GENERAL_CHANNEL,"*****************************\n");
              */

              dbg(GENERAL_CHANNEL,"*****************************\n");
              dbg(GENERAL_CHANNEL,"Client sending tcp pack with:\n");
              dbg(GENERAL_CHANNEL,"\tSeq = %u\n",derp.seq);

              if (currentCount >= maxDataTransfer && addr.lastWritten == addr.lastAck && addr.lastWritten == addr.lastSent)
              {
                dbg(GENERAL_CHANNEL,"Finished delivering data\n");
                addr.lastAck = addr.lastWritten; 
                return msg;
              }
              else
              {
                dbg(GENERAL_CHANNEL,"CURRENT_COUNT = %u\n",currentCount);
                dbg(GENERAL_CHANNEL,"maxDataTransfer = %u\n",maxDataTransfer);
                dbg(GENERAL_CHANNEL,"lastWritten = %u\n",addr.lastWritten);
                dbg(GENERAL_CHANNEL,"lastAck = %u\n",addr.lastAck);
                dbg(GENERAL_CHANNEL,"lastSent = %u\n",addr.lastSent);
              }

              makePack(&sendPackage,myMsg->dest,myMsg->src,MAX_TTL,myMsg->protocol,sequence,&derp,PACKET_MAX_PAYLOAD_SIZE);
              sequence++;

              out.currPack = sendPackage;
              out.expectedTime = 2*addr.RTT + call reliabilityTimer.getNow();
              out.fd = fd;
              out.seqNum = derp.seq;
              call outstandingMessages.pushfront(out);

              calcRoute();
              call Sender.send(sendPackage,portCalc(myMsg->src));

              return msg;

            }
            else if (derp.flags[0] == FLAG_FIN && derp.flags[1] == FLAG_NONE && addr.state == ESTABLISHED)
            {
              clock_t curr = clock();
              derp.flags[0] = FLAG_ACK;
              derp.flags[1] = FLAG_NONE;
              addr.RTT = 1;

              makePack(&sendPackage, myMsg->dest,myMsg->src,MAX_TTL,myMsg->protocol,sequence,&derp,PACKET_MAX_PAYLOAD_SIZE);
              sequence++;
              calcRoute();
              call Sender.send(sendPackage,portCalc(myMsg->src));

              timeSent = call periodicTimer.getNow();

              while((2*addr.RTT) > clock()-curr)
              {
                dbg(GENERAL_CHANNEL,"I found the culprit time = %d\n",call periodicTimer.getNow());
              }

              derp.flags[0] = FLAG_FIN;
              derp.flags[1] = FLAG_NONE;

              makePack(&sendPackage, myMsg->dest,myMsg->src,MAX_TTL,myMsg->protocol,sequence,&derp,PACKET_MAX_PAYLOAD_SIZE);
              sequence++;
              calcRoute();
              call Sender.send(sendPackage,portCalc(myMsg->src));

              return msg;
            }
            else if (derp.flags[0] == FLAG_ACK && derp.flags[1] == FLAG_NONE && addr.state == FIN_WAIT1)
            {
              // Doesn't seem to be needed
              dbg(GENERAL_CHANNEL,"&&&&&&&&&&&& Ack for fin received\n");
              return msg;
            }
            else if(derp.flags[0] == FLAG_FIN && derp.flags[1] == FLAG_NONE && addr.state == FIN_WAIT2)
            {
              derp.flags[0] = FLAG_ACK;
              derp.flags[1] = FLAG_NONE;

              makePack(&sendPackage, myMsg->dest,myMsg->src,MAX_TTL,myMsg->protocol,sequence,&derp,PACKET_MAX_PAYLOAD_SIZE);
              sequence++;
              calcRoute();
              call Sender.send(sendPackage,portCalc(myMsg->src));

              call Transport.close(call socketIdentifier.get(derp.srcPort));

              return msg;
            }
            else if (derp.flags[0] == FLAG_ACK && derp.flags[1] == FLAG_NONE && addr.state == LAST_ACK)
            {
              // Doesn't seem to be needed
              call socketHash.remove(call socketIdentifier.get(TOS_NODE_ID));
              dbg(GENERAL_CHANNEL,"*****Server has closed down*****\n");

              return msg;
            }
            else
            {
            	dbg(GENERAL_CHANNEL,"ENCOUNTERED UNFITTING MESSAGE\n")
            	return msg;
            }


            
            makePack(&sendPackage,myMsg->dest,myMsg->src,MAX_TTL,myMsg->protocol,sequence,&derp,PACKET_MAX_PAYLOAD_SIZE);
            sequence++;
            calcRoute();
            call Sender.send(sendPackage,portCalc(myMsg->src));

            return msg;
            
         }
  
         if (myMsg->protocol == PROTOCOL_LINKSTATE)
         {
            receiveLinkStateProtocol(myMsg);

            makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL, myMsg->protocol, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
            
            call Sender.send(sendPackage,AM_BROADCAST_ADDR);

            return msg;
         }
    
        
      }
      else
      {
      	dbg(GENERAL_CHANNEL,"Package is unknown\n");
      }

      //dbg(GENERAL_CHANNEL,"The Receive event function got to the lowest msg return statement\n");
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
    dbg(GENERAL_CHANNEL, "PING EVENT for destination = %d\n",destination);

    if (destination == TOS_NODE_ID)
    {
      dbg(GENERAL_CHANNEL,"**************Ending time = %u******************\n",call periodicTimer.getNow());
      return;
    }
    
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
      dbg(GENERAL_CHANNEL, "Woah printneighbors actually works\n");
   }

   event void CommandHandler.printRouteTable()
   {
   	 
   }

   event void CommandHandler.printLinkState()
   {
   	 
   }

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(uint16_t port){
    socket_t fd;
    socket_addr_t addr;
    socket_store_t socket;

    dbg(GENERAL_CHANNEL,"Server on node %d being called with port value %d\n",TOS_NODE_ID,port);

    fd = call Transport.socket();

    socket = call socketHash.get(fd);
    socket.RTT = 20000;

    call socketHash.remove(fd);
    call socketHash.insert(fd,socket);

    addr.port = port;
    addr.addr = TOS_NODE_ID;

    call Transport.bind(fd,&addr);

    call Transport.listen(fd);
   }

   event void CommandHandler.setTestClient(uint16_t dest, uint16_t srcPort, uint16_t destPort, uint16_t transfer){
    socket_t fd;
    socket_addr_t srcAddr;
    socket_addr_t destAddr;
    socket_store_t derp;
    TCPpack tcp;
    outstandTCP out;

    currentCount = 0;
    maxDataTransfer = transfer;

    dbg(GENERAL_CHANNEL,"Client on node %d being called\n",TOS_NODE_ID);
    dbg(GENERAL_CHANNEL,"\tDest = %d\n",dest);
    dbg(GENERAL_CHANNEL,"\tsrcPort = %d\n",srcPort);
    dbg(GENERAL_CHANNEL,"\tdestPort = %d\n",destPort);
    dbg(GENERAL_CHANNEL,"\ttransfer = %d\n",transfer);

    fd = call Transport.socket();

    dbg(GENERAL_CHANNEL,"Initial value of fd = %d\n",fd);
    srcAddr.port = srcPort;
    srcAddr.addr = TOS_NODE_ID;

    destAddr.port = destPort;
    destAddr.addr = dest;

    call Transport.bind(fd,&srcAddr);
    
    derp = call socketHash.get(fd);
    derp.state = SYN_SENT;
    derp.RTT = call periodicTimer.getNow();
    call socketHash.remove(fd);
    call socketHash.insert(fd,derp);

    tcp.srcPort = srcPort;
    tcp.destPort = destPort;
    tcp.flags[0] = FLAG_SYN;
    tcp.flags[1] = FLAG_NONE;
    tcp.seq = 0;
    tcp.ack = 0;
    tcp.advertisedWindow = 0;

    setupSeqInformation(fd,tcp.seq,tcp.ack);

    calcRoute();

    makePack(&sendPackage, TOS_NODE_ID, dest, MAX_TTL, PROTOCOL_TCP,sequence,&tcp,PACKET_MAX_PAYLOAD_SIZE);
    sequence++;
    call Sender.send(sendPackage,portCalc(dest));

    out.currPack = sendPackage;
    out.expectedTime = 10000 + call periodicTimer.getNow();
    out.seqNum = 0;
    out.fd = fd;

    //call writeTimer.startOneShot(10);
    call writeTimer.startPeriodic(100);
    call outstandingMessages.pushfront(out);
    call reliabilityTimer.startPeriodic(11000);

    dbg(GENERAL_CHANNEL,"========ReliabilityTimer Starting at %u\n",call reliabilityTimer.getNow());
   }

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   event void CommandHandler.clientClose(uint16_t dest, uint16_t srcPort, uint16_t destPort)
   {
      socket_store_t derp = call socketHash.get(call socketIdentifier.get(srcPort));
      socket_t fd = call socketIdentifier.get(srcPort);
      uint32_t* keys = call socketHash.getKeys();
      TCPpack tcp;

      //dbg(GENERAL_CHANNEL,"Dest = %d and destPort = %d\n",dest,destPort);
      //dbg(GENERAL_CHANNEL,"derp.dest.addr = %d, and derp.dest.port = %d\n",derp.dest.addr,derp.dest.port);
      //dbg(GENERAL_CHANNEL,"derp.srcport = %d\n",derp.src);
      dbg(GENERAL_CHANNEL,"Size of socketHash = %d\n",call socketHash.size());
      dbg(GENERAL_CHANNEL,"Key of sockeHash = %d\n",*keys);

      if (derp.dest.addr == dest && derp.dest.port == destPort)
      {
          dbg(GENERAL_CHANNEL,"Connection has been found\n");
          
          tcp.srcPort = srcPort;
          tcp.destPort = destPort;
          tcp.flags[0] = FLAG_FIN;
          tcp.flags[1] = FLAG_NONE;
          tcp.seq = 0;
          tcp.ack = 0;
          tcp.advertisedWindow = 0;
          
          derp.state = FIN_WAIT1;
          call socketHash.remove(fd);
          call socketHash.insert(fd,derp);

          calcRoute();

          makePack(&sendPackage, TOS_NODE_ID, dest, MAX_TTL, PROTOCOL_TCP,sequence,&tcp,PACKET_MAX_PAYLOAD_SIZE);
          sequence++;
          call Sender.send(sendPackage,portCalc(dest));
      }

   }

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