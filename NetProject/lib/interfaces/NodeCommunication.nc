#include "../../includes/packet.h"

interface NodeCommunication{
	event void linkStateChange();
	command bool sendCheck(pack* msg);
	command void receiveLinkStateProtocol(pack* msg);
	command void sendLinkState(uint32_t node, uint8_t *neighbors);
	command void calcRoute();
	command void initializeNode(uint32_t nodeID);
	command uint32_t portCalc(uint32_t node);
	command bool containsRouting(uint32_t node);
}