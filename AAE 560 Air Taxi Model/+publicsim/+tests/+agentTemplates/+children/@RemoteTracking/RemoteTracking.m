classdef RemoteTracking < publicsim.agents.functional.Tracking  & publicsim.agents.hierarchical.Child
    
    properties
        configTrackingType='publicsim.funcs.trackers.BasicKalman(6)';
    end
    
    methods
        function obj=RemoteTracking()
        end
        
        function init(obj)
            obj.trackingEnableRemoteSensing();
            obj.setTaskingGroupId(obj.groupId);
            obj.setTrackMessageKeys([],obj.groupId);
            obj.enableTasking(obj.configTrackingType);
        end
    end
    
end