classdef Link < publicsim.models.excelBased.builders.Builder
    
    properties
        linkData
    end
    
    properties(Access=private,Constant)
        LINK_NAME_COLUMN='Link Name';
        BANDWIDTH_COLUMN='Bandwidth (bps)';
        FIXED_LATENCY_COLUMN='Fixed Latency (ms)';
        USE_DISTANCE_LATENCY_COLUMN='Use Distance Latency';
        DISTANCE_LATENCY_TRUE='Y';
        DISTANCE_LATENCY_FALSE='N';
        LATENCY_DISTANCE_FACTOR_COLUMN='Latency Distance Factor (% of c)';
        LINK_DATA_STRUCT=struct('name',[],...
            'bandwidth',[],...
            'fixedLatency',[],...
            'distanceLatencyFactor',[]);
    end
    
    methods
        function obj=Link()
        end
        
        function parse(obj,sheetData)
            obj.sheetData=sheetData;
            obj.buildLinkData();
        end
        
        function buildLinkData(obj)
            linkNames=obj.findColumnDataByLabel(obj.LINK_NAME_COLUMN);
            linkBandwidths=obj.findColumnDataByLabel(obj.BANDWIDTH_COLUMN);
            fixedLatencies=obj.findColumnDataByLabel(obj.FIXED_LATENCY_COLUMN);
            useDistances=obj.findColumnDataByLabel(obj.USE_DISTANCE_LATENCY_COLUMN);
            distanceFactors=obj.findColumnDataByLabel(obj.LATENCY_DISTANCE_FACTOR_COLUMN);
            
            for i=1:numel(linkNames)
                dataEntry=obj.LINK_DATA_STRUCT;
                dataEntry.name=linkNames{i};
                dataEntry.bandwidth=linkBandwidths{i};
                dataEntry.fixedLatency=fixedLatencies{i}/1000; %in miliseconds
                if strcmpi(dataEntry.fixedLatency,'inf')
                    dataEntry.fixedLatency=inf;
                end
                
                if strcmpi(dataEntry.bandwidth,'inf')
                    dataEntry.bandwidth=inf;
                end
                
                if isequal(useDistances{i},obj.DISTANCE_LATENCY_FALSE) || any(isnan(distanceFactors{i}))
                    dataEntry.distanceLatencyFactor=inf;
                else
                    dataEntry.distanceLatencyFactor=distanceFactors{i};
                end
                obj.linkData{i}=dataEntry;
            end
        end
    end
    
end

