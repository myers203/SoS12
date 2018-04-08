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
        end
        
        function setTripPricing(obj,types,values)
            obj.trip_pricing = containers.Map(types,values);
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
        function prices = calcPrice(obj,ac)
            if isempty(obj.dist_bw_ports)
                obj.dist_bw_ports  = obj.calcDistBetweenPorts();
            end
            prices = nan(obj.num_ports);
            dist2ports = obj.distance2Ports(ac.location);
            for ii=1:obj.num_ports
                for jj=1:obj.num_ports
                    if ii == jj
                        continue
                    end
                    total_dist = dist2ports(ii) + obj.dist_bw_ports(ii,jj);
                    prices(ii,jj) = obj.price_per_mile*total_dist;
                end
            end
        end
        
        function cost = getLandingCost(obj,port_id)
            port = obj.getPortById(port_id);
            cost = port.landing_cost;
        end
        
        function [port,ii] = getPortById(obj,port_id)
            for ii=1:length(obj.serviced_ports)
                if obj.serviced_ports{ii}.port_id == port_id
                    port = obj.serviced_ports{ii};
                    break;
                end
            end
        end
        function d = distance2Ports(obj,ac_location)
            d = zeros(1,obj.num_ports);
            for ii=1:obj.num_ports
                port_loc = obj.serviced_ports{ii}.getLocation;
                d(ii)    = obj.calc_dist(ac_location,port_loc);
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
        
        function setPickupArrival(obj,port_id,ac_id)
            port = obj.getPortById(port_id);
            port.pickupArrived(ac_id);
        end
    end
    
    methods(Access = private)

    end
end