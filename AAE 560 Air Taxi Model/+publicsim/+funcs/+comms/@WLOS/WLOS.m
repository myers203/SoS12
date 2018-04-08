classdef WLOS < publicsim.funcs.comms.PointToPoint
    %WLOS Wireless Line of Site network
    
    properties (SetAccess = private)
        distLimit = 650e3;
        latencyBase = 0.1;
        latencyMult = 2.2 - 0.1;
        world;
        
        obstructionTolerance = 1e-6; % m
    end
    
    methods
        function obj = WLOS(bandwidth, world)
            latency = inf;  % Temporary, will update once the link is set up
            obj@publicsim.funcs.comms.PointToPoint(bandwidth, latency);
            if nargin < 2
                obj.world = publicsim.util.Earth();
                obj.world.setModel('elliptical');
            else
                obj.world = world;
            end
        end
        
        function init(obj)
            % First, check if either switch is part of a movable
            if isa(obj.inputSwitch.parent.parent, 'publicsim.agents.base.Movable') || ...
                    isa(obj.outputSwitch.parent.parent, 'publicsim.agents.base.Movable')
                obj.setLatency(@obj.calcLatency);
            else
                obj.setLatency(obj.calcLatency());
            end
        end
        
        function l = calcLatency(obj)
            %TODO: May need to handle positional stuff better
            %             if isa(obj.outputSwitch.parent.parent, 'publicsim.agents.hierarchical.Child')
            %                 p1 = obj.outputSwitch.parent.parent.getNestedProperty('getPosition');
            %             else
            p1 = obj.outputSwitch.parent.parent.getPosition();
            %             end
            
            %             if isa(obj.inputSwitch.parent.parent, 'publicsim.agents.hierarchical.Child')
            %                 p2 = obj.inputSwitch.parent.parent.getNestedProperty('getPosition');
            %             else
            p2 = obj.inputSwitch.parent.parent.getPosition();
            %             end
            
            if obj.isInSight(p1, p2)
                dist = norm(p1 - p2);
                l = obj.latencyBase + (dist / obj.distLimit) * obj.latencyMult;
            else
                l = inf;
            end
        end
        
        function setWorld(obj, world)
            obj.world = world;
        end
        
        function setOutputSwitch(obj,outputSwitch)
            setOutputSwitch@publicsim.funcs.comms.PointToPoint(obj, outputSwitch);
            if obj.isComplete();
                obj.init();
            end
        end
        
        function setInputSwitch(obj,inputSwitch)
            setInputSwitch@publicsim.funcs.comms.PointToPoint(obj, inputSwitch);
            if obj.isComplete();
                obj.init();
            end
        end
        
        function setIsMoving(obj, isMoving)
            obj.isMoving = isMoving;
        end
        
    end
    
    methods (Access = private)
        function bool = isComplete(obj)
            bool = ~isempty(obj.inputSwitch) && ...
                ~isempty(obj.outputSwitch);
        end
        
        function bool = isInSight(obj, p1, p2)
            % Returns if there is line of sight between the points
            % Calculate the formula of the line between the two points as:
            % [x, y, z] = [x0, y0, z0] + t * [cx, cy, cz]
            % Let p(t = 0) = p1, p(t = 1) = p2
            c = (p2 - p1); % Finds the slope of the line
            % Parse for easier readability
            u = c(1);
            v = c(2);
            w = c(3);
            x = p1(1);
            y = p1(2);
            z = p1(3);
            
            % Ellipsoid of earth plus the atmosphere
            a = obj.world.getRadius;
            b = obj.world.getPolarRadius;
            
            % Calculate the intersection point(s), if any, with the earth
            % ellipsoid
            
            t_intersection(1) = -(1/(b^2 * (u^2 + v^2) +  a^2 * w^2)) ...
                * (b^2 * (u * x + v * y) + a^2 * w * z + ...
                1/2 * sqrt(4 * (b^2 * (u * x + v * y) + a^2 * w * z)^2 - ...
                4*(b^2 * (u^2 + v^2) + a^2 * w^2) * ...
                (b^2 * (-a^2 + x^2 + y^2) + a^2 * z^2)));
            
            % If the line never even intersects the atmosphere, then the
            % atmospheric distance will always be zero
            if imag(t_intersection(1)) ~= 0
                bool = 1;
            else
                % At least some throught the world
                t_intersection(2) = -(1/(b^2 * (u^2 + v^2) +  a^2 * w^2)) ...
                    * (b^2 * (u * x + v * y) + a^2 * w * z - ...
                    1/2 * sqrt(4 * (b^2 * (u * x + v * y) + a^2 * w * z)^2 - ...
                    4*(b^2 * (u^2 + v^2) + a^2 * w^2) * ...
                    (b^2 * (-a^2 + x^2 + y^2) + a^2 * z^2)));
                
                % Next, need limit the possible distance to that between p1 and
                % p2, which translates to between 0 <= t =< 1
                
                for i = 1:numel(t_intersection)
                    if t_intersection(i) > 1
                        t_intersection(i) = 1;
                    elseif t_intersection(i) < 0
                        t_intersection(i) = 0;
                    end
                end
                
                % Now solve for the intersection points and get the distance
                p1_atmosphere = p1 + t_intersection(1) * c;
                p2_atmosphere = p1 + t_intersection(2) * c;
                dist = norm(p1_atmosphere - p2_atmosphere);
                if dist < obj.obstructionTolerance
                    bool = 1;
                else
                    bool = 0;
                end
            end
        end
    end
    
end

