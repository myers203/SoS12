classdef MovableTest < publicsim.sim.Callee & publicsim.agents.base.Movable
    %MOVABLE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        updatePeriod=1;
        positionLog={};
    end
    
    methods
        function obj=MovableTest(time,position,velocity,acceleration)
            movable=publicsim.funcs.movement.NewtonMotion();
            obj.setMovementManager(movable);
            obj.setInitialState(time,{'position',position,'velocity',velocity,'acceleration',acceleration});
        end
        
        function init(obj)
            obj.scheduleAtTime(obj.movementLastUpdateTime);
        end
        
        function runAtTime(obj,time)
            obj.scheduleAtTime(time+obj.updatePeriod);
            obj.updateMovement(time);
            obj.positionLog{end+1}=obj.getPosition();
        end
    end
    
    %%%% TEST METHODS %%%%%
    
    methods(Static)
        
        function test_Movable()
            import publicsim.*;
            tsim=sim.Instance('./tmp');
            mt{1}=tests.agents.base.MovableTest(0,[100 100 100],[10 10 10],[0 0 0]);
            mt{2}=tests.agents.base.MovableTest(0,[50 50 50],[5 5 5],[1 1 1]);
            for i=1:numel(mt)
                tsim.AddCallee(mt{i});
            end
            tsim.runUntil(0,100);
            assert(isequal(mt{1}.positionLog{end},[1100 1100 1100]),'Position Movement Failure!');
            assert(isequal(mt{2}.positionLog{end},[5550 5550 5550]),'Position Movement Failure!');
        end
        
    end
    
end

