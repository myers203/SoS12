classdef GenericScheduler < handle
    %GenericScheduler Contains default methods and properties for function
    %classes of type "scheduler"
    
    properties
        num_events = []; % number of events in the schedule
    end
    
    methods
        function obj = GenericScheduler()
        end
        
        function schedule = getSchedule(obj,weights) %#ok<INUSD>
            schedule = [];
        end
        
        function next_to_execute = getNext(obj) %#ok<MANU>
            next_to_execute = [];
        end
        
                
        function setNumEvents(obj,num_events)
            obj.num_events = num_events;
        end
    end
end

