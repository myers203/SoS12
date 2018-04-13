classdef WeatherCell < publicsim.agents.hierarchical.Child & publicsim.agents.physical.Destroyable
    %WEATHERCELL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        location
        radius
        density  % 1.0 = total obscuration; 0 = no obscuration
        duration


        % --- Sim properties ---
        plotter
        last_update_time
        run_interval
    end
    
    methods
        function obj = WeatherCell(location,radius,density)
            obj.location = location;
            obj.radius   = radius;
            obj.density  = density;

            obj.duration = 0;
            
            obj.plotter = [];

            % --- Simulation ---
            obj.run_interval     = 1;
            obj.last_update_time = -1;
        end
        
        function init(obj)
            obj.setLogLevel(publicsim.sim.Logger.log_INFO);
            obj.scheduleAtTime(0);
        end
        
        function runAtTime(obj,time)
            if (time - obj.last_update_time) >= obj.run_interval

                obj.duration = obj.duration + (time - obj.last_update_time);

                if obj.weatherDone(time) 
                    obj.deletePlot();
                    obj.parent.killWeatherCell(obj);
                end
                
                obj.last_update_time = time;
                obj.scheduleAtTime(time+obj.run_interval);
            end
        end
        
        function check = weatherDone(obj,time)
            check = false;

            if rand() < airtaxi.funcs.pCDF(obj.duration,obj.parent.avg_duration)
                check = true;
            end
        end
        
        function vis = getVisibility(obj,loc1,loc2)
            % returns visibility as a percentage, 1.0 = 100% visible
            dist_in_weather = obj.getDistInWeather(loc1,loc2);
            vis = exp(-obj.density*dist_in_weather);            
        end
        
        function d = getDistInWeather(obj,loc1,loc2)
            if loc1 == loc2
                d = 0;
                return;
            end
            [m,b] = airtaxi.funcs.slopeInterceptFromPoints(loc1,loc2);            
            [p1,p2] = airtaxi.funcs.lineCircleIntersection(m,b,obj.location,obj.radius);
            
            % use point in same direction of loc2
            if sign(p1(1)-loc1(1)) == sign(loc2(1)-loc1(1))
                % distance = min(dist to weather edge, dist to other acft)
                d = min(airtaxi.funcs.calc_dist(loc1,p1),airtaxi.funcs.calc_dist(loc1,loc2));
            else
                d = min(airtaxi.funcs.calc_dist(loc1,p2),airtaxi.funcs.calc_dist(loc1,loc2));
            end
        end
        
        function r = getRadius(obj)
            r = obj.radius;
        end
        
        function v = getPosition(obj)
            v = obj.location;
        end
        
        function v = getVelocity(obj)
            v=[0,0,0];
        end
        
        function a = getAcceleration(obj)
            a = [0,0,0];
        end
        
        function plotWeather(obj,alpha)
            % TODO:  Plot Weather ???
            pos = [obj.location-obj.radius 2*obj.radius 2*obj.radius];
            c = [0 0 1 alpha];
            obj.plotter = rectangle('Position',pos,'Curvature',[1 1], ...
                'FaceColor',c,'EdgeColor',c);
        end
        
        function deletePlot(obj)
            delete(obj.plotter);
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
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests TODO Make gooder
            tests = {};
            %tests{1} = 'publicsim.tests.agents.base.MovableTest.test_Movable';
        end
    end
end

