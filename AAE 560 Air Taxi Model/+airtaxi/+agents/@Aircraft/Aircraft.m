<<<<<<< HEAD
classdef Aircraft < airtaxi.agents.Agent & publicsim.agents.base.Movable...
        & publicsim.agents.hierarchical.Child
    % Aircraft agent
    properties
        % --- AC properties ---
        ac_id               % Numerical reference for the AC
        pilot_type
        cruise_speed        % Cruise speed
        
        % --- Ops properties ---
        operation_mode      
        current_port
        num_ports
        holding_time
        nav_dest
        waiting_time
        
        % --- Dynamics properties ---
        location            % Current location
        speed               % Current speed
        
    end

    properties (Access = protected)

        color
        
        % --- Customer ---
        customer_responses
        customers_served_count
        routes_served_count
        pickup
        destination
        
        % --- Dynamics ---
        visibility
        skill
        dir_vect
        dir_vect_next
        climb_rate
        cruise_altitude
        max_turn_rate       
        arrival_threshold
 
        nav_dist_thresh 
        visual_range
        
        % --- Sim properties ---
        last_update_time
        plotter
        run_interval
        plot_crashes
    end
    
    methods
        function obj = Aircraft()
            obj = obj@airtaxi.agents.Agent();
            obj@publicsim.agents.base.Movable();
            % --- Operaional ---
            obj.operation_mode = 'idle';  % When the sim starts it is idle
                                          % Options: 'idle',
                                          %          'wait2pickup',
                                          %          'wait4trip',
                                          %          'onTrip',
                                          %          'enroute2pickup',
                                          %          'crash-fatal',
                                          %          'crash-nonfatal'
            
            obj.color = 'b';

            % Options: 'human','full-auto'
            obj.pilot_type = 'human'; 
%             obj.pilot_type = 'full-auto'; 
          
            obj.pilot_type = []; 
            
            obj.customer_responses  = {};
            obj.destination         = struct();
            
            obj.customers_served_count = 0;
            
            obj.num_ports           = num_ports;
            obj.routes_served_count = zeros(num_ports);
            obj.arrival_threshold   = 6;
            obj.holding_time = 0;
            obj.waiting_time = 0;

            obj.arrival_threshold   = 3.2;
            
            % --- Movement ---
            obj.climb_rate         = 0;
            obj.max_turn_rate      = deg2rad(10);    
            obj.speed              = 0;              % [m/s]
            % Uber White Paper: "3. En-route VTOL airspeed is 170 mph."
            obj.cruise_speed       = 170/...          % [mph]
            obj.cruise_speed       = 270/...          % [km/hr]
                obj.convert.unit('hr2min'); %[mi/min]
            
            % only account for acft < XXX nmi away
            obj.nav_dist_thresh    = 20; 
            obj.visual_range       = 20;
            
            % --- Simulation ---
            obj.run_interval       = 1;
            obj.plotter            = [];
            obj.last_update_time   = -1;
            obj.plot_crashes       = true;
            obj.setLogLevel(publicsim.sim.Logger.log_INFO);
        end
        
        function init(obj)
            obj.setMovementManager(obj);
            obj.scheduleAtTime(0);
        end
        
        function runAtTime(obj,time)
            if (time - obj.last_update_time >= obj.run_interval)
                time_since_update = time - obj.last_update_time;

                obj.updateParams(time_since_update);
                switch obj.operation_mode
                    case {'idle'}
                    case {'wait2pickup'}
                        if obj.parent.getClearance(obj)
                            obj.waiting_time=0;
                            obj.setOperationMode('enroute2pickup');
                            obj.startPickup();
                        end
                    case {'wait4trip'}
                        if obj.parent.getClearance(obj)
                            obj.waiting_time=0;
                            obj.setOperationMode('onTrip');
                            obj.startTrip();
                        end
                    case {'onTrip', 'enroute2pickup'}
                end
                
                obj.last_update_time = time;
                obj.scheduleAtTime(time+obj.run_interval);
            end
        end
        
        function updateParams(obj,time_since_update)
            % Location update
            % Check current operation operation_mode
            switch obj.operation_mode
                case {'enroute2pickup', 'onTrip'}
                    % find new vector
                    obj.navigate();
                    % update location based on last vector
                    obj.updateLocation(time_since_update);
            end
        end
        
        function navigate(obj)
            % get next direction vector
            vector = obj.getVector(obj.location,obj.nav_dest);

            theta = obj.avoidCollision();
            % limit to max turn rate
            theta = sign(theta) * min(obj.max_turn_rate,abs(theta));
            
            % rotate direction vector by theta
            RotMatrix = [cos(theta)  -sin(theta); 
                         sin(theta)  cos(theta)];
            obj.dir_vect_next = (RotMatrix * vector')';
        end
        
        function delta_theta = avoidCollision(obj)
            % TODO: add collision avoidance algorithm
            acftRelPos = obj.gatherSA();
            
            % modify vector based on SA data
            delta_theta = 0;
            for i=1:size(acftRelPos,1)
                d_theta = 0;
                v = acftRelPos{i,:};
                dist = norm(v);
                % only process aircraft within threhold distance
                if dist < obj.nav_dist_thresh  
                    % get angle between flight vector and aircraft vector
                    alpha = atan2(obj.dir_vect(2),obj.dir_vect(1)) - ...
                        atan2(v(2),v(1));
                    
                    % only worried about acft in front of us
                    if (alpha > -pi/2) && (alpha < pi/2)
                        % d_theta should stear us 45 deg away from other
                        % aircraft, scaled by distance (closer aircraft
                        % have higher impace to d_theta
                        d_theta = sign(alpha)*pi/4 - alpha;
                        d_theta = d_theta * ...
                            (obj.nav_dist_thresh-dist)/obj.nav_dist_thresh ;
                    end
                end
                
                delta_theta = delta_theta + d_theta;
            end
        end
        
        function acftRelPos = gatherSA(obj)
            if strcmp(obj.pilot_type, 'full-auto')
                acftRelPos = obj.gatherDatalinkSA();
            elseif strcmp(obj.pilot_type, 'human')
                acftRelPos = obj.gatherVisualSA();
            end
        end
        
        function acftRelPos = gatherDatalinkSA(obj)
            % TODO: add datalink SA
            acftRelPos = obj.parent.getDatalinkData(obj);
        end
        
        function acftRelPos = gatherVisualSA(obj)
            % TODO: add visual SA
            w = obj.getWeather();
            acftRelPos = obj.parent.vectors2Aircraft(obj);

            % filter out all aircraft outside of visual range
            del_flag = zeros(1,size(acftRelPos,1));
            for i=1:size(acftRelPos,1)
                % filter out aircraft beyond visual range
                if norm(acftRelPos{i,:}) > obj.visual_range
                    del_flag(i) = 1;
                else  % in normal visual range
                    % now filter out those blocked by weather
                    vis = 1.0;
                    for j=1:length(w)
                        % accumulate all visibility impacts
                        vis = vis * w{j}.getVisibility(obj.location, ...
                                obj.location + acftRelPos{i,:});
                    end
                    if rand() > vis
                        del_flag(i) = 1;
                    end                            
                end
            end
            % delete flagged aircraft
            acftRelPos = acftRelPos(~del_flag);
        end
        
        function dist_flown = updateLocation(obj,time_since_update)
			% Update the aircraft location 
			
			% Calculate remaining distance to target location
            dist2dest = airtaxi.funcs.calc_dist(obj.location,obj.nav_dest);
            
            dist_flown = obj.speed*time_since_update;
            alt_climb  = 3;
            obj.location(3) = alt_climb;
            
            
            
            if dist2dest < obj.arrival_threshold && obj.parent.getLandingClearance(obj)
                if strcmp(obj.operation_mode,'enroute2pickup')
                    obj.setOperationMode('wait4trip');
                    obj.reachedPickupPort();
                    obj.holding_time = 0;
                else
                    obj.setOperationMode('idle');
                    obj.reachedDestination();
                    obj.holding_time = 0;
                end
            elseif dist2dest>obj.arrival_threshold % Have not arrived yet
                obj.setLocation([obj.location(1:2) + dist_flown*obj.dir_vect ...
                    obj.location(3)]);         
                % Set dir_vect to new vector
                obj.dir_vect = obj.dir_vect_next;
            else
                obj.speed = 0;
                obj.holding_time = obj.holding_time + obj.run_interval;
            end
			
			% Update the realtime plot 
            obj.plotter.updatePlot(obj.location);
        end
        
        function midAirCollision(obj,s_rel)
            p = 1/(1+exp(5.5-.075*s_rel));
            if p>.4
                obj.parent.logFatalCrash();
            else
                obj.parent.logNonFatalCrash();
                obj.parent.logFatalCrash(obj.pilot_type);
%                 obj.setOperationMode('crash-fatal');
            else
                obj.parent.logNonFatalCrash(obj.pilot_type);
%                 obj.setOperationMode('crash-nonfatal')
            end
            crash_location=obj.location;
            destination = obj.nav_dest;
            id = obj.ac_id;
            table(id,destination,crash_location)
            v = obj.location;
            plot(v(1),v(2),'rx','MarkerSize',12,'LineWidth',2);
            obj.operation_mode = 'idle';
            obj.location = obj.nav_dest;
            obj.speed = 0;
            obj.destination = struct();
            obj.plotter.traj = [];
            obj.plotter.updatePlot(obj.location);
        end
        
        function w = getWeather(obj)
            % Get all weather systems we are inside of
            global globalWeather;
            w = {};
            for i = 1:length(globalWeather.weatherCells)
                wLoc = globalWeather.weatherCells{i}.getPosition();
                dist = airtaxi.funcs.calc_dist(wLoc,obj.location);
                if dist < globalWeather.weatherCells{i}.getRadius()
                    % we are in this weather cell, return this one
                    w{end+1} = globalWeather.weatherCells{i};
                end
            end
        end
        
        function reachedDestination(obj)
            obj.setOperationMode('idle');
            obj.setLocation([obj.destination.location(1:2),0]);
            obj.current_port = obj.destination.id;
            obj.destination = struct();
            obj.nav_dest = [];
            obj.speed = 0;
			
            % Reset plot trajectory
            obj.plotter.traj = [];
        end
        
        function setCruiseSpeed(obj,cruise_speed)
            obj.cruise_speed = cruise_speed/obj.convert.unit('hr2min');
        end
        
        function setLocation(obj,loc)
            obj.location = loc;
        end
        
        function assignTrip(obj,src_id,dest_id)
            obj.destination.id = dest_id;
            dest = obj.parent.getPortById(dest_id);
            obj.destination.location = dest.location();
            obj.pickup.id = src_id;
            obj.pickupCustomer();
        end
        
        function pickupCustomer(obj)
            if obj.pickup.id == obj.current_port
                obj.updateArrival(obj.pickup.id);
                obj.setOperationMode('wait4trip');
            else
                obj.pickup.location = obj.parent.getPortById(obj.pickup.id).getLocation();
                obj.setOperationMode('wait2pickup');
            end
        end
        
        function updateArrival(obj,port_id)
            obj.parent.setPickupArrival(port_id,obj.ac_id);
        end
        
        function reachedPickupPort(obj)
            obj.setOperationMode('wait4trip');
            obj.setLocation([obj.pickup.location(1:2),0]);
            obj.updateArrival(obj.pickup.id);
        end
        
        function startPickup(obj)
            obj.setOperationMode('enroute2pickup');
            obj.location(3) = 3;
            obj.nav_dest = obj.pickup.location;
            obj.dir_vect = obj.getVector(obj.location, obj.nav_dest);
            obj.speed    = obj.cruise_speed;
        end
        
        function startTrip(obj)
            obj.setOperationMode('onTrip');
            obj.location(3) = 3;
            obj.nav_dest = obj.destination.location;
            obj.dir_vect = obj.getVector(obj.location, obj.nav_dest);
            obj.speed    = obj.cruise_speed;
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
                case {'onTrip', 'enroute2pickup'}
                    obj.plotter.marker.type = 's';
            end
        end
        
        function scheduleNextDT(obj,time)
            obj.scheduleAtTime(time+1); % TODO Is time+1 correct?
        end
        
        function setVisibility(obj,vis)
            obj.visibility = vis;
        end
        
        function setSkill(obj,skill) 
            obj.skill = skill;
        end
        
        function team_id = getTeamID(obj)
            team_id = obj.getNestedProperty('team_id');
        end
        
        function c = getColor(obj)
            c = obj.color;
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
        
        %necessary for finding relative speed of impact
        function v = getRealVelocity(obj)
            v =  obj.speed.*obj.dir_vect;
        end
        
        function current_mode = getOperationMode(obj)
            current_mode = obj.operation_mode;
        end
    end
    
    methods (Static)
        function v = getVector(loc1, loc2)
            v = loc2(1:2) - loc1(1:2);
            v = v/norm(v);
        end
        
    end
    
    methods (Static,Access=private)
        
        function addPropertyLogs(obj)
			% Define the attributes that needs to be logged
			
			% The attributes can either be an agent property or a function which returns a value 
            obj.addPeriodicLogItems({'getOperationMode'});
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

=======
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

>>>>>>> new-branch-for-clearance-updates
