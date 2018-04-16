classdef Weather < publicsim.agents.hierarchical.Parent 
    %WEATHER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        avg_duration
        density_range  % 1.0 = total obscuration; 0 = no obscuration
        weatherCells
    end

    properties (Access = private)
        region_area
        radius_range
        max_cells
        
        % --- Sim properties ---
        last_update_time
        run_interval
    end
    
    methods
        function obj = Weather()
            obj = obj@publicsim.agents.hierarchical.Parent();
            obj.radius_range    = [10, 20];    % [min max] radius
            obj.density_range   = [0.0, 0.2];  % [min max] density
            obj.max_cells = 3;          % max number of weather cells
            obj.avg_duration    = 600;         % avg duration of weather
            
            obj.weatherCells = {};

            obj.useSingleNetwork = false;
            
            % --- Simulation ---
            obj.run_interval     = 1;
            obj.last_update_time = -1;
        end
        
        function runAtTime(obj,time)
            if (time - obj.last_update_time) >= obj.run_interval
                
                obj.spawnWeather(time);

                obj.last_update_time = time;
                obj.scheduleAtTime(time+obj.run_interval);
            end
        end
        
        function init(obj) 
            obj.setLogLevel(publicsim.sim.Logger.log_INFO);
            obj.scheduleAtTime(0);
        end
        
        function spawnWeather(obj,time)
            if length(obj.weatherCells) == obj.max_cells
                return;
            end
            
            if airtaxi.funcs.spawnWeather(time,length(obj.weatherCells), obj.max_cells)
                loc = [randi(obj.region_area(1,:)) randi(obj.region_area(2,:))];
                rad = randi(obj.radius_range);
                density = obj.density_range(1) + ...
                    (obj.density_range(2) - obj.density_range(1)) * rand();

                % Create weather cell and plot
                wc = airtaxi.agents.WeatherCell(loc, rad, density);
                d_range = obj.density_range(2)-obj.density_range(1);
                alpha = 0.1 + 0.2 * density / d_range;
                wc.plotWeather(alpha);
                obj.weatherCells{end+1} = wc;
                obj.addChild(wc);
            end            
        end
        
        function killWeatherCell(obj,wc)
            % find this cell in array
            for i=1:length(obj.weatherCells)
                if obj.weatherCells{i} == wc
                    % remove cell and exit loop
                    obj.weatherCells(i) = [];
                    wc.destroy();
                    break;
                end
            end
        end
        
        function setZone(obj,zone)
            obj.region_area = [ zone.xLim ; zone.yLim ];
        end
        
        function vis = getVisibility(obj,loc1,loc2)
            % returns visibility as a percentage, 1.0 = 100% visible
            dist_in_weather = obj.getDistInWeather(loc1,loc2);
            vis = exp(-obj.density*dist_in_weather);            
        end
        
        function d = getDistInWeather(obj,loc1,loc2)
            [m,b] = airtaxi.funcs.slopInterceptFromPoints(loc1,loc2);            
            [p1,p2] = airtaxi.funcs.lineCircleIntersection(m,b,obj.location,obj.radius);
            
            % use point in same direction of loc2
            if sign(p1(1)-loc1(1)) == sign(loc2(1)-loc1(1))
                % distance = min(dist to weather edge, dist to other acft)
                d = min(airtaxi.funcs.calc_dist(loc1,p1),airtaxi.funcs.calc_dist(loc1,loc2));
            else
                d = min(airtaxi.funcs.calc_dist(loc1,p2),airtaxi.funcs.calc_dist(loc1,loc2));
            end
        end
    end
    
    methods(Static)
        function marker = setMarker()
            marker.type      = 'o';
            marker.size      =  obj.radius;
            marker.edgeColor = 'k';
            marker.faceColor = '';
        end
    end
    
end

