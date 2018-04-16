classdef Port < airtaxi.agents.Agent & publicsim.agents.base.Locatable
    properties
        port_id
        location
        
        trip_options 	
        
        pickups_arrived
        customer_demand
        operation_cost
        
        chargers
        landing_cost
        landing_slots
        charging_cost 				
        num_ports
    end
    
    properties (Access = private)
        current_customers
        max_customers = 10      
        
        plotter
        
        last_update_time
        run_interval
        trip_accept_topic
        response_broadcast_topic
        trip_price_topic
        
        free_cust_refs  				% List of reference ids for customers 
    end
    
    properties (Constant)
        TRIP_TOPIC_KEY = 'TRIP_INFO';
        CUSTOMER_REQUEST_TOPIC_KEY = 'CUSTOMER_REQUEST';
        TRIP_ACCEPT_TOPIC_KEY       = 'TRIP_ACCEPT'
    end
    
    methods
        function obj = Port(num_ports)
            obj = obj@airtaxi.agents.Agent();
            obj@publicsim.agents.base.Locatable();
            
            obj.chargers = containers.Map('KeyType','int32','ValueType','any');
            obj.num_ports = num_ports;
            obj.run_interval = 1;
            obj.last_update_time = -1;
            
            obj.pickups_arrived = [];
            obj.free_cust_refs = 1:obj.max_customers;
            obj.trip_options = cell(1,obj.num_ports);
        end
        function init(obj) 
            obj.response_broadcast_topic = obj.getDataTopic(obj.CUSTOMER_REQUEST_TOPIC_KEY,'','');
            obj.trip_price_topic = obj.getDataTopic(obj.TRIP_TOPIC_KEY,'','');
            obj.trip_accept_topic = obj.getDataTopic(obj.TRIP_ACCEPT_TOPIC_KEY,'','');
            
            obj.subscribeToTopic(obj.trip_price_topic);
            obj.subscribeToTopicWithCallback(obj.trip_accept_topic,@obj.updateAcceptance);
            
            obj.setLogLevel(publicsim.sim.Logger.log_INFO);
            
            obj.scheduleAtTime(0);
        end
        
        function runAtTime(obj,time)
            if (time - obj.last_update_time) >= obj.run_interval
                obj.spawnDemand(time)
                obj.checkSupply();
                if ~isempty(obj.trip_options) && ~isempty(obj.current_customers)...
                        && obj.unservedCustomers()
                    [decisions,decision_changes] = obj.customerDecision();
                    if sum(decision_changes)
                        % Any decision change
                        obj.broadcastResponses(decisions);
                    end
                end
                obj.last_update_time = time;
                obj.updateCustomerStates(time)
                obj.scheduleAtTime(time+1);
            end
        end
        function check = unservedCustomers(obj)
            demand_sum = 0;
            for ii=1:length(obj.current_customers)
                demand_sum = demand_sum + ...
                    obj.current_customers{ii}.demand_state;
            end
            % If all demands served
            if demand_sum == length(obj.current_customers)
                check = false;
            else
                check = true;
            end
        end
        
        function updateCustomerStates(obj,time)
			% Update customer state
            customer_del_flag = [];
            for ii=1:length(obj.current_customers)
                for jj=1:length(obj.pickups_arrived)
                    pickup_id = obj.pickups_arrived(jj);
                    if obj.current_customers{ii}.demand_state == 1
                        if obj.current_customers{ii}.pickup_ac == pickup_id
                            % Pickup arrived
                            % Delete customer from port
                            ref = obj.current_customers{ii}.ref;
                            obj.free_cust_refs(end+1) = ref;
                            customer_del_flag(end+1) = ii;
                            obj.pickups_arrived(jj)   = [];
                            break
                        end
                    end
                end
            end
            if ~isempty(customer_del_flag)
                customer_del_flag = fliplr(customer_del_flag);
            end
            for ii=customer_del_flag
                obj.current_customers{ii}.deletePlot();
                obj.current_customers(ii) = [];
            end
            customer_del_flag = [];
            for ii=1:length(obj.current_customers)
                if obj.current_customers{ii}.waitTimeOver(time) && ...
                        ~obj.current_customers{ii}.demand_state
                    ref = obj.current_customers{ii}.ref;
                    obj.free_cust_refs(end+1) = ref;
                    customer_del_flag(end+1) = ii;
                end
                decisions(ii) = obj.current_customers{ii}.trip_decision;
            end
            
            if ~isempty(customer_del_flag)
                decisions(customer_del_flag) = -1;
                obj.broadcastResponses(decisions)
                customer_del_flag = fliplr(customer_del_flag);
            end
            try 
            for ii=customer_del_flag
                obj.current_customers{ii}.deletePlot();
                obj.current_customers(ii) = [];
            end
            catch
                keyboard
            end
                    
        end
        
        function updateAcceptance(obj,time,msg)
            if msg{1}.port_id ~= obj.port_id
                return
            end
            ref = msg{1}.cust_ref;
            idx = obj.findCurrentCustomerIdx(ref);
            if isempty(idx)
                obj.cancelResponse(msg{1});
                return
            end
            obj.current_customers{idx}.pickup_ac = msg{1}.ac_id;
%             cust = obj.current_customers{idx};
%             cust.pickup_ac = msg{1}.ac_id;
            obj.current_customers{idx}.demand_state = 1;
%             obj.current_customers{idx} = cust;
        end
        
        function idx = findCurrentCustomerIdx(obj,ref)
            idx = [];
            for ii=1:length(obj.current_customers)
                cust = obj.current_customers{ii};
                if cust.ref == ref
                    idx = ii;
                    return;
                end
            end
        end
        function spawnDemand(obj,time)	
			if length(obj.current_customers) == obj.max_customers 
				% Maximum customers reached
				return
			end
			
			% Check if the demand spawning function returns demand for this port at this time			
            if airtaxi.funcs.spawnCustomer(obj.port_id,time,obj.current_customers,obj.max_customers)
                dest = [];
                while isempty(dest)
                    dest = randi([1 obj.num_ports]);
                    if dest == obj.port_id
                        dest = [];
                    end
                end
                % Create customer objects
                spawn_info.ref = obj.free_cust_refs(1); obj.free_cust_refs(1) = [];
                spawn_info.port_location = obj.location;
                spawn_info.max_customers = obj.max_customers;
                spawn_info.time          = time;
                customer = airtaxi.agents.Customer(spawn_info,dest);
                obj.current_customers{end+1} = customer;
            end
        end
        
        function checkSupply(obj)
			% Examine the current aircraft available for trips
            [topics,msgs] = obj.getNewMessages();
            for ii=1:length(topics)
                if isequal(topics{ii}.type,obj.TRIP_TOPIC_KEY)
                    trip_info = msgs{ii};
                else
                    keyboard;
                end
                if ~isempty(trip_info.prices)
                    obj.processSupply(trip_info)
                else
                    % Aircraft already on trip
                    for kk=1:obj.num_ports
                        % already exist
                        idx = obj.doesTripOptionExist(kk,trip_info.ac_id);
                        if ~isempty(idx)
                            obj.trip_options{kk}(idx) = [];
                        end
                    end
                    
                    for kk=1:length(obj.current_customers)
                        if isempty(obj.current_customers{kk}.pickup_ac) && ...
                            obj.current_customers{kk}.trip_decision == trip_info.ac_id
                        
                            obj.current_customers{kk}.trip_decision = -1;
                            obj.current_customers{kk}.demand_state  = 0;
                        end 
                    end
                end
            end
        end
        function broadcastResponses(obj,decisions)
			% Broadcast responses of all the custoemrs at the port 
            response_msg = obj.createResponse(decisions);
            obj.publishToTopic(obj.response_broadcast_topic,response_msg);
        end
        
        function cancelResponse(obj,accept_msg)
			% Broadcast cancelation of trips by customer 
            cancel_msg = obj.createCancelResponse(accept_msg);
            obj.publishToTopic(obj.response_broadcast_topic,cancel_msg);
        end
        
        function cancel_msg = createCancelResponse(obj,accept_msg)
            cancel_msg{1} = accept_msg;
            cancel_msg{1}.ac_id = -1;
        end
		
        function response_msg = createResponse(obj,decisions)
            for ii=1:length(decisions)
                if ~isnan(decisions(ii))
                    msg = struct;
                    msg.ac_id    = decisions(ii);
                    msg.port_id  = obj.port_id;
                    msg.cust_ref = obj.current_customers{ii}.ref;
                    msg.dest     = obj.current_customers{ii}.trip_demand;
                    response_msg{ii} = msg;
                end
            end
        end
        function [decisions,decision_changes] = customerDecision(obj)
            % Customer decision-making
            decisions = nan(1,length(obj.current_customers));
            decision_changes = zeros(1,length(obj.current_customers));
            for ii=1:length(obj.current_customers)
                customer = obj.current_customers{ii};
                if customer.demand_state == 1
                    decisions(ii) = customer.trip_decision;
                    continue
                end
                available_options = obj.trip_options{customer.trip_demand};
                if isempty(available_options)
                    continue
                end
            
                decisions(ii) = customer.findBestDeal(available_options);
                if decisions(ii)~=customer.trip_decision
                    decision_changes(ii) = 1;
                    obj.current_customers{ii}.trip_decision = decisions(ii);
                end
            end
        end
        
        function processSupply(obj,trip_info)
			% Extract available trip options from the aircraft broadcast data 
            for ii=1:obj.num_ports
                trip_option = struct;
                trip_option.ac_id       = trip_info.ac_id;
                trip_option.wait_time   = trip_info.wait_times(obj.port_id);
                trip_option.price       = trip_info.prices(obj.port_id,ii);
                % Check if trip option from the particular aircraft
                % already exist
                idx = obj.doesTripOptionExist(ii,trip_info.ac_id);
                if isempty(idx)
                    obj.trip_options{ii}{end+1} = trip_option;
                else
                    obj.trip_options{ii}{idx}   = trip_option;
                end
            end
%             keyboard;
        end
        
        function idx = doesTripOptionExist(obj,port_id,ac_id)
            idx = [];
            for ii=1:length(obj.trip_options{port_id})
                if obj.trip_options{port_id}{ii}.ac_id == ac_id
                    idx = ii;
                    return
                end
            end
        end
        function pickupArrived(obj,pickup_id)
            % Check for customer awaiting this pickup
            obj.pickups_arrived(end+1) = pickup_id;
        end
        
        function loc = getLocation(obj)
            loc = obj.location;
        end
        function setLocation(obj,loc)
            obj.location = loc;
        end
        function setPlotter(obj,plotter)
            obj.plotter = plotter;
        end
        function id = identifier(obj)
            id = obj.port_id;
        end
        
        function v = getPosition(obj)
            v = obj.location;
        end
        
        
        function customer_data = getCustomerData(obj)
			% Customer data for logging 
            customer_data = struct();
            customer_data.total_count  = length(obj.current_customers);
            served_count = 0;
            trip_demand    = nan(1,customer_data.total_count);
            trip_decision  = nan(1,customer_data.total_count);
            for ii=1:customer_data.total_count
                if obj.current_customers{ii}.demand_state
                    served_count = served_count + 1;
                end
                trip_demand(ii)  = obj.current_customers{ii}.trip_demand;
                trip_decision(ii) = obj.current_customers{ii}.trip_decision;
            end
            customer_data.served_count   = served_count;
            customer_data.trip_demand    = trip_demand;
            customer_data.trip_decision  = trip_decision;
        end
    end
    methods (Static,Access=private)
        
        function addPropertyLogs(obj)
			% Define the attributes that needs to be logged
			
			% The attributes can either be an agent property or a function which returns a value 
            obj.addPeriodicLogItems({'getCustomerData'});
			
			% Optionally period of logging can also be defined
			% period = 2.0; %[s] in simulation time 
			% obj.addPeriodicLogItems({'getCustomerData'},period);
			
        end
        
    end
    
            %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests TODO Make gooder
            tests = {};
            %tests{1} = 'publicsim.tests.agents.base.MovableTest.test_Movable';
        end
    end
end