generic module ListC(int n){
	provides interface List;
}

implementation{
	uint16_t MAX_SIZE = n;

	linkstate container[n];
	uint16_t size = 0;

	command void List.pushback(linkstate* input){
		// Check to see if we have room for the input.
		if(size < MAX_SIZE){
			// Put it in.
			container[size] = input;
			size++;
		}
	}

	command void List.pushfront(linkstate* input){
		// Check to see if we have room for the input.
		if(size < MAX_SIZE){
			int32_t i;
			// Shift everything to the right.
			for(i = size-1; i>=0; i--){
				container[i+1] = container[i];
			}

			container[0] = input;
			size++;
		}
	}

	command linkstate* List.popback(){
		linkstate* returnVal;

		returnVal = container[size];
		// We don't need to actually remove the value, we just need to decrement
		// the size.
		if(size > 0)size--;
		return returnVal;
	}

	command linkstate* List.popfront(){
		linkstate* returnVal;
		uint16_t i;

		returnVal = container[0];
		if(size>0){
			// Move everything to the left.
			for(i = 0; i<size-1; i++){
				container[i] = container[i+1];
			}
			size--;
		}

		return returnVal;
	}

	// This is similar to peek head.
	command linkstate List.front(){
		return container[0];
	}

	// Peek tail
	command t List.back(){
		return container[size];
	}

	command bool List.isEmpty(){
		if(size == 0)
			return TRUE;
		else
			return FALSE;
	}

	command uint16_t List.size(){
		return size;
	}

	command t List.get(uint16_t position){
		return container[position];
	}
}
