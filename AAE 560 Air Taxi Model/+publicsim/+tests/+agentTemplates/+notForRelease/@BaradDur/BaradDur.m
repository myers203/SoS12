classdef BaradDur < publicsim.agents.functional.Sensing & publicsim.agents.functional.Tracking
    
    properties
        sensorType='publicsim.tests.agentTemplates.notForRelease.EyeOfSauron';
    end
    
    properties(SetAccess=private)
        
    end
    
    methods
        
        function obj = BaradDur()
            % nothing?
        end
        
        function init(obj)
            obj.enableSensing(obj.sensorType);
            obj.enableTracking('publicsim.funcs.trackers.BasicKalman');
            obj.setTrackMessageKeys([],obj.upstreamNetworkIds(1));
        end
        
        function setGroupId(obj,id)
            obj.setObservationTopicGroup(id);
            obj.setTrackObservationGroupId(id);
        end
        
    end
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()            
            tests = {}; 
        end
    end
    
end

