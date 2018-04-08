classdef Observables < publicsim.funcs.oracles.Oracle
    
    properties(Constant)
        SENSING_CLASS='publicsim.agents.functional.Sensing';
    end
    
    methods
        
        function obj=Observables(instance)
            obj=obj@publicsim.funcs.oracles.Oracle(instance);
        end
        
        %Assumes only a single exists
        function observableManager=getObservableObjectManager(obj)
            sensingCallees=obj.getCalleesByClass(obj.SENSING_CLASS);
            sensingCallee=sensingCallees{1};
            observableManager=sensingCallee.observableObjectManager;
        end
        
        function [spatials,movableIds,observables]=getSpatials(obj)
            time=obj.simInst.Scheduler.currentTime;
            observableManager=obj.getObservableObjectManager;
            observableManager.updateAllObservables(time);
            observables=observableManager.getObservables(time);
            movableIds=zeros(numel(observables),1);
            spatials=cell(numel(observables),1);
            for i=1:numel(observables)
                observable=observables{i};
                movableIds(i)=observable.movableId;
                spatials{i}=observable.spatial;
            end
        end
    end
    
end

