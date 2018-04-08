classdef Destroyable < publicsim.analysis.CoordinatedAnalyzer
    
    properties
        logger
        allDestroyableData=struct('agentId',[],...
            'classTypes',[],...
            'movableId',[],...
            'didDestroy',[],...
            'destroyTime',[])
    end
    
    methods
        
        function obj=Destroyable(logger, coordinator)
            if ~exist('coordinator', 'var')
                coordinator = publicsim.analysis.Coordinator();
            end
            obj@publicsim.analysis.CoordinatedAnalyzer(coordinator);
            obj.logger=logger;
            obj.loadAllData();
        end
        
    end
    
    methods(Access=private)
        
        function loadAllData(obj)
            allDestroyableAgents=publicsim.sim.Loggable.getAgentsByClass(obj.logger,'publicsim.agents.physical.Destroyable');
            obj.allDestroyableData.agentId=[allDestroyableAgents.id];
            obj.allDestroyableData.movableId=NaN*ones(numel(allDestroyableAgents),1);
            obj.allDestroyableData.didDestroy=zeros(numel(allDestroyableAgents),1);
            obj.allDestroyableData.destroyTime=inf*ones(numel(allDestroyableAgents),1);
            for i=1:numel(allDestroyableAgents)
                if isprop(allDestroyableAgents(i).value,'movableId') && ~isempty(allDestroyableAgents(i).value.movableId)
                    obj.allDestroyableData.movableId(i)=allDestroyableAgents(i).value.movableId;
                end
                obj.allDestroyableData.classTypes{i}=[{class(allDestroyableAgents(i).value)}; superclasses(allDestroyableAgents(i).value)];
                obj.allDestroyableData.displayName{i}=allDestroyableAgents(i).value.commonName;
            end
            
            destroyableData=publicsim.sim.Loggable.readParamsByClass(obj.logger,'publicsim.agents.physical.Destroyable',{'isDestroyed'});
            
            destroyableIds=[destroyableData.isDestroyed.id];
            didDestroy=[destroyableData.isDestroyed.value];
            destroyTimes=[destroyableData.isDestroyed.time];
            for i=1:numel(destroyableIds)
                obj.allDestroyableData.didDestroy(destroyableIds(i)==obj.allDestroyableData.agentId)=...
                    didDestroy(i);
                obj.allDestroyableData.destroyTime(destroyableIds(i)==obj.allDestroyableData.agentId)=...
                    destroyTimes(i);
            end
            
            
        end
        
    end
    
end

