classdef TrackAggregator < handle
    %AGGREGATOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        DBMap
    end
    
    methods
        
        function obj=TrackAggregator()
            obj.DBMap=containers.Map('KeyType','char','ValueType','any');
        end
        
        function trackIdList=getAllTrackIDs(obj)
            trackIdList=[];
            dbList=values(obj.DBMap);
            for i=1:numel(dbList)
                trackDB=dbList{i};
                trackIdList=[trackIdList cell2mat(keys(trackDB.map))]; %#ok<AGROW>
            end
            trackIdList=unique(trackIdList);
        end
        
        
        function [track,error]=findBestTrack(obj,trackId,time)
            trackList={};
            dbList=values(obj.DBMap);
            for i=1:numel(dbList)
                trackDB=dbList{i};
                if isKey(trackDB.map,trackId)
                    trackList{end+1}=trackDB.map(trackId); %#ok<AGROW>
                end
            end
            
            if numel(trackList) == 0
                track=[];
                error=[];
                return;
            end
            
            filterErrors=zeros(numel(trackList),1);
            for i=1:numel(trackList)
                filterObj=trackList{i};
                filterErrors(i)=filterObj.getPositionErrorAtTime(time);
            end
            
            [error,idx]=min(filterErrors);
            track=trackList{idx};
        end
        
    end
    
end

