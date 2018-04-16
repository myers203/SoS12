classdef Operator < publicsim.agents.hierarchical.Parent
    % The airline operator
    properties 
        team_id         
        team_name       
        aircraft_fleet
        serviced_ports
        budget
        totaled_aircraft
        fatal_crashes
        nonfatal_crashes
        
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
        vectors_bw_acft
        rel_speed_bw_acft
        dist_bw_acft
        danger_threshold
        
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
            obj.takeoff_clearance = 9;      % in nmi
            obj.landing_clearance = 6;
            obj.danger_threshold = 100/6076.12;
            obj.useSingleNetwork = false;
            obj.location = [0,0,0];
            
            obj.totaled_aircraft = {};
            obj.num_tot_acft = 0;
            obj.fatal_crashes = 0;
            obj.nonfatal_crashes = 0;
            
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
            check1 = true;
            for i=1:size(vects,1)
                if norm(vects{i,:}) < obj.takeoff_clearance
                    check1 = false;
                    break;
                end
            end
            
            check2 = true;
            %this loop checks for vehicles that might takeoff
            %simultaneously at the same vertiport
            cur_ports = 1:obj.num_aircraft;
            for i=1:size(vects,1)
                cur_ports(i) = obj.aircraft_fleet{i}.current_port;
            end

            ids = find(acft.current_port==cur_ports);
           if ~isempty(ids)
            for i=1:length(ids)
                waiting_times = obj.getWaitingTimes(ids);
               if (strcmp(obj.aircraft_fleet{ids(i)}.operation_mode, 'onTrip')...
                       ||strcmp(obj.aircraft_fleet{ids(i)}.operation_mode, 'enroute2pickup'))...
                       && (strcmp(acft.operation_mode, 'wait4trip')...
                       ||strcmp(acft.operation_mode, 'wait2pickup')...
                       &&sum(acft.location(1:2)==obj.aircraft_fleet{ids(i)}.location(1:2))==2)
                   check2 = false;
                   break;
               elseif strcmp(obj.aircraft_fleet{ids(i)}.operation_mode, 'wait4trip')...
                       ||strcmp(obj.aircraft_fleet{ids(i)}.operation_mode, 'wait2pickup')...
                       && strcmp(acft.operation_mode, 'wait4trip')...
                       ||strcmp(acft.operation_mode, 'wait2pickup')
                       if max(waiting_times)==0 %assign a new waiting time for all at the port
                            for j = 1:length(ids)
                                obj.aircraft_fleet{ids(j)}.waiting_time =...
                                    obj.aircraft_fleet{ids(j)}.waiting_time-j;                   
                            end
                            
                            waiting_times = obj.getWaitingTimes(ids);
                            if acft.waiting_time<max(waiting_times)
                                check2=false;
                                break;
                            end
                       elseif acft.waiting_time<max(waiting_times) 
                           check2 = false;
                           break;
                       elseif sum(waiting_times==max(waiting_times))>=2
                            %reset the waiting times
                            %which will cause the loop to go back to the
                            %beginning if-statement for this port on the
                            %next run
                            obj.resetWaitingTimes(ids);
                            check2 = false;
                           break;
                       end
               end  

            end
            end
            check = check1==check2;
            
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
                if ~isempty(ids)&&sum(ids==acft.ac_id)==1
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
        
        function checkForCollision(obj)

            flag_crashed = zeros(1,obj.num_aircraft);
            for i=1:obj.num_aircraft
                for j=1:obj.num_aircraft
                    if i ~= j && (ismember(obj.aircraft_fleet{j}.getOperationMode, ...
                            {'onTrip', 'enroute2pickup'}))&&...
                            (ismember(obj.aircraft_fleet{i}.getOperationMode, ...
                            {'onTrip', 'enroute2pickup'}))

                        s_rel = obj.rel_speed_bw_acft{i,j};
                        %will need to model pdf for inside of EASA's
                        %clearance parameter
                        if obj.dist_bw_acft{i,j} < 100/6076.12 % ft/nmi
                            %all aircraft involved collide
                            flag_crashed(i) = 1;
                            flag_crashed(j) = 1;
                        end
                    end
                end
            end
            
            % reset all crashed aircraft
            for i=1:obj.num_aircraft
                if flag_crashed(i)
                    % force collision to destroy
                    obj.aircraft_fleet{i}.midAirCollision(s_rel);
                end
            end
        end
        
        function logFatalCrash(obj)
            obj.fatal_crashes = obj.fatal_crashes+1;
        end
        
        function logNonFatalCrash(obj)
            obj.nonfatal_crashes = obj.nonfatal_crashes+1;
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
    
    methods(Access = private)

    end
end