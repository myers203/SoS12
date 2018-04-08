classdef Network < publicsim.analysis.CoordinatedAnalyzer
    %NETWORK Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        logger
        allNetworkStatuses
        allLinkStatuses
    end
    
    methods
        
        function obj=Network(logger, coordinator)
            if ~exist('coordinator', 'var')
                coordinator = publicsim.analysis.Coordinator();
            end
            obj@publicsim.analysis.CoordinatedAnalyzer(coordinator);
            obj.logger=logger;
            obj.loadNetworkData();
            obj.removeChildLinks();
        end
        
        function removeChildLinks(obj)
            rmIdx=1:numel(obj.allLinkStatuses.isChildLink);
            rmIdx=rmIdx(obj.allLinkStatuses.isChildLink==1);
            fNames=fields(obj.allLinkStatuses);
            for i=1:numel(fNames)
                obj.allLinkStatuses.(fNames{i})(rmIdx)=[];
            end
        end
        
        function plotTotalNetworkLatency(obj)
            
            [allTimes,~,allTimesIdx]=unique(floor(obj.allNetworkStatuses.times));
            meanLatencies=zeros(numel(allTimes),1);
            for i=1:numel(allTimes)
                idxSet=1:numel(allTimesIdx);
                idxSet(allTimesIdx~=i)=[];
                stepLatencies=obj.allNetworkStatuses.latencies(idxSet);
                stepIds=obj.allLinkStatuses.id(idxSet);
                [stepIds,~,stepIdsIdx]=unique(stepIds);
                mergedStepLatencies=zeros(numel(stepIds,1));
                for j=1:numel(stepIds)
                    subStepLatencies=stepLatencies(stepIdsIdx==j);
                    mergedStepLatencies(j)=max(subStepLatencies);
                end
                meanLatencies(i)=mean(mergedStepLatencies);
            end
            
            figure;
            hold all;
            plot(allTimes,meanLatencies,'LineWidth',1.0);
            plot(allTimes(1:end),smooth(meanLatencies,5),'-','LineWidth',1.75);
            xlabel('Time (s)');
            ylabel('Mean Network Latency (s)');
            title('Network-Level Average Latency');
            legend('Per-Step','Smoothed');
            
        end
        
        function totalBytes = getTotalNetworkBytes(obj)
            totalBytes=sum(obj.allLinkStatuses.sentBits)/8;
        end
        
        function [totalBits,numLinks] = getLinksByClassId(obj,classId)
            
            [output, bool, memoizeKey] = obj.getMemoize(classId);
            if bool
                totalBits = output.totalBits;
                numLinks = output.numLinks;
                return;
            end
            
            idx=[];
            for i=1:numel(obj.allLinkStatuses.classId)
                if strcmpi(classId,obj.allLinkStatuses.classId(i))
                    idx=[idx i]; %#ok<AGROW>
                end
            end
            numLinks=numel(unique(obj.allLinkStatuses.id(idx)));
            totalBits=sum(obj.allLinkStatuses.sentBits(idx));
            
            output.totalBits = totalBits;
            output.numLinks = numLinks;
            obj.memoize(output, memoizeKey, classId);
        end
        
        function plotTotalLinkTraffic(obj)
            figure;
            hold all;
            allLinkIds=obj.allLinkStatuses.id;
            uniqueLinkIds=unique(allLinkIds);
            for i=1:numel(uniqueLinkIds)
                y=obj.allLinkStatuses.sentBits(allLinkIds==uniqueLinkIds(i));
                t=obj.allLinkStatuses.time(allLinkIds==uniqueLinkIds(i));
                plot(t,y);
            end
            hold off;
            xlabel('Time (s)');
            ylabel('Total Per-Link Traffic (bits)');
        end
        
        function plotAllLinkThroughput(obj)
            figure;
            hold all;
            allLinkIds=obj.allLinkStatuses.id;
            uniqueLinkIds=unique(allLinkIds);
            for i=1:numel(uniqueLinkIds)
                y=obj.allLinkStatuses.sentBits(allLinkIds==uniqueLinkIds(i));
                t=obj.allLinkStatuses.time(allLinkIds==uniqueLinkIds(i));
                [t,idx]=sort(t);
                y=diff(y(idx));
                nSmooth=5;
                y=smooth(y,nSmooth)./smooth(t(2:end),nSmooth);
                plot(t(nSmooth+1:end),y(nSmooth:end));
            end
            hold off
            xlabel('Time (s)');
            ylabel('Total Per-Link Thoughput (bits/sec)');
        end
        
        function plotLatencyById(obj, id)
            allIds = unique(obj.allLinkStatuses.id);
            if ~any(allIds == id)
                warning('No links of id == %d', id);
            end
            
            figure;
            hold on;
            inds = obj.allLinkStatuses.id == id;
            plot(obj.allLinkStatuses.time(inds), obj.allLinkStatuses.lastLatency(inds));
            xlabel('Time');
            ylabel('Latency (s)');
            title(sprintf('Link Latency for ID = %d', id));
        end
        
        function plotAllLinkLatencyById(obj)
            allIds = unique(obj.allLinkStatuses.id);
            for i = 1:numel(allIds)
                obj.plotLatencyById(allIds(i));
            end
        end
        
    end
    
    methods(Access=protected)
        function loadNetworkData(obj)
            networkData=publicsim.sim.Loggable.readParamsByClass(obj.logger,'publicsim.funcs.comms.Network',{'getLinkUsages','getNetworkStatus'});
            
            linkUsages=networkData.getLinkUsages;
            obj.allLinkStatuses=[];
            for i=1:numel(linkUsages)
                linkStatuses=linkUsages(i).value;
                fnames=fields(linkStatuses);
                fnames{end+1}='time'; %#ok<AGROW>
                for j=1:numel(fnames)
                    fname=fnames{j};
                    if isequal(fname,'time')
                        newVals=linkUsages(i).time*ones(1,numel([linkStatuses.(fnames{j-1})]));
                    elseif isequal(fname,'classId')
                        newVals={linkStatuses.(fname)};
                    else
                        newVals=[linkStatuses.(fname)];
                    end
                    if ~isfield(obj.allLinkStatuses,fname)
                        obj.allLinkStatuses.(fname)=newVals;
                    else
                        obj.allLinkStatuses.(fname)=[obj.allLinkStatuses.(fname) newVals];
                    end
                end
            end
            
            networkUsages=networkData.getNetworkStatus;
            obj.allNetworkStatuses=[];
            for i=1:numel(networkUsages)
                networkUsage=networkUsages(i).value;
                networkUsage.times=ones(1,numel([networkUsage.latencies]))*networkUsages(i).time;
                fnames=fields(networkUsage);
                for j=1:numel(fnames)
                    fname=fnames{j};
                    newVals=[networkUsage.(fname)];
                    if ~isfield(obj.allNetworkStatuses,fname)
                        obj.allNetworkStatuses.(fname)=newVals;
                    else
                        if size(obj.allNetworkStatuses.(fname), 1) < size(newVals, 1)
                            obj.allNetworkStatuses.(fname) = ...
                                [obj.allNetworkStatuses.(fname); ...
                                zeros(size(newVals, 1) - ...
                                size(obj.allNetworkStatuses.(fname), 1), ...
                                size(obj.allNetworkStatuses.(fname), 2))];
                        end
                        obj.allNetworkStatuses.(fname)=[obj.allNetworkStatuses.(fname) newVals];
                    end
                end
            end
            
        end
    end
end

