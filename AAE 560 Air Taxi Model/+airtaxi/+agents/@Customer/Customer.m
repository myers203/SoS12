classdef Customer < handle
    properties 
        demand_state    % 1=No Acft Assigned, 0=Acft Assigned
        source_id
        dest_id
        spawn_info
    end
    
    properties (Access = private)
        spawn_time      % The time when customer appears at the port
        cancel_prob     % Probability of cancellation
        
        plotter
        convert = airtaxi.util.Convert;
    end
    
    properties (Constant)
        % Properties of the customer
        MAX_PRICE_MU     = 200; % $
        MAX_TIME_MU      = 30; % minutes     
        
        MAX_PRICE_SIG    = 7;  % $
        MAX_TIME_SIG     = 5;  % minutes
        
        CANCEL_PROB_MU   = 0.02;
        CANCEL_PROB_SIG  = 0.01;
        
    end
    methods
        function obj = Customer(spawn_info,src,dst)
            obj.spawn_info   = spawn_info;
            obj.source_id    = src;
            obj.dest_id      = dst;
            obj.demand_state = 1;
            obj.setPlotter();
            obj.plotCustomer();
        end
       
        function setPlotter(obj)
            marker = obj.setMarker();
            obj.plotter      = airtaxi.funcs.plots.Plotter(marker);
        end
        function plotCustomer(obj)
            max_cust = obj.spawn_info.max_customers;
            center   = obj.spawn_info.port_location;    
            theta    = obj.spawn_info.slot_num*2*pi/max_cust;
            R        = 2;
            location = center + R*[cos(theta),sin(theta), 0];
            obj.plotter.updatePlot(location);
        end
        
        function bool = waitTimeOver(obj,time)
            bool = false;
            if time - obj.spawn_time > obj.max_wait_time
                bool = true;
            end
        end
        
        function assigned(obj)
            obj.demand_state = 0;
        end
        
        function setDemandState(obj,val)
            obj.demand_state = val;
        end
        
        function ac_id = findBestDeal(obj,trip_options)
            % Go for the option with lowest price & least wait time
            trip_prices = nan(size(trip_options));
            wait_times  = nan(size(trip_options));
            for ii=1:length(trip_options)
                if isempty(trip_options{ii})
                   price = inf; 
                else
                   price = trip_options{ii}.price;
                end
                wait_times(ii) = trip_options{ii}.wait_time;
                trip_prices(ii) = price;
            end
            zero_wait_trip_prices = trip_prices;
            zero_wait_trip_prices(wait_times ~= 0) = inf;
            if sum(wait_times == 0)
                [~,min_idx] = min(zero_wait_trip_prices);            
            else
                [~,min_idx] = min(trip_prices);
            end
            ac_id = trip_options{min_idx}.ac_id;
        end
        function bool = cancelTrip(obj)
            bool = false;
            % Random cancellation
            if rand() < obj.CANCEL_PROB
                % Cancel Trip
                bool = true;
            end
        end
        
        function deletePlot(obj)
            delete(obj.plotter.plot_handle);
        end
    end
    
    methods(Static)
        function marker = setMarker()
            marker.type      = 'o';
            marker.size      =  6;
            marker.edgeColor = 'k';
            marker.faceColor = 'y';
        end
    end
end