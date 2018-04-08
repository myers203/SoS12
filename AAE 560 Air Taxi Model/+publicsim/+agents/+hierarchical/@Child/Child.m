classdef Child < publicsim.agents.base.Networked
    %CHILD Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private,Transient)
        parent
    end
    
    properties(SetAccess=protected)
        groupId
    end
    
    methods
        
        function obj=Child()
        end
        
        function setParent(obj,parent)
            obj.parent=parent;
            if isprop(parent, 'parentGroupId') && ~isempty(parent.parentGroupId)
                obj.groupId=parent.parentGroupId;
            else
                obj.groupId=parent.id;
            end
        end
        
        function propertyValue=getNestedProperty(obj,propertyName)
            keyboard
            if isempty(obj.parent)
                warning('Parentless child seeking parent''s property');
                propertyValue=[];
                return;
            end
            if isprop(obj.parent,propertyName) || ismethod(obj.parent,propertyName)
                if isa(obj.parent,'publicsim.agents.hierarchial.Child')
                    propertyValue=obj.parent.getNestedProperty(propertyName);
                else
                    propertyValue=obj.parent.(propertyName);
                end
            else
                propertyValue=obj.(propertyName);
            end
        end
        
        function peers=getPeersOfType(obj,type)
            peers=obj.parent.getChildrenOfType(type);
        end
        
        function setGroupId(obj,groupId)
            obj.groupId=groupId;
            if isa(obj,'publicsim.agents.hierarchical.Parent')
                setGroupId@publicsim.agents.hierarchical.Parent(groupId);
            end
        end
        
    end
    
end

