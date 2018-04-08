classdef ObjectManager < handle
    %OBJECTMANAGER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        topicGroup
        lastRunTime;
        nextObjId=1;
    end
    
    properties(Constant)
        sensorGroup='sensors';
        objectGroup='observables';
    end
    
    methods
        
        function obj=ObjectManager(time)
            obj.lastRunTime=time;
            obj.topicGroup=publicsim.funcs.groups.TopicGroup();
        end
        
        function observables=getObservables(obj,time)
            obj.updateAllObservables(time);
            observables=obj.topicGroup.getChildObjects(obj.objectGroup);
        end
        
        function updateAllObservables(obj,time)
            if obj.lastRunTime>=time
                return;
            end
            obj.lastRunTime=time;
            objects=obj.topicGroup.getChildObjects(obj.objectGroup);
            for i=1:length(objects) %TODO: Remove destroyed observables
                if isa(objects{i}, 'publicsim.agents.physical.Destroyable')
                    if objects{i}.isDestroyed
                        obj.topicGroup.removeFromTopic([obj.objectGroup '/' num2str(objects{i}.movableId)], objects{i});
                        continue;
                    end
                end
                object=objects{i};
                object.updateMovement(time);
            end
        end
        
        function addObservable(obj,observable)
            observable.setMovableId(obj.nextObjId);
            obj.nextObjId=obj.nextObjId+1;
            obj.topicGroup.appendToTopic([obj.objectGroup '/' num2str(observable.movableId)],observable);
        end
        
        
    end
    
end

