classdef Customer < handle
    properties 
        ref
        demand_state
        trip_demand
        
        trip_decision
        
        pickup_ac
    end
    
    properties (Access = private)
        spawn_time      % The time when customer appears at the port
        max_price       % Max. price acceptable for the customer
        max_wait_time   % Max. wait time acceptable for the customer
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
        function obj = Customer(spawn_info,trip_demand)
            obj.demand_state = 0;  % 0 --> Not served
                                   % 1 --> Served
            obj.ref = spawn_info.ref;
            obj.trip_demand  = trip_demand;
            obj.spawn_time   = spawn_info.time;
            obj.trip_decision = -1; % No trip selected
            obj.setPlotter();
            obj.plotCustomer(spawn_info);
            obj.generateCharacteristics();
        end
       
        function generateCharacteristics(obj)
            % max_price
            % max_wait_time
            % trip_demand
            obj.max_price      = normrnd(obj.MAX_PRICE_MU,obj.MAX_PRICE_SIG);            
            obj.max_wait_time  = normrnd(obj.MAX_TIME_MU,obj.MAX_TIME_SIG);            
            obj.cancel_prob    = normrnd(obj.CANCEL_PROB_MU,obj.CANCEL_PROB_SIG);            
        end
        
        function setPlotter(obj)
            marker = obj.setMarker();
            obj.plotter      = airtaxi.funcs.plots.Plotter(marker);
        end
        function plotCustomer(obj,spawn_info)
            max_cust = spawn_info.max_customers;
            center   = spawn_info.port_location;    
            R        = 2;
            theta    = spawn_info.ref*2*pi/max_cust;
            location = center + R*[cos(theta),sin(theta), 0];
            obj.plotter.updatePlot(location);
        end
        
        function bool = waitTimeOver(obj,time)
            bool = false;
            if time - obj.spawn_time > obj.max_wait_time
                bool = true;
            end
        end
        function response = acceptTrip(obj, trip_price)
            % If price is acceptable, acceptTrip
            response = true;
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