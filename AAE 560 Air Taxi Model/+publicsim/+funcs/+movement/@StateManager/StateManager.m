classdef StateManager < publicsim.tests.UniversalTester
    properties (SetAccess = private)
    end
    
    methods
        function obj = StateManager()
        end
    end
    
    methods
        function [newState,oldState] = updateLocation(obj,spatial,timeDiff) %#ok<INUSD>
            % This function is made to be overloaded
            % [newState,oldState] = obj.movementManager.updateLocation(obj.spatial,timeDiff)
            % This function is made to be overloaded.
            newState = spatial;
            oldState = spatial;
        end
    end
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.funcs.movement.StateManager.test_StateManager()';
        end
    end
    
    methods (Static)
        function test_StateManager()
            % Tester for StateManager
            
            % Really nothing much to test here. Just make sure that
            % updateLocation executes and returns the input spatial in both
            % new and old state with the same format
            stateManager = publicsim.funcs.movement.StateManager();
            spatial.position = randi([0, 10], 1, 3);
            spatial.velocity = randi([0, 20], 1, 3);
            spatial.acceleration = randi([0, 30], 1, 3);
            [newState, oldState] = stateManager.updateLocation(spatial, rand() * 20);
            
            allFields = fields(newState);
            % Assert field values are the same
            for i = 1:numel(allFields)
                assert(all(newState.(allFields{i}) == oldState.(allFields{i})), 'Returned states are different');
                assert(all(newState.(allFields{i}) == spatial.(allFields{i})), 'Returned state does not match input state');
            end
        end
    end
end

