classdef Weather < publicsim.agents.base.Locatable
    %WEATHER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        location
        radius
        density  % 1.0 = total obscuration; 0 = no obscuration

        plotter
    end
    
    methods
        function obj = Weather(location,radius,density)
            obj = obj@publicsim.agents.base.Locatable();
            obj.location = location;
            obj.radius   = radius;
            obj.density  = density;

            obj.setPlotter();
        end
        
        function plotWeather(obj)
            % TODO:  Plot Weather ???

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

