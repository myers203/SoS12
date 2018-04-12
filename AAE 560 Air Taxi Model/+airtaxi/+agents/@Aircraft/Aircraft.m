classdef Aircraft < airtaxi.agents.Agent & publicsim.agents.base.Movable...
        & publicsim.agents.hierarchical.Child & publicsim.agents.physical.Destroyable
    % Aircraft agent
    properties
        % --- AC properties ---
        ac_id               % Numerical reference for the AC
        type                % AC Type
        pilot_type
        num_seats           % Number of seats available in the AC
        cruise_speed        % Cruise speed
        range               % Max. distance in miles with a fully-charged battery
        
        % --- Ops properties ---
        operation_mode      
        current_port
        num_ports
        
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
        dir_vect
        dir_vect_next
        climb_rate
        cruise_altitude
        max_turn_rate       
        arrival_threshold
        nav_dest
        nav_dist_thresh 
        
        % --- Sim properties ---
        last_update_time
        plotter
        run_interval
        plot_crashes
    end
    
    methods
        function obj = Aircraft(num_ports)
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
            obj.pilot_type = 'full-auto'; % Options: 'human',
                                          %          'full-auto'
            
            obj.customer_responses  = {};
            obj.destination         = struct();
            
            obj.customers_served_count = 0;
            
            obj.num_ports           = num_ports;
            obj.routes_served_count = zeros(num_ports);
            obj.arrival_threshold   = 2;
            
            % --- Movement ---
            obj.climb_rate         = 0;
            obj.max_turn_rate      = deg2rad(10);    
            obj.speed              = 0;              % [m/s]
            % Uber White Paper: "3. En-route VTOL airspeed is 170 mph."
            obj.cruise_speed       = 170/...          % [mph]
                obj.convert.unit('hr2min'); %[mi/min]
            
            % only account for acft < XXX nmi away
            obj.nav_dist_thresh    = 20; 
            
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
                            obj.setOperationMode('enroute2pickup');
                            obj.startPickup();
                        end
                    case {'wait4trip'}
                        if obj.parent.getClearance(obj)
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
                dist = norm(acftRelPos(i,:));
                % only process aircraft within threhold distance
                if dist < obj.nav_dist_thresh  
                    % get angle between flight vector and aircraft vector
                    alpha = atan2(obj.dir_vect(2),obj.dir_vect(1)) - ...
                        atan2(acftRelPos(i,2),acftRelPos(i,1));
                    
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
            acftRelPos = {};
        end
        
        function dist_flown = updateLocation(obj,time_since_update)
			% Update the aircraft location 
			
			% Calculate remaining distance to target location
            dist2dest = airtaxi.funcs.calc_dist(obj.location,obj.nav_dest);
            
            dist_flown = obj.speed*time_since_update;
            alt_climb  = obj.climb_rate*time_since_update;
            
			% Update arrival at the ports 
            if dist2dest < obj.arrival_threshold
                if strcmp(obj.operation_mode,'enroute2pickup')
                    obj.reachedPickupPort();
                else
                    obj.reachedDestination();
                end
            else  % Have not arrived yet
                obj.setLocation([obj.location(1:2) + dist_flown*obj.dir_vect ...
                    obj.location(3) + alt_climb]);
                
                % Set dir_vect to new vector
                obj.dir_vect = obj.dir_vect_next;
                
                % Check for collision with other aircraft.  Since air
                % collisions come in pairs, this must be handled at the
                % fleet (operator) level and is called here.
                %obj.parent.checkForCollision(obj);


            end
			
			% Update the realtime plot 
            obj.plotter.updatePlot(obj.location);
        end
        
        function midAirCollision(obj,s_rel)
            p = 1/(1+exp(5.5-.075*s_rel));
            if p>.4
                obj.setOperationMode('crash-fatal');
            else
                obj.setOperationMode('crash-nonfatal')
            end
            
            if obj.plot_crashes
                obj.speed = 0;
                obj.destination = struct();
                obj.plotter.traj = [];
                % Update the realtime plot 
                obj.plotter.updatePlot(obj.location);
                obj.destroy()
            end
        end
        
        function reachedDestination(obj)
            obj.setLocation([obj.destination.location(1:2),obj.location(3)]);
            obj.current_port = obj.destination.id;
            obj.destination = struct();
            obj.nav_dest = [];
			
            obj.speed = 0;
            obj.setOperationMode('idle');
			
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
            obj.setLocation([obj.pickup.location(1:2),obj.location(3)]);
            obj.updateArrival(obj.pickup.id);
            obj.setOperationMode('wait4trip');
        end
        
        function startPickup(obj)
            obj.setOperationMode('enroute2pickup');
            obj.nav_dest = obj.pickup.location;
            obj.dir_vect = obj.getVector(obj.location, obj.nav_dest);
            obj.speed    = obj.cruise_speed;
        end
        
        function startTrip(obj)
            obj.setOperationMode('onTrip');
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
                case {'crash-fatal', 'crash-nonfatal'}
                    obj.plotter.marker.type = 'x';
                    obj.color = 'r';
            end
        end
        
        function scheduleNextDT(obj,time)
            obj.scheduleAtTime(time+1); % TODO Is time+1 correct?
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

