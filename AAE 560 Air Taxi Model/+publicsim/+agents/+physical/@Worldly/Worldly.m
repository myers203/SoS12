classdef Worldly < publicsim.agents.base.Locatable
    %WORLDLY Agent type who has knowledge of the world
    
    properties
        world; % The known world
    end
    
    methods
        function g = getGravity(obj, varargin)
            % Calculate gravitational force vector in ECEF at current location
            if (nargin == 0)
                time = obj.getCurrentTime();
            else
                if ~isempty(varargin)
                    time = varargin{1};
                else
                    time = obj.getCurrentTime();
                end
            end
            
            loc = obj.spatial.position;
            gUnitVector = -loc / norm(loc);
            mu = obj.world.getGravParam();
            r = norm(loc);
            g = gUnitVector * (mu / (r^2)) * obj.getMass(time);
        end
        
        function setWorld(obj,world)
            obj.world=world;
        end
    end    
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.tests.agents.physical.WorldlyTest.test_Worldly';
        end
    end
    
end

