function check = spawnCustomer(simTime,port)
	% The customer demand at each port is defined by this function
	
	% Currently, a simple random demand generator is used to spaw customers
	% A time dependent demand which is a function of several other factors can also be conceived
	check = false;
	
	if mod(simTime,10) ~= 0
		return
	end
	
	if rand() > 0.7 + length(port.current_customers)*0.3/port.max_customers
		check = true;
	end
end