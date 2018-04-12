classdef Port < airtaxi.agents.Agent & publicsim.agents.base.Locatable & publicsim.agents.hierarchical.Child
    properties
        port_id
        location
        
        trip_options 	
        
        pickups_arrived
        customer_demand
        
        landing_slots
        num_ports

        max_customers = 10      
        current_customers
        free_cust_slots
    end
    
    properties (Access = private)
        
        plotter
        
        last_update_time
        run_interval
    end
    
    methods
        function obj = Port()
            obj = obj@airtaxi.agents.Agent();
            obj@publicsim.agents.base.Locatable();
            
            obj.run_interval = 1;
            obj.last_update_time = -1;
            obj.pickups_arrived = [];
            obj.free_cust_slots = ones(1,obj.max_customers);
        end
        
        function init(obj)
            obj.setLogLevel(publicsim.sim.Logger.log_INFO);
            
            obj.scheduleAtTime(0);
        end
        
%         function runAtTime(obj,time)
%             if (time - obj.last_update_time) >= obj.run_interval
% 
%                 obj.last_update_time = time;
%                 obj.scheduleAtTime(time+1);
%             end
%         end
        
        function updateCustomerStates(obj)
			% Update customer state
            del_flag = zeros(1,length(obj.current_customers));
            for ii=1:length(obj.current_customers)
                cust = obj.current_customers{ii};
                if cust.demand_state == 0
                    if isempty(obj.pickups_arrived)
                        break
                    else
                        % assign first pickup available
                        obj.pickups_arrived = obj.pickups_arrived(2:end);
                        obj.free_cust_slots(cust.spawn_info.slot_num) = 1;
                        cust.deletePlot();
                        
                        % flag customer for deletion
                        del_flag(ii) = 1;
                    end
                end
            end
            % delete picked up customers
            obj.current_customers = obj.current_customers(~del_flag);
        end
        
        function slotNum = fillFirstCustSlot(obj)
            for i=1:obj.max_customers
                if obj.free_cust_slots(i) 
                    obj.free_cust_slots(i) = 0;
                    slotNum = i;
                    break;
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
            destination    = nan(1,customer_data.total_count);
            source         = nan(1,customer_data.total_count);
            for ii=1:customer_data.total_count
                if obj.current_customers{ii}.demand_state
                    served_count = served_count + 1;
                end
                destination(ii)   = obj.current_customers{ii}.dest_id;
                source(ii)        = obj.current_customers{ii}.source_id;
            end
            customer_data.served_count   = served_count;
            customer_data.dest_id        = destination;
            customer_data.source_id      = source;
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