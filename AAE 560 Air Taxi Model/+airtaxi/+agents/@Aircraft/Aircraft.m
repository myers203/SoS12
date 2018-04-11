classdef Aircraft < airtaxi.agents.Agent & publicsim.agents.base.Movable...
        & publicsim.agents.hierarchical.Child & publicsim.agents.physical.Destroyable
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
        climb_rate
        cruise_altitude
        
        % --- Sim properties ---
        last_update_time
        plotter
        run_interval
    end
    
    methods
        function obj = Aircraft(num_ports)
            obj = obj@airtaxi.agents.Agent();
            obj@publicsim.agents.base.Movable();
            % --- Operaional ---
            obj.operation_mode = 'idle';  % When the sim starts it is idle
                                          % Options: 'idle',
                                          %          'onTrip',
                                          %          'enroute2pickup',
                                          %          'crash-fatal',
                                          %          'crash-nonfatal'
            
            obj.color = 'b';
            
            obj.customer_responses  = {};
            obj.destination         = struct();
            
            obj.customers_served_count = 0;
            
            obj.num_ports          = num_ports;
            obj.routes_served_count  = zeros(num_ports);
            
            % --- Movement ---
            obj.climb_rate         = 0;
            obj.speed              = 0;              % [m/s]
            obj.cruise_speed       = 60/...          % [mph]
                obj.convert.unit('hr2min'); %[mi/min]
            
            % --- Simulation ---
            obj.run_interval       = 1;
            obj.plotter            = [];
            obj.last_update_time   = -1;
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
                if strcmp(obj.operation_mode,'idle') 
                elseif strcmp(obj.operation_mode,'onTrip') || strcmp(obj.operation_mode,'enroute2pickup')
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
                    dist_flown = obj.updateLocation(time_since_update);
            end
        end
        
        function dist_flown = updateLocation(obj,time_since_update)
			% Update the aircraft location 
			
			% Calculate remaining distance to destination
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
            else  % Have not arrived yet
                obj.setLocation([obj.location(1:2) + dist_flown*obj.dir_vect ...
                    obj.location(3) + alt_climb]);

%                 Check for collision with other aircraft. Since air
%                 collisions come in pairs, this must be handled at the
%                 fleet (operator) level and is called here.
                  dist2acft = ...
                  obj.parent.distance2Aircraft(obj.ac_id,obj.location);
			
			% Update the realtime plot 
            obj.plotter.updatePlot(obj.location);
            end
        end
        
        function midAirCollision(obj,s_rel)
            p = 1./(1+exp(5.5-.075*s_rel));
            obj.plotter.traj = [];
            obj.destroy()
            if p>.3
                obj.setOperationMode('crash-fatal');
            else
                obj.setOperationMode('crash-nonfatal')
            end
        end
        
        function reachedDestination(obj)
            obj.setLocation([obj.destination.location(1:2),obj.location(3)]);
            obj.current_port = obj.destination.id;
            obj.destination = struct();
			
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
                obj.startTrip();
            else
                obj.setOperationMode('enroute2pickup');
                obj.pickup.location = obj.parent.serviced_ports{obj.pickup.id}.getLocation();
                obj.setDirVect(obj.pickup.location);
                obj.speed = obj.cruise_speed;
            end
        end
        
        function updateArrival(obj,port_id)
            obj.parent.setPickupArrival(port_id,obj.ac_id);
        end
        
        function reachedPickupPort(obj)
            obj.setLocation([obj.pickup.location(1:2),obj.location(3)]);
            obj.updateArrival(obj.pickup.id);
            obj.setDirVect(obj.destination.location);
            obj.setOperationMode('onTrip');
            obj.speed = obj.cruise_speed;
        end
        
        function startTrip(obj)
            obj.setOperationMode('onTrip');
            obj.setDirVect(obj.destination.location);
            obj.speed     = obj.cruise_speed;
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

