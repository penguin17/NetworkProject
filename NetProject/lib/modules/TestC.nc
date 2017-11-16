#include "../../includes/packet.h"
#include "../../includes/socket.h"

generic module TestC(){
   provides interface Test;
   uses interface Hashmap<uint32_t> as Hash5;
}

implementation{
	command void Test.initialize(uint32_t value)
	{
		dbg(GENERAL_CHANNEL,"Value being sent in for initialize %u\n",value);
		call Hash5.insert(1,value);

		if (call Hash5.contains(1))
		{
			dbg(GENERAL_CHANNEL,"Contains key value zero with the value %u %%%\n",call Hash5.get(1));
			dbg(GENERAL_CHANNEL,"Size of hash is %d\n",call Hash5.size());
		}
	}
	command void Test.print()
	{
		dbg(GENERAL_CHANNEL,"The value inside the TestC module = %d\n",call Hash5.get(1));
	}
}