classdef PrioritizeTracks < publicsim.funcs.priority_generators.PriorityGenerator
    %PrioritizeTracks Generate a set of track priorities based on position
    %and velocity information
    properties (SetAccess=protected)
        position_weight = 1;
        velocity_weight = 1;
        weights
        track_database = publicsim.funcs.databases.Database({'tracks'},{'char'});  % might not be double for key type later, we will see.
    end
    
    methods
        function obj = PrioritizeTracks()
            obj.weights = [obj.position_weight, obj.velocity_weight];
        end
        
        function [priorities,sorted_keys] = getPriorities(obj,weights)
            
            keys = obj.track_database.tracks.keys();
            
            priorities = nan(1,numel(keys));
            
            for i = 1:numel(keys);
                key=keys{i};
                position_value = obj.getPositionValue(key);
                velocity_value = obj.getVelocityValue(key);
                priorities(i) = weights(1)*position_value + weights(2)*velocity_value;
            end
            
            [priorities, inds] = sort(priorities,'descend');
            
            sorted_keys = keys(inds);
        end
        
        function value = getPositionValue(obj,key)
            value = publicsim.funcs.priority_generators.PrioritizeTracks.getValue(obj.track_database.tracks(key).position_array);
        end
        
        function value = getVelocityValue(obj,key)
            value = publicsim.funcs.priority_generators.PrioritizeTracks.getValue(obj.track_database.tracks(key).velocity_array);
        end
    end
    
    methods (Static)
        function value = getValue(array)
            value = det(array);
        end
    end
    
    
    %%%% TEST METHDOS %%%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.funcs.priority_generators.PrioritizeTracks.test_prioritizeTracks';
        end
    end
    
    methods (Static)
        function test_prioritizeTracks()
            template = struct('position_array',nan(3),'velocity_array',nan(3));
            a = publicsim.funcs.priority_generators.PrioritizeTracks();
            
            for i = 1:3
                current = template;
                current.position_array = rand(3);
                current.velocity_array = rand(3);
                a.track_database.updateDatabase(sprintf('track_%d',i),current);
            end
            
            [priorities,keys] = a.getPriorities(a.weights); %#ok<ASGLU>
            
            display('Passed PrioritiesTracks Test!');
        end
    end
end

