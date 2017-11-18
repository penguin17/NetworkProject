#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include <time.h>
generic module TransportC(){
   provides interface Transport;
   uses interface Hashmap<socket_store_t> as socketHash;
   uses interface Hashmap<socket_addr_t> as socketConnections;
   uses interface Hashmap<socket_t> as socketIdentifier;
   uses interface Timer<TMilli> as periodicTimer; //Interface that was wired above.
}

implementation{

	TCPpack translateMsg(uint8_t* payload)
  {
    uint8_t arr[20];
    TCPpack derp;

    memcpy(arr,payload,20);

    derp.srcPort = arr[0]<<15;
    derp.srcPort = derp.srcPort|arr[1];


    derp.destPort = arr[2]<<15;
    derp.destPort = derp.destPort|arr[3];

    derp.flags[0] = arr[4];
    derp.flags[1] = arr[5];

    derp.seq = arr[6]<<23;
    derp.seq = derp.seq|(arr[7]<<15);
    derp.seq = derp.seq|arr[8];

    derp.ack = arr[9]<<23;
    derp.ack = derp.seq|(arr[10]<<15);
    derp.ack = derp.seq|arr[11];

    derp.advertisedWindow = arr[12]<<15;
    derp.advertisedWindow = derp.advertisedWindow|arr[13];

    memcpy(derp.data,arr+14,5);

    


    return derp;

  }
	bool timedOut(socket_t fd)
	{
		uint32_t timeCheck;
		socket_store_t derp = call socketHash.get(fd);

		// Remember to check for timeouts of packets instead of zero

		if (derp.RTT == 0)
			timeCheck = MAX_TIMEMSG;
		else if (derp.RTT < 0)
			dbg(GENERAL_CHANNEL, "Somethings is up with the avgRTT value being lower than zero\n");
		else if (derp.RTT > 0)
			timeCheck = derp.RTT;

		if ((call periodicTimer.getNow() - 0) > 3 * timeCheck)
			return TRUE;
		
		return FALSE;
	}
	command socket_t Transport.socket()
	{
		uint32_t inc = 1;
		socket_t fd;
		socket_store_t derp;

		if (call socketHash.size() >= 100)
		{
			dbg(GENERAL_CHANNEL, "Transport socket returning null\n");
			derp.state = CLOSED;
			return 0;
		}

		while(call socketHash.contains(inc))
			inc++;

		fd = inc;

		derp.state = CLOSED;
		derp.effectiveWindow = 0;
		derp.RTT = 0;
		derp.lastWritten = 0;
		derp.lastAck = 0;
		derp.lastSent = 0;
		derp.lastRead = 0;
		derp.lastRcvd = 0;
		derp.nextExpected = 1;

		call socketHash.insert(fd,derp);

		return fd;
	}

	command error_t Transport.bind(socket_t fd, socket_addr_t *addr)
	{
		socket_store_t derp = call socketHash.get(fd);

		if (!call socketHash.contains(fd))
		{
			dbg(GENERAL_CHANNEL, "A socket is trying to connect that isn't in the socket hash!!!\n");
			return FAIL;
		}

		derp.src = addr->port;

		call socketIdentifier.insert(derp.src,fd);

		call socketHash.remove(fd);
		call socketHash.insert(fd,derp);

		return SUCCESS;
	}

	command socket_t Transport.accept(socket_t fd)
	{
		socket_store_t derp = call socketHash.get(fd);
		uint32_t* keys = call socketConnections.getKeys();
		socket_addr_t connect;

		if (call socketConnections.size() == 0)
			return 0;

		connect = call socketConnections.get(*keys);


		if (derp.state != ESTABLISHED)
		{
			dbg(GENERAL_CHANNEL, "Transport accept function is returning null socket\n");
			return 0;
		}


		derp.dest.port = connect.port;
		derp.dest.addr = connect.addr;

		call socketHash.remove(fd);
		call socketHash.insert(fd,derp);

		call socketConnections.remove(*keys);

		return fd;
	}

	command error_t Transport.receive(pack* package)
	{
		TCPpack derp = translateMsg(package->payload);
		socket_t fd = call socketIdentifier.get(derp.destPort);
		socket_store_t addr = call socketHash.get(fd);

		if (!call socketHash.contains(fd))
			return FAIL;

		dbg(GENERAL_CHANNEL,"Second Fd = %d\n",fd);

		if (derp.flags[0] == FLAG_SYN && derp.flags[1] == FLAG_NONE && addr.state == LISTEN)
		{
			addr.state = SYN_RCVD;

			call socketHash.remove(fd);
			call socketHash.insert(fd,addr);

			return SUCCESS;
		}
		else if (derp.flags[0] == FLAG_SYN && derp.flags[1] == FLAG_ACK && addr.state == SYN_SENT)
		{
			addr.state = ESTABLISHED;
			addr.dest.port = derp.srcPort;
			addr.dest.addr = package->src;
			//addr.RTT = call periodicTimer.getNow() - 0;
			//addr.timeSent = 0;
			dbg(GENERAL_CHANNEL,"Client has been connected\n");

			call socketHash.remove(fd);
			call socketHash.insert(fd,addr);

			return SUCCESS;
		}
		else if (derp.flags[0] == FLAG_ACK && derp.flags[1] == FLAG_NONE && addr.state == SYN_RCVD)
		{
			addr.state = ESTABLISHED;
			addr.dest.port = derp.srcPort;
			addr.dest.addr = package->src;
			//addr.RTT = call periodicTimer.getNow() - 0;
			//addr.timeSent = 0;
			dbg(GENERAL_CHANNEL,"Server Has Been Connected\n");

			call socketHash.remove(fd);
			call socketHash.insert(fd,addr);

			return SUCCESS;
		}
		else if (derp.flags[0] == FLAG_FIN && derp.flags[1] == FLAG_NONE && addr.state == ESTABLISHED)
		{
			addr.state = LAST_ACK;

			call socketHash.remove(fd);
			call socketHash.insert(fd,addr);

			return SUCCESS;
		}
		else if (derp.flags[0] == FLAG_ACK && derp.flags[1] == FLAG_NONE && addr.state == FIN_WAIT1)
		{
			addr.state = FIN_WAIT2;
			//addr.RTT = call periodicTimer.getNow() - 0;
			//addr.timeSent = 0;

			call socketHash.remove(fd);
			call socketHash.insert(fd,addr);

			return SUCCESS;
		}
		else if(derp.flags[0] == FLAG_FIN && derp.flags[1] == FLAG_NONE && addr.state == FIN_WAIT2)
		{
			uint32_t currTime = call periodicTimer.getNow();
			addr.state = TIME_WAIT;

			call socketHash.remove(fd);
			call socketHash.insert(fd,addr);

			return SUCCESS;
		}
		else if (derp.flags[0] == FLAG_ACK && derp.flags[1] == FLAG_NONE && addr.state == LAST_ACK)
		{
			addr.state = CLOSED;

			//call socketHash.remove(fd);

			return SUCCESS;
		}
		else if (derp.flags[0] == FLAG_NONE && derp.flags[1] == FLAG_NONE && addr.state == ESTABLISHED)
		{
			return SUCCESS;
		}
		else if (derp.flags[0] == FLAG_ACK && derp.flags[1] == FLAG_NONE && addr.state == ESTABLISHED)
		{
			return SUCCESS;
		}
		
		dbg(GENERAL_CHANNEL,"Transport receive function should've not gotten here\n");
		dbg(GENERAL_CHANNEL,"Current state = %u\n",addr.state);
		return FAIL;
	}

	// Connect not fully implemented
	command error_t Transport.connect(socket_t fd, socket_addr_t * addr)
	{
		socket_store_t derp = call socketHash.get(fd);

		if (derp.state == ESTABLISHED && derp.dest.port == addr->port && derp.dest.addr == addr->addr)
		{
			return SUCCESS;
		}	

		return FAIL;
	}

	command error_t Transport.close(socket_t fd)
	{
		socket_store_t derp = call socketHash.get(fd);
		clock_t timeNow = clock();

		if (!call socketHash.contains(fd))
		{
			dbg(GENERAL_CHANNEL, "Trying to close a socket that isn't even open\n");
			return FAIL;
		}

		if (derp.state == TIME_WAIT)
		{	//derp.RTT = 2;

			while((2*derp.RTT) > clock()-timeNow)
			{
				//dbg(GENERAL_CHANNEL,"wOWZERSKDFJA;LKDF;ALKD\n");
			}

			dbg(GENERAL_CHANNEL,"Client has closed correctly\n");
			call socketHash.remove(fd);
			return SUCCESS;
		}
		else if (derp.state == CLOSED)
		{
			call socketHash.remove(fd);
			return SUCCESS;
		}

		return FAIL;
	}

	command error_t Transport.listen(socket_t fd)
	{
		socket_store_t derp = call socketHash.get(fd);

		if (!call socketHash.contains(fd))
		{
			dbg(GENERAL_CHANNEL, "Trying to make a socket listen when it shouldn't be\n");
			return FAIL;
		}
		if (derp.state != CLOSED)
		{
			dbg(GENERAL_CHANNEL, "For some reason, the socket is in some other state other than closed when trying to switch to the state of listening\n");
			return FAIL;
		}

		derp.state = LISTEN;

		call socketHash.remove(fd);
		call socketHash.insert(fd,derp);

		return SUCCESS;
	}
	event void periodicTimer.fired()
	{
		//Derp
	}
	command error_t Transport.release(socket_t fd)
	{

	}
	command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen)
	{
		uint32_t check = 0;
		int i = 0;
		socket_store_t derp = call socketHash.get(fd);

		//dbg(GENERAL_CHANNEL,"REAL buffer = %s\n",derp.rcvdBuff + 1);

		if (derp.lastRead == derp.lastRcvd)
			return 0;

		

		derp.lastRead++;

		for (i = 0; i < bufflen; i++)
		{
			if (derp.lastRead >= SOCKET_BUFFER_SIZE)
			{
				derp.lastRead = 0;

			}
			else if (derp.lastRead == (derp.nextExpected - 1))
			{
				//dbg(GENERAL_CHANNEL,"This is the reason why it's not shwoing anything?\n");
				call socketHash.remove(fd);
				call socketHash.insert(fd,derp);
				return check;
			}

			buff[i] = derp.rcvdBuff[derp.lastRead];
			//dbg(GENERAL_CHANNEL,"+++++++++++Buffer value(read thingy) = %u\n",buff[i]);
			derp.lastRead++;
			check++;
		}

		call socketHash.remove(fd);
		call socketHash.insert(fd,derp);
		return check;
	}
	command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen)
	{
	    socket_store_t derp = call socketHash.get(fd);
	    uint16_t check = 0;
	    int i = 0;

	    if (derp.lastWritten == (derp.lastAck - 1))
	    	return 0;

	    if (derp.lastWritten == derp.lastAck)
	    derp.lastWritten++;

	    for (i = 0; i < bufflen; i++)
	    {
	    	if (derp.lastWritten >= SOCKET_BUFFER_SIZE)
	    		derp.lastWritten = 0;

	    	derp.sendBuff[derp.lastWritten] = buff[i];
	    	derp.lastWritten++;
	    }

	    call socketHash.remove(fd);
	    call socketHash.insert(fd,derp);

	    dbg(GENERAL_CHANNEL,"The current written portion = %s\n",derp.sendBuff + 1);
	}	
}