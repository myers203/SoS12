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
        takeoff_clearance   
        
        vectors_bw_acft
        
        datalink_buffer
        datalink_buf_len
        
        % --- Sim properties ---
        last_update_time
        run_interval
    end
    
    methods
        function obj = Operator(op_info)
            obj = obj@publicsim.agents.hierarchical.Parent();
            obj.team_id      = op_info{1};
            obj.team_name    = op_info{2};
            
            obj.takeoff_clearance = 1;      % in nmi

            obj.useSingleNetwork = false;
            obj.location = [0,0,0];
            
            obj.dist_bw_ports = []; 
            obj.vectors_bw_acft = {};
            
            obj.datalink_buffer = [];
            obj.datalink_buf_len = 5;

            % --- Simulation ---
            obj.run_interval     = 1;
            obj.last_update_time = -1;
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

                obj.calcVectsBetweenAcft();
                obj.bufferDatalinkData();

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
        
        function check = getClearance(obj,acft)
            vects = obj.vectors2Aircraft(acft);
            check = true;
            for i=1:size(vects,1)
                if norm(vects(i,:)) < obj.takeoff_clearance
                    check = false;
                    return;
                end
            end
        end
        
        function bufferDatalinkData(obj)
            obj.datalink_buffer = obj.datalink_buffer(2:end);
            obj.datalink_buffer{end+1} = obj.vectors_bw_acft;
        end
        
        function data = getDatalinkData(obj,acft)
            data = obj.datalink_buffer{1};
            data = data{acft.ac_id,:};
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
                d(ii)    = airtaxi.funcs.calc_dist(obj_location,port_loc);
            end
        end
        
        function checkForCollision(obj,acft)
            for ii=1:obj.num_aircraft
                if (obj.aircraft_fleet{ii}.ac_id ~= acft.ac_id) && ...
                        (ismember(obj.aircraft_fleet{ii}.getOperationMode, ...
                        {'onTrip', 'enroute2pickup'}))
                    d = airtaxi.funcs.calc_dist3d(acft.location, ...
                        obj.aircraft_fleet{ii}.getLocation());
                    v_2 = obj.aircraft_fleet{ii}.getRealVelocity;
                    v_1 = acft.getRealVelocity;
                    %relative speed calculation
                    s_rel = norm(v_1-v_2)*1.60934*60; %km/h for pdf  
                    %will need to model pdf for inside of EASA's
                    %clearance parameter
                    if d < 1000/6076.12 % ft/nmi
                        %both aircraft involved collide
                        acft.midAirCollision(s_rel);
                        obj.aircraft_fleet{ii}.midAirCollision(s_rel);
                    end
                end
            end
        end
        
        function calcVectsBetweenAcft(obj)
            % calculate vectors between all aircraft for datalink buffering
            % and lookup.  Each column/row is vector from that aircraft to
            % all others
            for i=1:obj.num_aircraft
                for j=1:obj.num_aircraft
                    obj.vectors_bw_acft{i,j} = [Inf Inf Inf];
                    if i ~= j && (ismember(obj.aircraft_fleet{j}.getOperationMode, ...
                            {'onTrip', 'enroute2pickup'}))
                    
                        obj.vectors_bw_acft{i,j} = ...
                            obj.aircraft_fleet{i}.getLocation - ...
                            obj.aircraft_fleet{j}.getLocation;
                    end
                end
            end
        end
        function v = vectors2Aircraft(obj,acft)
            v = obj.vectors_bw_acft{acft.ac_id,:};
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
                    dist(ii,jj) = airtaxi.funcs.calc_dist(port1_loc,port2_loc);
                end
            end
        end
        
    end
    
    methods(Access = private)

    end
end