classdef Spoke < publicsim.agents.base.Networked
    %SPOKE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(Transient)
        hub
    end
    
    methods
        
        function obj=Spoke()
        end
        
        function addHub(obj,hub)
            obj.hub=hub;
        end
        
        function spokes=getSpokesOfType(obj,type)
            spokes=obj.hub.getSpokesOfType(type);
        end
        
    end
    
end

