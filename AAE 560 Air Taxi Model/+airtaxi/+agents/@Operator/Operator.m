classdef Operator < publicsim.agents.hierarchical.Parent
    % The airline operator
    properties 
        aircraft_fleet
        serviced_ports
        totaled_aircraft
        fatal_crashes_human
        fatal_crashes_auto
        nonfatal_crashes_human
        nonfatal_crashes_auto
        
        trip_pricing
        dist_bw_ports
    end
    properties (Access = private)
        location
        num_ports
        num_aircraft
        num_tot_acft
        takeoff_clearance   
        landing_clearance
        separation_distance
        vectors_bw_acft
        rel_speed_bw_acft
        dist_bw_acft
        
        crash_threshold
        
        datalink_buffer
        datalink_buf_len
        
        % --- Sim properties ---
        last_update_time
        run_interval
    end
    
    methods
        function obj = Operator()
            obj = obj@publicsim.agents.hierarchical.Parent();
            obj.takeoff_clearance   = 9;
            obj.landing_clearance = 6;
            obj.separation_distance = 0;
            obj.crash_threshold = 50/3280.84;
            obj.useSingleNetwork = false;
            obj.location = [0,0,0];
            
            obj.totaled_aircraft = {};
            obj.num_tot_acft = 0;
            obj.fatal_crashes_human = 0;
            obj.fatal_crashes_auto = 0;
            obj.nonfatal_crashes_human = 0;
            obj.nonfatal_crashes_auto = 0;
            
            obj.dist_bw_ports = []; 
            obj.vectors_bw_acft = {};
            obj.rel_speed_bw_acft = {};
            obj.dist_bw_acft = {};                        
            
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

                obj.calcAircraftDynamicData();
                obj.bufferDatalinkData();
                obj.last_update_time = time;
                obj.checkForCollision();
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
                if norm(vects{i,:}) < obj.takeoff_clearance
                    check = false;
                    break;
                end
            end
        end
           
        
        function resetWaitingTimes(obj,ids)
            for j = 1:length(ids)
                obj.aircraft_fleet{ids(j)}.waiting_time=0;
            end
        end
        
        function w = getWaitingTimes(obj,ids)
            w = zeros(length(ids),1);
            for j = 1:length(ids)
                w(j) = obj.aircraft_fleet{ids(j)}.waiting_time;                   
            end
        end
        
        function check = getLandingClearance(obj,acft)
            ids = zeros(obj.num_aircraft,1);
            d = obj.getAircraftDist2Port(acft);
            check = true;
            ids = find(d<obj.landing_clearance);
                if ~isempty(ids)&&sum(ids==acft.ac_id)==1%make sure the ac
                    %is contained near the port of interest
                holding_times = zeros(length(ids),1);
                for j = 1:length(ids)
                    holding_times(j) = obj.aircraft_fleet{ids(j)}.holding_time;                   
                end
                    if acft.holding_time==0 %first time in the queue
                        check = false;
                        return;
                    elseif acft.holding_time>0  
                        for k = 1:length(ids)
                            %Break the tie with min id
                            if  acft.holding_time==max(holding_times)&&...
                                sum(holding_times==max(holding_times))>1&&...
                                acft.ac_id==min(ids)
                                check = true;
                                return;
                                %let it go if it has the longest holding
                                %time
                            elseif acft.holding_time==max(holding_times)...
                                &&sum(holding_times==max(holding_times))==1
                                check = true;
                                return;
                            elseif acft.holding_time<max(holding_times)%check is false if ac not first one there
                                check = false;
                                return;
                            end
                        end
                    end
                end
            end
        
        function d = getAircraftDist2Port(obj,acft)
            l = zeros(length(obj.num_aircraft),3);
            d = 1:length(l);
            for i = 1:obj.num_aircraft
               l(i,:) = obj.aircraft_fleet{i}.location;
               d(i) = norm(acft.nav_dest - l(i,:));
            end
        end
   
                
        function bufferDatalinkData(obj)
            obj.datalink_buffer = obj.datalink_buffer(2:end);
            obj.datalink_buffer{end+1} = obj.vectors_bw_acft;
        end
        
        function data = getDatalinkData(obj,acft)
            data = obj.datalink_buffer{1};
            data = data(:,acft.ac_id);
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

        function setTakeoffClearance(obj,clearance)
            obj.takeoff_clearance   = clearance;
        end
        
        function setLandingClearance(obj,clearance)
            obj.landing_clearance   = clearance;
        end
        
        function setSeparationDistance(obj,dist)
            obj.separation_distance = dist;
        end
        
        function setNetDelay(obj,delay)
            obj.datalink_buf_len = delay;
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
        
        function checkForCollision(obj)

            check = cell2mat(obj.dist_bw_acft);
            A = tril(check,-1); %use only the lower triangular matrix not including the diagonal term

            row = 2; %row count
            for col = 1:length(A) - 1
                while(row < length(A)+1)
                    if(A(row,col) <= obj.crash_threshold) 
                        p_id_col = obj.aircraft_fleet{col}.current_port;
                        p_id_row = obj.aircraft_fleet{row}.current_port;
                        if ~strcmp(obj.aircraft_fleet{col}.operation_mode,'idle')
                           if ~sum(obj.aircraft_fleet{col}.location(1:2)==...
                                    obj.serviced_ports{p_id_col}.location(1:2))==2
                                    obj.aircraft_fleet{col}.midAirCollision(obj.rel_speed_bw_acft{col,row}); 
                           end
                        end
                        
                        if ~strcmp(obj.aircraft_fleet{row}.operation_mode,'idle')
                           if ~sum(obj.aircraft_fleet{row}.location(1:2)==...
                                obj.serviced_ports{p_id_row}.location(1:2))==2                           
                                obj.aircraft_fleet{row}.midAirCollision(obj.rel_speed_bw_acft{col,row});
                           end
                        end
          
                    end
                    row = row + 1; 
                end
                row = col + 2;
            end
        end
        
        function logFatalCrash(obj,mode)
            if strcmp(mode,'human')
                obj.fatal_crashes_human = obj.fatal_crashes_human+1;
            else
                obj.fatal_crashes_auto = obj.fatal_crashes_auto+1;
            end
        end
        
        function logNonFatalCrash(obj,mode)
            if strcmp(mode,'human')
                obj.nonfatal_crashes_human = obj.nonfatal_crashes_human+1;
            else
                obj.nonfatal_crashes_auto = obj.nonfatal_crashes_auto+1;
            end
        end

        function calcAircraftDynamicData(obj)
            % calculate vectors between all aircraft for datalink buffering
            % and lookup.  Each column/row is vector from that aircraft to
            % all others
            for i=1:obj.num_aircraft
                for j=1:obj.num_aircraft
                    obj.vectors_bw_acft{i,j} = [Inf Inf Inf];
                    obj.dist_bw_acft{i,j} = Inf;
                    obj.rel_speed_bw_acft{i,j} = 0;

                    if i ~= j && (ismember(obj.aircraft_fleet{j}.getOperationMode, ...
                            {'onTrip', 'enroute2pickup'}))&&...
                    (ismember(obj.aircraft_fleet{i}.getOperationMode, ...
                            {'onTrip', 'enroute2pickup'}))
                        
                        % calc vectors between aircraft
                        obj.vectors_bw_acft{i,j} = ...
                            obj.aircraft_fleet{i}.getLocation - ...
                            obj.aircraft_fleet{j}.getLocation;
                        
                        % calc distance between aircraft
                        obj.dist_bw_acft{i,j} = ...
                            norm(obj.vectors_bw_acft{i,j});
                        
                        % calc relative speed between aircraft
                        obj.rel_speed_bw_acft{i,j} = ...
                            norm(obj.aircraft_fleet{i}.getRealVelocity - ...
                            obj.aircraft_fleet{j}.getRealVelocity);                            

                        %relative speed calculation to km/h for pdf
                        obj.rel_speed_bw_acft{i,j} = ...
                            obj.rel_speed_bw_acft{i,j}*1.60934*60; %km/h for pdf  
                    end
                end
            end
        end
        
        function v = vectors2Aircraft(obj,acft)
            v = obj.vectors_bw_acft(:,acft.ac_id);
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
    

end