classdef CovarianceMinimizer < publicsim.funcs.assessors.Assessor
    %COVARIANCEMINIMIZER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        trackMap
    end
    
    methods
        
        function obj=CovarianceMinimizer()
            obj.trackMap=containers.Map('KeyType','int64','ValueType','any');
        end
        
        function updateAssessorData(obj,~,ids,inputDatas)
            assert(isfield(inputDatas,'serializedTracks'),'Incompatible input data type');
            assert(isfield(inputDatas,'trackTypes'),'Incompatible input data type');
            serializedTracks=inputDatas.serializedTracks;
            trackTypes=inputDatas.trackTypes;
            if iscell(ids)
                ids=cell2mat(ids);
            end
            
            for i=1:numel(serializedTracks)
                serializedTrack=serializedTracks{i}; %#ok<NASGU>
                trackType=trackTypes{i};
                track=eval([trackType '.deserializeWithType(serializedTrack,trackType)']);
                
                id=ids(i);
                assert(isa(track,'publicsim.funcs.trackers.Tracker'),...
                    'CovMin only supports track objects as input datas');
                obj.trackMap(id)=track;
            end
            
        end
        
        function [ids,priorities,otherData]=getPriorities(obj,time)
            ids=cell2mat(keys(obj.trackMap));
            covErrors=zeros(numel(ids),1);
            serializedTracks=cell(numel(ids),1);
            trackTypes=cell(numel(ids),1);
            for i=1:numel(ids)
                id=ids(i);
                track=obj.trackMap(id);
                covErrors(i)=track.getPositionErrorAtTime(time);
                serializedTracks{i}=track.serialize();
                trackTypes{i}=class(track);
            end
            otherData.trackTypes=trackTypes;
            otherData.serializedTracks=serializedTracks;
            covErrors=log(covErrors);
            covErrors=covErrors-min(covErrors);
            priorities=covErrors+1;
        end
    end
    
end

