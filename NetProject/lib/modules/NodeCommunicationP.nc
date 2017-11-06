#include "../includes/packet.h"
#include "../includes/LinkState.h"
#include "../includes/command.h"
#include "../includes/CommandMsg.h"
#include "../includes/sendInfo.h"
#include "../includes/channels.h"

/*
	************ Things to take note of ****************
	- linkstateMap is myMap from old implementation and has changed from a list to hashmap
	- PacketChecker was originally named Hash
	- tempMap and transferMap may be deleted when putting in implementation because of no further use
	- ExpandedList has also changed from list to hash haha
	- Want to change implementation of starting at negative one because could cause problem with unsigned numbers, change to COST_MAX
*/

generic module NodeCommunicationP(){
   provides interface NodeCommunication;

   
   uses interface Hashmap<uint32_t> as PacketChecker;
   uses interface Hashmap<uint32_t> as CostMap;
   uses interface Hashmap<uint32_t> as RoutingMap;
   uses interface Hashmap<uint32_t> as NeighborList;
   uses interface Hashmap<uint32_t> as CheckList;
   uses interface Hashmap<uint32_t> as ExpandedList;
   uses interface Hashmap<linkstate> as transferMap;
   uses interface Hashmap<linkstate> as tempMap;
   uses interface Hashmap<linkstate> as linkStateMap;

   
}
implementation{
	uint32_t NODE_ID = 0;
	linkstate map;


	void printGraph()
	{
		int i = 0;
		int j = 0;
		uint32_t* keys = call linkStateMap.getKeys();

		map = call linkStateMap.get(NODE_ID);

		dbg(GENERAL_CHANNEL, "Map for node: %d with size = %d\n",NODE_ID, call linkStateMap.size());

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

		dbg(GENERAL_CHANNEL,"CostMap for node %d\n",NODE_ID);

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
		dbg(GENERAL_CHANNEL,"Node %d\n",NODE_ID);

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

    uint32_t portCalcRec(uint32_t node)
    {
    	if (call RoutingMap.get(node) == TOS_NODE_ID)
	   	 	return node;
	   	 else if (call RoutingMap.get(node) == COST_MAX)
	   	 	return COST_MAX;
	   	 else	
	   	 	portCalcRec(call RoutingMap.get(node));
    }
    command uint32_t NodeCommunication.portCalc(uint32_t node)
    {
	   	 // Fill in

	   	 return portCalcRec(node);
    }

	command bool NodeCommunication.sendCheck(pack* msg)
	{
		if ((msg->protocol == PROTOCOL_PING || msg->protocol == PROTOCOL_PINGREPLY) && NODE_ID == 2)
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
	command void NodeCommunication.receiveLinkStateProtocol(pack* msg)
	{
		//dbg(GENERAL_CHANNEL, "Node %d is sending linkstate\n",NODE_ID);
		if (call linkStateMap.contains(msg->src))
		{
			call linkStateMap.remove(msg->src);
		    addToTopology(msg->src,msg->payload);
			signal NodeCommunication.linkStateChange();
		}
		else
		{
			addToTopology(msg->src,msg->payload);
		}

	}
	command void NodeCommunication.sendLinkState(uint32_t node, uint8_t *neighbors)
	{
		//dbg(GENERAL_CHANNEL, "Node %d is sending linkstate\n",NODE_ID);
		if (call linkStateMap.contains(node))
		{
			call linkStateMap.remove(node);
		}

		addToTopology(node,neighbors);
	}
	command void NodeCommunication.calcRoute()
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


	  	

	}
	command void NodeCommunication.initializeNode(uint32_t nodeID)
	{
		dbg(GENERAL_CHANNEL, "**********************************\n");
		dbg(GENERAL_CHANNEL, "Original value of nodeID = %d\n",NODE_ID);
		NODE_ID = nodeID;
		dbg(GENERAL_CHANNEL, "Value has changed to nodeID = %d\n",NODE_ID);
	}
	
	command bool NodeCommunication.containsRouting(uint32_t node)
	{
		if (call RoutingMap.contains(node) && call RoutingMap.get(node) != COST_MAX)
			return TRUE;
		return FALSE;
	}
}