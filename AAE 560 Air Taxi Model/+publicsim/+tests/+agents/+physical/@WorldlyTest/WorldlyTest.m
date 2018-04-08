classdef WorldlyTest < publicsim.agents.physical.Worldly
    %WORLDLYTEST Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        
        function runAtTime(obj, time)
            % Do nothing
        end
        
        function mass = getMass(obj, varargin)
            mass = 1;
        end
        
        function time = getCurrentTime(~)
           time = 0;
        end
    end
    
    methods (Static)
        function test_Worldly()
            world = publicsim.util.Earth();
            world.setModel('elliptical');
            
            obj = publicsim.tests.agents.physical.WorldlyTest();
            obj.world = world;
            
            locationsLLA = {[0 0 0], ...
                [10 20 1e3], ...
                [5 -16 1e6], ...
                [-52 180 1e9], ...
                [-80 -53 1e12]};
                
            expectedValues = {[-9.798274618982264 0 0], ...
                [-9.068285426426970 -3.300585971049412 -1.690213192843348], ...
                [-7.012417196651188 2.010778274155443 -0.634537505397185], ...
                [0.242314724506498 0 0.310135518028055] * 1e-3, ...
                [-0.041654799206882 0.055277785583131 0.392539378769483] * 1e-9};
            
            for i = 1:numel(locationsLLA)
                obj.spatial.position = obj.world.convert_lla2ecef(locationsLLA{i});
                g = obj.getGravity();
                assert(norm(expectedValues{i} - g) < 1e-15, 'Failed to calculate gravity correctly');
            end
        end
    end
    
end

