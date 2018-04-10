classdef Operator < publicsim.agents.hierarchical.Parent
    % The airline operator
    properties 
        team_id         
        team_name       
        aircraft_fleet
        serviced_ports
        budget
        
        trip_pricing
        dist_bw_ports
    end
    properties (Access = private)
        location
        num_ports
        num_aircraft
        total_budget
        investment 
        
        price_per_mile

        % --- Sim properties ---
        last_update_time
        run_interval
    end
    
    methods
        function obj = Operator(op_info)
            obj = obj@publicsim.agents.hierarchical.Parent();
            obj.team_id      = op_info{1};
            obj.team_name    = op_info{2};
            obj.total_budget = op_info{3};
            obj.investment   = op_info{4};
            
            
            obj.useSingleNetwork = false;
            obj.price_per_mile   = 0.5;    % $ per mile
            obj.location = [0,0,0];
            
            obj.dist_bw_ports = []; 

            % --- Simulation ---
            obj.run_interval = 1;
            obj.last_update_time   = -1;
        end
        
        function init(obj) 
            obj.dist_bw_ports  = obj.calcDistBetweenPorts();
            obj.setLogLevel(publicsim.sim.Logger.log_INFO);
            obj.scheduleAtTime(0);
        end
        
        function runAtTime(obj,time)
            if (time - obj.last_update_time) >= obj.run_interval
                for i=1:obj.num_ports
                    port = obj.serviced_ports{i};
                    obj.assignLocalAircraft(port);
                    port.updateCustomerStates();
                end
                
                for i=1:obj.num_ports
                    port = obj.serviced_ports{i};
                    obj.assignRemoteAircraft(port);
                    port.updateCustomerStates();
                    obj.spawnDemand(port,time);
                end

                obj.last_update_time = time;
                obj.scheduleAtTime(time+obj.run_interval);
            end
        end
        
        function assignAircraft(~,port,acft,cust)
            acft.assignTrip(port.port_id,cust.dest_id);  
            cust.assigned();
        end
        
        function assignLocalAircraft(obj,port)
            for i=1:length(port.current_customers)
                cust = port.current_customers{i};
                if port.current_customers{i}.demand_state == 1
                    acft = obj.getAvailableAircraftAtPort(port);
                    if isempty(acft)
                        break;
                    end
                    obj.assignAircraft(port,acft,cust);
                end
            end
        end

        function assignRemoteAircraft(obj,port)
            for i=1:length(port.current_customers)
                cust = port.current_customers{i};
                demand_state = port.current_customers{i}.demand_state;
                if demand_state == 1
                    % sort ports in order of distance
                    [~,idx] = sort(obj.dist_bw_ports(port.port_id,:));
                    
                    % first port is self, so start with 2nd in list
                    for j=2:length(idx)  
                        otherPort = obj.serviced_ports{idx(j)};
                        acft = obj.getAvailableAircraftAtPort(otherPort);
                        if isempty(acft)
                            continue;
                        else
                            obj.assignAircraft(port,acft,cust);
                        end
                    end
                end
            end
        end
        
        function spawnDemand(obj,port,time)	
			if length(port.current_customers) == ...
                    port.max_customers 
				% Maximum customers reached
				return
			end
			
			% Check if the demand spawning function returns demand for this port at this time			
            if airtaxi.funcs.spawnCustomer(time,port)
                dest = [];
                while isempty(dest)
                    dest = randi([1 obj.num_ports]);
                    if dest == port.port_id
                        dest = [];
                    end
                end
                
                % Populate Spawn Info
                spawn_info.time          = time;
                spawn_info.slot_num      = port.fillFirstCustSlot();
                spawn_info.port_location = port.location;
                spawn_info.max_customers = port.max_customers;

                % Create customer object
                customer = airtaxi.agents.Customer(spawn_info,port.port_id,dest);
                port.current_customers{end+1} = customer;
            end
        end
        
        function aircraft = getAvailableAircraftAtPort(obj,port)
            aircraft = {};
            for i=1:obj.num_aircraft
                acft = obj.aircraft_fleet{i};
                if strcmp(acft.operation_mode,'idle') && ...
                        acft.current_port == port.port_id
                    aircraft = acft;
                    return
                end
            end
        end
        
        function setPickupArrival(obj,port_id,ac_id)
            port = obj.getPortById(port_id);
            port.pickupArrived(ac_id);
        end
        
        function setService(obj,ports)
            obj.serviced_ports = ports;
            obj.num_ports      = length(ports);
        end
        
        function setAircraft(obj,acft)
            obj.aircraft_fleet = acft;
            obj.num_aircraft   = length(acft);
        end
        
        function port_id = findNearbyPort(obj,ac_location)
            d = obj.distance2Ports(ac_location);
            [~,min_idx] = min(d);
            port_id = obj.serviced_ports{min_idx}.port_id;
        end
        
        function setLocation(obj,location,earth)
            obj.location   = location;
            obj.state(1:3) = earth.convert_lla2ecef(location)';
        end
        
        function loc = getLocation(obj)
            loc = obj.location;
        end
        
        function mean_trip_dist = findMeanTripDistances(obj,port_id)
            dist2Ports = obj.dist_bw_ports(port_id,:);
            % Eliminate distance to itself
            dist2Ports(dist2Ports == 0) = [];
            mean_trip_dist = sum(dist2Ports)/(obj.num_ports-1);
        end
        
        function [port,ii] = getPortById(obj,port_id)
            for ii=1:length(obj.serviced_ports)
                if obj.serviced_ports{ii}.port_id == port_id
                    port = obj.serviced_ports{ii};
                    break;
                end
            end
        end
        
        function [acft,ii] = getAircraftById(obj,ac_id)
            for ii=1:length(obj.aircraft_fleet)
                if obj.aircraft_fleet{ii}.ac_id == ac_id
                    acft = obj.aircraft_fleet{ii};
                    break;
                end
            end
        end
        
        function d = distance2Ports(obj,obj_location)
            d = zeros(1,obj.num_ports);
            for ii=1:obj.num_ports
                port_loc = obj.serviced_ports{ii}.getLocation;
                d(ii)    = obj.calc_dist(obj_location,port_loc);
            end
        end
        
        function d = distance2Aircraft(obj,acft_id,ac_location)
            d = zeros(1,obj.num_aircraft);
            for ii=1:obj.num_aircraft
                if obj.aircraft_fleet{ii}.ac_id == acft_id
                    d(ii) = Inf;
                else
                    if ismember(obj.aircraft_fleet{ii}.getOperationMode, ...
                            ['onTrip', 'enroute2pickup'])
                        ac_loc = obj.aircraft_fleet{ii}.getLocation;
                        d(ii) = obj.calc_dist3d(ac_location,ac_loc);
                    else
                        d(ii) = Inf;
                    end
                end
            end
        end
            
        function dist = calcDistBetweenPorts(obj)
            dist = zeros(obj.num_ports);
            for ii=1:obj.num_ports
                port1_loc = obj.serviced_ports{ii}.getLocation;
                for jj=1:obj.num_ports
                    if ii == jj
                        continue
                    end
                    port2_loc = obj.serviced_ports{jj}.getLocation;
                    dist(ii,jj) = obj.calc_dist(port1_loc,port2_loc);
                end
            end
        end
        
        function dist = calc_dist(~,loc1,loc2)
            dist = sqrt((loc1(1)-loc2(1))^2 + (loc1(2)-loc2(2))^2);
        end
        
        function dist = calc_dist3d(~,loc1,loc2)
            dist = sqrt((loc1(1)-loc2(1))^2 + (loc1(2)-loc2(2))^2 + ...
                (loc1(3)-loc2(3))^2);
        end
        
    end
    
    methods(Access = private)

    end
end