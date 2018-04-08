classdef WeightedRoundRobin < publicsim.funcs.schedulers.GenericScheduler
    %WeightedRoundRobin For the weighted round robin scheduling scheme.
    
    properties (SetAccess=protected)
        current_weights = []
        object_names = {}
    end
    
    methods
        function obj = WeightedRoundRobin()
            
        end
        
        function setWeights(obj,weights,names)
            assert(isnumeric(weights));
            assert(numel(weights)==numel(names));
            
            obj.current_weights = weights;
            obj.object_names = names;
        end
        
        function [schedule,scheduled_names] = scheduleEvents(obj)
            schedule = publicsim.funcs.schedulers.WeightedRoundRobin.getSchedule(obj.current_weights);
            scheduled_names = obj.object_names(schedule);
        end
        
    end
    
    methods (Static)
        function schedule = getSchedule(weights,scheduleLength)
            current_weight = 0;
            weights = weights/publicsim.funcs.schedulers.WeightedRoundRobin.gcd(weights); % so the schedule doesn't get too long.
            
            if nargin<2
                scheduleLength = sum(ceil(weights));
            end
            
            i = -1;
            schedule = [];
            ctr = 0;
            while numel(schedule) < scheduleLength
                i = mod(i+1, numel(weights));
                
                if i == 0
                    current_weight = current_weight - publicsim.funcs.schedulers.WeightedRoundRobin.gcd(weights);
                    if current_weight <=0
                        current_weight = max(weights);
                        if current_weight == 0
                            return
                        end
                    end
                end
                
                if weights(i+1) >= current_weight
                    schedule(end+1) = i+1;  %#ok<AGROW>
                end
                ctr = ctr+1;
            end
        end
        
        function greatest_common_divisor=gcd(weights)
            i = 1;
            result = weights(i);
            while i < numel(weights)
                i = i+1;
                result = publicsim.funcs.schedulers.WeightedRoundRobin.pairwiseGCD(result,weights(i));
            end
            greatest_common_divisor = result;
        end
        
        function result = pairwiseGCD(num1,num2)
            if num2 == 0
                result = num1;
            else
                result = publicsim.funcs.schedulers.WeightedRoundRobin.pairwiseGCD(num2,mod(num1,num2));
            end
        end
    end
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            import publicsim.tests.UniversalTester.*
            tests{1} = 'publicsim.funcs.schedulers.WeightedRoundRobin.test_weightedRoundRobin';
        end
    end
    
    methods (Static)
        function test_weightedRoundRobin()
            schedule = publicsim.funcs.schedulers.WeightedRoundRobin.getSchedule([4,3,2]);
            assert(all(schedule==[1 1 2 1 2 3 1 2 3]));
            
            a = publicsim.funcs.schedulers.WeightedRoundRobin();
            a.setWeights([4,3,2],{'A','B','C'});
            [b,c]=a.scheduleEvents(); %#ok<ASGLU>
            
            disp('Passed WeightedRoundRobin test!');
        end
    end
end

