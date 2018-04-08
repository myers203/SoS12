classdef Impactable < publicsim.analysis.CoordinatedAnalyzer
    
    properties
        logger
        allImpactableData=struct('agentId',[],...
            'classTypes',[],...
            'movableId',[],...
            'didImpact',[],...
            'impactTime',[],...
            'impactEcef',[]);
    end
    
    methods
        
        function obj=Impactable(logger, coordinator)
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
            allImpactableAgents=publicsim.sim.Loggable.getAgentsByClass(obj.logger,'publicsim.agents.physical.Impactable');
            obj.allImpactableData.agentId=[allImpactableAgents.id];
            obj.allImpactableData.movableId=NaN*ones(numel(allImpactableAgents),1);
            obj.allImpactableData.didImpact=zeros(numel(allImpactableAgents),1);
            obj.allImpactableData.impactTime=inf*ones(numel(allImpactableAgents),1);
            obj.allImpactableData.impactEcef=NaN*ones(numel(allImpactableAgents),3);
            for i=1:numel(allImpactableAgents)
                if isprop(allImpactableAgents(i).value,'movableId') && ~isempty(allImpactableAgents(i).value.movableId)
                    obj.allImpactableData.movableId(i)=allImpactableAgents(i).value.movableId;
                end
                obj.allImpactableData.classTypes{i}=[{class(allImpactableAgents(i).value)}; superclasses(allImpactableAgents(i).value)];
                obj.allImpactableData.displayName{i}=allImpactableAgents(i).value.commonName;
            end
            
            impactableData=publicsim.sim.Loggable.readParamsByClass(obj.logger,'publicsim.agents.physical.Impactable',{'impacted','impactECEF'});
            
            impactedIds=[impactableData.impacted.id];
            didImpact=[impactableData.impacted.value];
            impactTimes=[impactableData.impacted.time];
            for i=1:numel(impactedIds)
                obj.allImpactableData.didImpact(impactedIds(i)==obj.allImpactableData.agentId)=...
                    didImpact(i);
                obj.allImpactableData.impactTime(impactedIds(i)==obj.allImpactableData.agentId)=...
                    impactTimes(i);
            end
            
            impactedIds=[impactableData.impactECEF.id];
            impactEcefs={impactableData.impactECEF.value}';
            for i=1:numel(impactedIds)
                obj.allImpactableData.impactEcef(impactedIds(i)==obj.allImpactableData.agentId,:)=...
                    impactEcefs{i};
            end
            
        end
        
    end
    
end

