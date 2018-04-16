classdef Aircraft < airtaxi.agents.Agent & publicsim.agents.base.Movable & publicsim.agents.hierarchical.Child
    % Aircraft agent
    properties
        % --- AC properties ---
        ac_id               % Numerical reference for the AC
        type                % AC Type
        num_seats           % Number of seats available in the AC
        cruise_speed        % Cruise speed
        range               % Max. distance in miles with a fully-charged battery
        
        % --- Ops properties ---
        operation_mode      
        current_port
        num_ports
        operating_costs
        revenue
        current_trip_price
        
        % --- Dynamics properties ---
        location            % Current location
        speed               % Current speed
    end
    
    properties (Access = protected)
        % --- Battery ---
        need2charge             % Flag indicating need to charge
        charge_level            % Current charge level of the battery
        charge_drop_rate        % Charge drop per mile
        min_charge_threshold    % Fraction of max. charge allowable below 
                                % which charging is needed
        
        % --- Customer ---
        customer_responses
        customers_served_count
        routes_served_count
        pickup
        destination
        
        % --- Dynamics ---
        dir_vect
        climb_rate
        cruise_altitude
        
        % --- Sim properties ---
        last_update_time
        plotter
        run_interval
        
        % --- Agent Communication ---
        trip_accept_topic
        price_broadcast_topic
        customer_request_topic
    end
    
    properties (Constant)
        TRIP_TOPIC_KEY              = 'TRIP_INFO';
        CUSTOMER_REQUEST_TOPIC_KEY  = 'CUSTOMER_REQUEST';
        TRIP_ACCEPT_TOPIC_KEY       = 'TRIP_ACCEPT';
    end
    methods
        function obj = Aircraft(num_ports)
            obj = obj@airtaxi.agents.Agent();
            obj@publicsim.agents.base.Movable();
            % --- Operaional ---
            obj.operation_mode               = 'idle';      % When the sim starts it is idle
                                                            % Options: 'idle',
                                                            %          'onTrip',
                                                            %          'charging',
                                                            %          'enroute2pickup',
                                                            %          'enroute2charging',
            
            
            obj.customer_responses  = {};
            obj.destination         = struct();
            
            obj.customers_served_count = 0;
            
            obj.num_ports          = num_ports;
            obj.operating_costs    = 0;
            obj.revenue            = 0;
            obj.current_trip_price = nan;
            obj.routes_served_count  = zeros(num_ports);
            
            % --- Battery ---
            obj.charge_level            = 1;       % 100% charge
            obj.need2charge             = false;   % Full charge
            obj.min_charge_threshold    = 0.3;     % Need to charge when below 30%
            
            % --- Movement ---
            obj.climb_rate         = 0;
            obj.speed              = 0;              % [m/s]
            obj.cruise_speed       = 200/...         % [mph]
                obj.convert.unit('hr2min'); %[mi/min]
            
            % --- Simulation ---
            obj.run_interval = 1;
            obj.plotter            = [];
            obj.last_update_time   = -1;
            obj.setLogLevel(publicsim.sim.Logger.log_INFO);
        end
        
        function init(obj)
            obj.setMovementManager(obj);
            obj.customer_request_topic = obj.getDataTopic(obj.CUSTOMER_REQUEST_TOPIC_KEY,'','');
            obj.trip_accept_topic      = obj.getDataTopic(obj.TRIP_ACCEPT_TOPIC_KEY, '','');
            
            obj.subscribeToTopic(obj.customer_request_topic);
            obj.scheduleAtTime(0);
        end
        
        function runAtTime(obj,time)
            if (time - obj.last_update_time >= obj.run_interval)
                time_since_update = time - obj.last_update_time;
                %                 obj.ac_id
                %                 keyboard
                obj.updateParams(time_since_update);
                
                if strcmp(obj.operation_mode,'idle') %|| strcmp(obj.operation_mode,'charging')
                    obj.findCustomers();
                elseif strcmp(obj.operation_mode,'onTrip') || strcmp(obj.operation_mode,'enroute2pickup')
                elseif  strcmp(obj.operation_mode,'enroute2charging')
                    keyboard
                end
                obj.last_update_time = time;
                obj.scheduleAtTime(time+1);
            end
        end
        
        function updateParams(obj,time_since_update)
            % Location update
            % Check current operation operation_mode
            switch obj.operation_mode
                case {'enroute2pickup', 'onTrip', 'enroute2charging'}
                    dist_flown = obj.updateLocation(time_since_update);
                    obj.updateChargeDrop(dist_flown)
                case 'charging'
                    charging_complete = obj.updateChargeGain(time_since_update);
                    if charging_complete
                        obj.need2charge = false;
                        obj.setOperationMode('idle');
                    end
            end
        end
        
        function dist_flown = updateLocation(obj,time_since_update)
			% Update the aircraft location 
			
			% Checck the operation mode
            if strcmp(obj.operation_mode,'enroute2pickup')
                
                dist2dest = sqrt((obj.location(1)-obj.pickup.location(1))^2+...
                        (obj.location(2)-obj.pickup.location(2))^2);

            else
                dist2dest = sqrt((obj.location(1)-obj.destination.location(1))^2+...
                    (obj.location(2)-obj.destination.location(2))^2);
            end
            
            dist_flown = obj.speed*time_since_update;
            alt_climb  = obj.climb_rate*time_since_update;
            
			% Update arrival at the ports 
            if dist_flown > dist2dest
                if strcmp(obj.operation_mode,'enroute2pickup')
                    obj.reachedPickupPort();
                else
                    obj.reachedDestination();
                end
            else
                obj.setLocation([obj.location(1:2) + dist_flown*obj.dir_vect ...
                    obj.location(3) + alt_climb]);
            end
			
			% Update the realtime plot 
            obj.plotter.updatePlot(obj.location);
        end
        
        function reachedDestination(obj)
            obj.setLocation([obj.destination.location(1:2),obj.location(3)]);
            obj.current_port = obj.destination.id;
            obj.destination = struct();
			
			% Check if the aircraft requires a recharge 
            if obj.need2charge || obj.chargeInsufficientForTrips()
				% Check if the current port has a charger 
                if obj.currentPortHasCharger()
                    obj.speed = 0;
                    obj.setOperationMode('charging');
                else
                    obj.setOperationMode('enroute2charging');
                end
                    
            else
                obj.speed = 0;
                obj.setOperationMode('idle');
            end
			
			% Update operation costs with the cost of landing at the port 
            obj.operating_costs = obj.operating_costs + ...
                obj.parent.getLandingCost(obj.current_port);
            
            % Reset plot trajectory
            obj.plotter.traj = [];
        end
        
        function check = chargeInsufficientForTrips(obj)
            check = false;
			% Determine the mean trip distance from current port to other serviced ports 
            mean_trip_dist = obj.parent.findMeanTripDistances(obj.current_port);
            range_left = obj.charge_level*obj.range;
			% Charge is insufficient if the 80% of the remaining range falls below mean trip distance 
            if 0.8*range_left < mean_trip_dist
                check = true;
            end
        end
        
        function setCruiseSpeed(obj,cruise_speed)
            obj.cruise_speed = cruise_speed/obj.convert.unit('hr2min');
        end
        function check = currentPortHasCharger(obj)
            check = false;
            chargers = obj.parent.serviced_ports{obj.current_port}.chargers;
            if isKey(chargers,obj.parent.team_id)
                check = true;
            end
        end
        
        function updateChargeDrop(obj,dist_flown)
            obj.charge_level = round(obj.charge_level - dist_flown/obj.range,4);
            if ~obj.need2charge
                if obj.charge_level < obj.min_charge_threshold
                    obj.need2charge = true;
                end
            end
        end
        
        function charging_complete = updateChargeGain(obj,time_since_update)
             charging_complete = false;
             charging_port = obj.parent.serviced_ports{obj.current_port};
             charger = charging_port.chargers(obj.parent.team_id);
             
             obj.charge_level = round(obj.charge_level + ...
                 charger.charging_rate*time_since_update/obj.range,4);
             cost = charger.charging_rate*time_since_update*charging_port.charging_cost;
             obj.operating_costs = obj.operating_costs + cost;
%              keyboard
             if round(obj.charge_level,1) == 1
                 charging_complete = true;
                 obj.charge_level = 1;
             end
        end
        
        function setLocation(obj,loc)
            obj.location = loc;
        end
        
        %         % Required to support publicsim's Moveable (plotting)
        %         function [new_state, start_state] = updateLocation(obj,current_state,~)
        %             start_state = current_state;
        %             new_state   = struct('position',obj.state(1:3),'velocity',obj.state(4:6),'acceleration',obj.state(7:9));
        %         end
        
        function findCustomers(obj)
			% Determine demand at the ports and calculate trip prices 
            [topics,msgs] = obj.getNewMessages();
            for i=1:length(topics)
                if isequal(topics{i}.type,obj.CUSTOMER_REQUEST_TOPIC_KEY)
                    response = msgs{i};
                    obj.processCustomerResponse(response);
                end
            end
            if ~isempty(obj.customer_responses)
                best_customer = obj.findBestCustomer();
                if ~isempty(best_customer)
                    obj.acceptTripRequest(best_customer);
                    return;
                end
            end
            % Calculate trip info and broadcast to all serviced ports
            % Trip info: wait time
            %            origin-destinaton price
            trip_info = obj.calcTripInfo();
            obj.broadcastTripPrices(trip_info);
        end
        
        function acceptTripRequest(obj,best_customer)
			% Update the destination based on best customer 
            accept_msg = obj.customer_responses{best_customer};
            if accept_msg.ac_id == -1
                keyboard
            end
            trip_prices = obj.parent.calcPrice(obj);
            obj.current_trip_price = trip_prices(accept_msg.port_id,accept_msg.dest);
            obj.customer_responses(best_customer) = [];
            obj.publishToTopic(obj.trip_accept_topic,accept_msg);
            obj.destination.id = accept_msg.dest;
            obj.destination.location = obj.parent.serviced_ports{obj.destination.id}.location();
            obj.pickup.id      = accept_msg.port_id;
            obj.pickupCustomer();
            obj.addDefaultLogEntry(obj.TRIP_ACCEPT_TOPIC_KEY,accept_msg);
        end
        
        function pickupCustomer(obj)
            if obj.pickup.id == obj.current_port
                obj.updateArrival(obj.pickup.id);
                obj.startTrip();
            else
                obj.setOperationMode('enroute2pickup');
                obj.pickup.location = obj.parent.serviced_ports{obj.pickup.id}.getLocation();
                obj.setDirVect(obj.pickup.location);
                obj.speed  = obj.cruise_speed;
            end
        end
        
        function updateArrival(obj,port_id)
            obj.parent.setPickupArrival(port_id,obj.ac_id);
            obj.revenue = obj.revenue + obj.current_trip_price;
        end
        function reachedPickupPort(obj)
            obj.setLocation([obj.pickup.location(1:2),obj.location(3)]);
            obj.updateArrival(obj.pickup.id);
            obj.setDirVect(obj.destination.location);
            obj.setOperationMode('onTrip');
            [~,pickup_port_ref] = obj.parent.getPortById(obj.pickup.id);
            [~,dest_port_ref]   = obj.parent.getPortById(obj.destination.id);
            count = obj.routes_served_count(pickup_port_ref,dest_port_ref);
            obj.routes_served_count(pickup_port_ref,dest_port_ref) = count+1;
            obj.customers_served_count = obj.customers_served_count +1;
            obj.pickup = struct();
        end
        function marketServed = getMarketServed(obj)
            marketServed.routes_served = obj.routes_served_count;
            marketServed.customers_served = obj.customers_served_count;
        end
        function startTrip(obj)
            obj.setOperationMode('onTrip');
            obj.setDirVect(obj.destination.location);
            obj.speed     = obj.cruise_speed;
            trip_info.ac_id      = obj.ac_id;
            trip_info.wait_times = [];
            trip_info.prices     = [];
            obj.broadcastTripPrices(trip_info);
        end
        
        function setDirVect(obj,dest_location)
            obj.dir_vect = (dest_location(1:2) - obj.location(1:2))/...
                norm(dest_location(1:2) - obj.location(1:2));
        end
        
        function setPlotter(obj,plotter)
            obj.plotter = plotter;
        end
        
        function id = identifier(obj)
            id = 'AC';
            if isfield(obj.flight_plan,'flight_number')
                id = obj.flight_plan.flight_number;
            end
        end
        
        function setOperationMode(obj,mode)
            obj.operation_mode = mode;
            
            % Set Marker color
            switch mode
                case 'idle'
                    obj.plotter.marker.type = 'o';
                case {'charging', 'enroute2charging'}
                    obj.plotter.marker.type = 'd';
                case {'onTrip', 'enroute2pickup'}
                    obj.plotter.marker.type = 's';
            end
        end
        function scheduleNextDT(obj,time)
            obj.scheduleAtTime(time+1); % TODO Is time+1 correct?
        end
        
        function trip_info = calcTripInfo(obj)
            % TODO: Calculate waittime
            wait_times = obj.calcWaitTimes();
            % TODO: Calculate price
            prices     = obj.parent.calcPrice(obj);
            
            trip_info.ac_id      = obj.ac_id;
            trip_info.wait_times = wait_times;
            trip_info.prices     = prices;
            %routes_served = obj.parent.service_routes;
            
        end
        
        function wait_times = calcWaitTimes(obj)
            dist2ports = obj.parent.distance2Ports(obj.location);
            wait_times = dist2ports/obj.cruise_speed;
        end
        
        function broadcastTripPrices(obj,trip_info)
            obj.price_broadcast_topic = obj.getDataTopic(obj.TRIP_TOPIC_KEY,'','');
            obj.publishToTopic(obj.price_broadcast_topic,trip_info)
            obj.addDefaultLogEntry(obj.TRIP_TOPIC_KEY,trip_info);
        end
        
        function processCustomerResponse(obj,response_msgs)
            % response format: response.ac_id
            %                          .port_id
            %                          .route
            for ii=1:length(response_msgs)
                response = response_msgs{ii};
                % Check if message from same customer already exists
                idx = obj.checkForResponse(response);
                if response.ac_id == obj.ac_id
                    if isempty(idx)
                        obj.customer_responses{end+1} = response;
                    else
                        obj.customer_responses{idx}   = response;
                    end
                    break;
                elseif response.ac_id == -1
                    % Delete response
                    if ~isempty(idx)
                        obj.current_trip_price = nan;
                        obj.customer_responses(idx)   = [];
                    end
                end
            end
            
        end
        
        function idx = checkForResponse(obj,response)
            idx = [];
            for ii=1:length(obj.customer_responses)
                stored_resp = obj.customer_responses{ii};
                if response.port_id == stored_resp.port_id && ...
                        response.cust_ref == stored_resp.cust_ref
                    % Same cutomer -- so update the existing response slot
                    idx = ii;
                    break
                end
            end
            
        end
        
        function team_id = getTeamID(obj)
            team_id = obj.getNestedProperty('team_id');
        end
        
        function id = findBestCustomer(obj)
            % Customer that is closest
            if length(obj.customer_responses) == 1
                id = 1;
                return
            end
            dist2Ports    = obj.parent.distance2Ports(obj.location);
            dist2pickup   = zeros(1,length(obj.customer_responses));
            trip_dist     = zeros(1,length(obj.customer_responses));
            for ii=1:length(obj.customer_responses)
                resp = obj.customer_responses{ii};
                dist2pickup(ii) = dist2Ports(resp.port_id);
                trip_dist(ii)   = obj.parent.dist_bw_ports(resp.port_id,resp.dest);
            end
            [min_dist,min_idx]  = min(dist2pickup);
%             if sum(dist2pickup == min_dist) > 1
%                 % More than one customr request from same port
%                 % Check longer trip
%                 check_resp = dist2pickup == min_dist;
%                 d_min = inf;
%                 min_idx = nan;
%                 for ii=1:length(obj.customer_responses)
%                     if check_resp(ii)
%                         if trip_dist(ii) < d_min
%                             d_min = trip_dist(ii);
%                             min_idx = ii;
%                         end
%                     end
%                 end
%             end
            
%             obj.parent.calcExpectedProfit();
            id = min_idx;
        end
        function loc = getLocation(obj)
            loc = obj.location;
        end
        
        function speed = getSpeed(obj)
            speed = obj.speed;
        end
        
        function v = getPosition(obj)
            v = obj.location;
        end
        function a = getAcceleration(obj)
            a = [];
        end
        function v = getVelocity(obj)
            v = obj.speed;
        end
        
        function current_mode = getOperationMode(obj)
            current_mode = obj.operation_mode;
        end
    end
    
    methods (Static,Access=private)
        
        function addPropertyLogs(obj)
			% Define the attributes that needs to be logged
			
			% The attributes can either be an agent property or a function which returns a value 
            obj.addPeriodicLogItems({'getOperationMode','operating_costs','revenue','getMarketServed'});
			
			% Optionally period of logging can also be defined
			% period = 2.0; %[s] in simulation time 
			% obj.addPeriodicLogItems({'getOperationMode','operating_costs','revenue'},period);
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

