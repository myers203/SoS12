classdef Oracle < handle
    %ORACLE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        simInst
    end
    
    methods
        function obj=Oracle(simInst)
            obj.simInst=simInst;
        end
        
        function callee=getCalleeById(obj,id)
            calleeList=obj.simInst.getAllCallees();
            for i=1:numel(calleeList)
                callee=calleeList{i};
                if callee.id==id
                    return;
                end
            end
        end
        
        function callees=getCalleesByClass(obj,class)
            callees={};
            calleeList=obj.simInst.getAllCallees();
            for i=1:numel(calleeList)
                callee=calleeList{i};
                if isa(callee,class)
                    callees{end+1}=callee; %#ok<AGROW>
                end
            end
        end
    end
    
end

