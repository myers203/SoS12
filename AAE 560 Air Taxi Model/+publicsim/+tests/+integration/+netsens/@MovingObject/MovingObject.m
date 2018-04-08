classdef MovingObject < publicsim.agents.base.Movable
    %MOVINGOBJECT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        
        function obj=MovingObject(time,position,velocity,acceleration)
            n_dims=3;
            movable=publicsim.funcs.movement.NewtonMotion(n_dims);
            obj.setMovementManager(movable);
            obj.setInitialState(time,{'position',position,'velocity',velocity,'acceleration',acceleration});
        end
        
        function runAtTime(obj,time) %#ok<INUSD>
            %Callee so must have this
        end
        
        
    end
    
end

