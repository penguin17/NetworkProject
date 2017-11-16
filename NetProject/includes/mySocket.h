//Author: UCM ANDES Lab
//$Author: abeltran2 $
//$LastChangedBy: abeltran2 $

#ifndef SOCKET_H
#define SOCKET_H


# include "protocol.h"
#include "channels.h"

enum{
	MAX_BUFFER_DATA = 128,
	MAX_TIMEMSG,
	MAX_FLAGS = 2,
	SOCKSTATE_CLOSED = 0,
	SOCKSTATE_LISTEN = 1,
	SOCKSTATE_SYNSENT = 2,
	SOCKSTATE_SYNREC = 3,
	SOCKSTATE_ESTAB = 4,
	SOCKSTATE_FINWAIT1 = 5,
	SOCKSTATE_FINWAIT2 = 6,
	SOCKSTATE_CLOSING = 7,
	SOCKSTATE_TIMEWAIT = 8,
	SOCKSTATE_CLOSE_WAIT = 9,
	SOCKSTATE_LAST_ACK = 10,
	SOCKSTATE_NULL = 11,

	FLAG_SYN = 0,
	FLAG_ACK = 1,
	FLAG_FIN = 2,
	FLAG_NONE = 3
};

typedef nx_struct socket_t{
	nx_uint16_t srcPort;
	nx_uint16_t src;
	nx_uint16_t destPort;
	nx_uint16_t dest;
	nx_uint16_t ID;
	nx_uint32_t timeSent;
	nx_uint32_t avgRTT;
	nx_uint8_t connectionState;
	nx_uint8_t bufferData[MAX_BUFFER_DATA];
}socket_t;

typedef nx_struct socket_addr_t{
	nx_uint16_t port;
	nx_uint16_t address;
	//nx_uint8_t connectionState;
	//nx_uint8_t bufferData[MAX_BUFFER_DATA];
} socket_addr_t;

typedef nx_struct TCPpack{
	nx_uint16_t srcPort;
	nx_uint16_t destPort;
	nx_uint8_t flags[MAX_FLAGS];
	nx_uint32_t seq;
	nx_uint32_t ack;
	nx_uint8_t data[7];
}TCPpack;

#endif
