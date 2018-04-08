classdef Sensing < publicsim.analysis.CoordinatedAnalyzer
    %SENSING Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=protected)
        logger
        allObservations;
    end
    
    methods
        
        function obj=Sensing(logger, coordinator)
            if ~exist('coordinator', 'var')
                coordinator = publicsim.analysis.Coordinator();
            end
            obj@publicsim.analysis.CoordinatedAnalyzer(coordinator);
            obj.logger=logger;
            obj.getAllObservations();
        end
        
        function plotObservations(obj)
            allPositions=obj.allObservations.measurements;
            [~,~,ic]=unique(obj.allObservations.ids);
            allIds=ic;
            
            figure;
            scatter3(allPositions(:,1),allPositions(:,2),allPositions(:,3),[],allIds);
            title('All Observations');
        end
        
        function output=getObservationsBySensor(obj)
            
            [output, bool, memoizeKey] = obj.getMemoize();
            if bool
                return;
            end
            
            sensorIds=unique(obj.allObservations.sensorId);
            sensorProps=obj.getSensorProperties();
            for i=1:numel(sensorIds)
                output(i).sensorId=sensorIds(i); %#ok<AGROW>
                output(i).sensorObj=sensorProps(sensorIds(i)==[sensorProps.id]).sensorObj; %#ok<AGROW>
                idxSet=1:numel(obj.allObservations.ids);
                idxSet=idxSet(obj.allObservations.sensorId==sensorIds(i));
                output(i).measurements=obj.allObservations.measurements(idxSet,:); %#ok<AGROW>
                output(i).ids=obj.allObservations.ids(idxSet); %#ok<AGROW>
                output(i).time=obj.allObservations.time(idxSet); %#ok<AGROW>
                output(i).sensorPosition=obj.allObservations.sensorPosition(idxSet,:); %#ok<AGROW>
                output(i).lookDirections = obj.allObservations.lookDirection(idxSet,:); %#ok<AGROW>
                output(i).errors = obj.allObservations.errors(idxSet,:); %#ok<AGROW>
                output(i).errors_AZELR = obj.allObservations.errors_AZELR(idxSet,:); %#ok<AGROW>
            end
            
            obj.memoize(output, memoizeKey);
        end
        
        function output=getObservationsByObservableId(obj)
            [output, bool, memoizeKey] = obj.getMemoize();
            if bool
                return;
            end
            
            observableIds=unique(obj.allObservations.ids);
            for i=1:numel(observableIds)
                observableId=observableIds(i);
                obsIdxi=obj.allObservations.ids==observableId;
                output(i).observableId=observableId; %#ok<AGROW>
                output(i).time=obj.allObservations.time(obsIdxi==1); %#ok<AGROW>
                output(i).sensorId=obj.allObservations.sensorId(obsIdxi==1); %#ok<AGROW>
                output(i).measurements=obj.allObservations.measurements(obsIdxi==1,:); %#ok<AGROW>
            end
            
            obj.memoize(output, memoizeKey);
        end
        
         function properties=getSensorProperties(obj)
             
             [properties, bool, memoizeKey] = obj.getMemoize();
             if bool
                 return;
             end
             
            sensorProperties=publicsim.sim.Loggable.getAgentsByClass(obj.logger,'publicsim.agents.functional.Sensing');
            for i=1:numel(sensorProperties)
                properties(i).id=sensorProperties(i).id; %#ok<AGROW>
                sensorObj=sensorProperties(i).value.sensor;
                properties(i).sensorObj=sensorObj; %#ok<AGROW>
                properties(i).sensorName=sensorProperties(i).value.commonName; %#ok<AGROW>
            end
            
            obj.memoize(properties, memoizeKey);
        end
        
    end
    
    methods(Access=private)
        
        function getAllObservations(obj)
            sensingData=publicsim.sim.Loggable.readParamsByClass(obj.logger,'publicsim.agents.functional.Sensing',{publicsim.agents.functional.Sensing.OBSERVATION_LOGGING_KEY});
            if isempty(sensingData.(publicsim.agents.functional.Sensing.OBSERVATION_LOGGING_KEY))
                warning('No sensor data loaded!');
                return;
            end
            allObservationRaw=[sensingData.(publicsim.agents.functional.Sensing.OBSERVATION_LOGGING_KEY).value];
            obj.allObservations=publicsim.agents.functional.Sensing.OBSERVATION_MESSAGE;
            obj.allObservations.lookDirection=[];
            obj.allObservations.errors_AZELR=[];
            for i=1:numel(allObservationRaw)
                if ~iscell(allObservationRaw(i).ids)
                    allObservationRaw(i).ids={allObservationRaw(i).ids};
                    allObservationRaw(i).measurements={allObservationRaw(i).measurements};
                    allObservationRaw(i).errors={allObservationRaw(i).errors};
%                     allObservationRaw(i).r_velocity_observations={allObservationRaw(i).r_velocity_observations};
%                     allObservationRaw(i).r_velocity_errors={allObservationRaw(i).r_velocity_errors};
                end
            end
            
            rmIdx=[];
            for i=1:numel(allObservationRaw)
                if any(isempty(cell2mat(allObservationRaw(i).ids)))
                    rmIdx(end+1)=i; %#ok<AGROW>
                end
            end
            allObservationRaw(rmIdx)=[];
            
            for i=1:numel(allObservationRaw)
                
                measurements=(allObservationRaw(i).measurements{1}.ECEF);
                if size(measurements,2) < 4
                    measurements(:,4)=NaN;
                end
                obj.allObservations.measurements=[obj.allObservations.measurements; measurements];
                
                errors=(allObservationRaw(i).errors{1}.ECEF);
                if size(errors,2) < 4
                    errors(:,4)=NaN;
                end
                obj.allObservations.errors=[obj.allObservations.errors; errors];
                
                errors=(allObservationRaw(i).errors{1}.AZELR);
                if size(errors,2) < 4
                    errors(:,4)=NaN;
                end
                obj.allObservations.errors_AZELR=[obj.allObservations.errors_AZELR; errors];
                
                ids=cell2mat(allObservationRaw(i).ids);
                obj.allObservations.ids=[obj.allObservations.ids; ids];
                
                sensorIds=allObservationRaw(i).sensorId*ones(numel(ids),1);
                obj.allObservations.sensorId=[obj.allObservations.sensorId; sensorIds];
                
                sensorPositions=repmat(allObservationRaw(i).sensorPosition,numel(ids),1);
                obj.allObservations.sensorPosition=[obj.allObservations.sensorPosition; sensorPositions];
                
                lookDirection = repmat(allObservationRaw(i).lookDirection,numel(ids),1);
                obj.allObservations.lookDirection = [obj.allObservations.lookDirection; lookDirection];
                
                
                times=allObservationRaw(i).time*ones(numel(ids),1);
                obj.allObservations.time=[obj.allObservations.time; times];
                
                
                
%                 r_velocity_observations=cell2mat(allObservationRaw(i).r_velocity_observations);
%                 obj.allObservations.r_velocity_observations=[obj.allObservations.r_velocity_observations; r_velocity_observations];
%                 
%                 r_velocity_errors=cell2mat(allObservationRaw(i).r_velocity_errors);
%                 obj.allObservations.r_velocity_errors=[obj.allObservations.r_velocity_errors; r_velocity_errors];
            end
            
        end
        
       
        
    end
    
end

