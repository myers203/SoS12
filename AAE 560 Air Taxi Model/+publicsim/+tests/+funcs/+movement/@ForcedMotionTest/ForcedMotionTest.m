classdef ForcedMotionTest < publicsim.agents.base.Movable
    %FORCEDMOTIONTEST Tester class for forced motion movement manager
    
    properties
        mass
        massTime
        
        thrust
        thrustTime
        
        time
        
        dragCoef;
    end
    
    methods
        
        function obj = ForcedMotionTest()
            movable = publicsim.funcs.movement.ForcedMotion(obj, {'getThrust'}, 1);
            obj.setMovementManager(movable);
        end
        
        function t = getThrust(obj, time)
            t = interp1(obj.thrustTime, obj.thrust, time);
        end
        
        function drag = getDrag(obj, time)
            drag = obj.dragCoef  * norm(obj.spatial.velocity);
        end
        
        function m = getMass(obj, time)
            m = interp1(obj.massTime, obj.mass, time);
        end
        
        function setTime(obj, val)
            obj.time = val;
        end
        
        function t = getCurrentTime(obj)
            t = obj.time;
        end
        
        function runAtTime(obj, time)
            % nothing here
        end
        
    end
    
end

