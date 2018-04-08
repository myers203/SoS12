classdef DestroyableTest < publicsim.agents.physical.Destroyable & publicsim.agents.base.Periodic
    %DESTROYABLE Tester for the Destroyable agent
    
    properties
        destroyTime = [];
    end
    
    methods
        
        function obj = DestroyableTest(time, varargin)
            % Define the movable
            n_dims = 3;
            movable = publicsim.funcs.movement.NewtonMotion(n_dims);
            obj.setMovementManager(movable);
            obj.setInitialState(time, struct('position', [0,0,0], 'velocity', [1, 1, 1], 'acceleration', [1, 1, 1]))
            
            if ~isempty(varargin)
                obj.destroyTime = varargin{1};
            end
        end
        
        function init(obj)
            obj.scheduleAtTime(obj.movementLastUpdateTime); % Schedule first call update
            obj.initPeriodic(1); % Update every second
            if ~isempty(obj.destroyTime)
                obj.scheduleAtTime(obj.destroyTime);
            end
        end
        
        function runAtTime(obj, time)
            
            if (~obj.isDestroyed && obj.isRunTime(time)) % If not destroyed
                obj.updateMovement(time);
            end
            
            if (time >= obj.destroyTime)
                obj.destroy();
            end
            
        end
        
    end

    methods (Static)
        
        % Test
        function test_destroyableAgent()
            % Create the sim
            testSim = publicsim.sim.Instance('./tmp');
            
            % Create destroyables
            initTime = 0;
            initPos = 100 * rand(1, 3);
            initVel = rand(1, 3);
            initAccel = 0.1 * rand(1, 3);
            
            destroyable{1} = publicsim.tests.agents.physical.DestroyableTest(initTime);
            destroyable{2} = publicsim.tests.agents.physical.DestroyableTest(initTime, 10);
            
            % Add to the sim
            for i = 1:numel(destroyable)
                testSim.AddCallee(destroyable{i});
            end
            
            % Run
            testSim.runUntil(0, 20);
            assert(~isequal(destroyable{1}.getPosition(), destroyable{2}.getPosition()), 'Destroyable: Movement failure!');
            disp('Passed Destroyable test!');
        end
        
    end
    
        %%%% TEST METHDOS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests = {};
        end
    end
    
end

