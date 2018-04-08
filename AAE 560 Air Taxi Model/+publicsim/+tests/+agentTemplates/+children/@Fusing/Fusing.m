classdef Fusing < publicsim.agents.functional.Fusing  & publicsim.agents.hierarchical.Child
    
    properties
        configFuserType=publicsim.agents.functional.Fusing.FUSER_TYPE_TRACK;
        configFuserAglorithm=publicsim.agents.functional.Fusing.FUSER_ALGORITHM_TRACK;
    end
    
    methods
        
        function obj=Fusing()
            
        end
        
        function init(obj)
            obj.addFusingSourceId(obj.groupId); 
            obj.enableFusing(obj.configFuserType,obj.configFuserAglorithm);
        end
    end
    
end

