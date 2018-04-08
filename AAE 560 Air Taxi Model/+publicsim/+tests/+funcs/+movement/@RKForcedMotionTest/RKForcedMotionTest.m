classdef RKForcedMotionTest < publicsim.agents.base.Movable
    %FORCEDMOTIONTEST Tester class for forced motion movement manager
    
    properties
        mass
        massTime
        
        thrust
        thrustTime
        
        time
        
        dragCoef = 0;
    end
    
    methods
        
        function obj = RKForcedMotionTest()
            movable = publicsim.funcs.movement.RKForcedMotion(obj, {'getThrust', 'getDrag'}, 1);
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

