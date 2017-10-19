#include "includes/LinkState.h"

interface List{
   /**
    * Put value into the end of the list.
    *
    * @param input - data to be inserted
    */
   command void pushback(linkstate *input);
	command void pushfront(linkstate *input);
	command linkstate* popback();
	command linkstate* popfront();
	command linkstate* front();
	command linkstate* back();
	command bool isEmpty();
	command uint16_t size();
	command t get(uint16_t position);
}