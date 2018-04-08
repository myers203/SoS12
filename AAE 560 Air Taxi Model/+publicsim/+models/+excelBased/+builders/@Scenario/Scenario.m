classdef Scenario < publicsim.models.excelBased.builders.Builder
    
    properties
        scenarioData
    end
    
    properties(Access=private,Constant)
        AGENT_GROUP_NAME_COLUMN='Agent Group Name';
        START_LOCATION_COLUMN='Agent Start Location';
        FINISH_LOCATION_COLUMN='Agent Finish Location';
        COUNT_COLUMN='Count';
        NETWORK_LINKS_COLUMN='Network Uplinks (Row,Row)';
        DEPRECATED_UPLINK_COLUMN='Uplink (Row)'
        AGENT_SUBSCRIPTION_COLUMN='Network Subscription Set (Row,Row)';
        DISPLAY_NAME_COLUMN='Display Name';
        SCENARIO_DATA_STRUCT=struct('id',[],...
            'groupType',[],...
            'name',[],...
            'movement',struct('start',[],'stop',[]),...
            'count',[],...
            'networkUplink',[],...
            'subscription',[]);
    end
    
    methods
        function obj=Scenario()
        end
        
        function parse(obj,sheetData)
            obj.sheetData=sheetData;
            obj.buildScenarioData();
        end
        
        function buildScenarioData(obj)
            agentTypes=obj.findColumnDataByLabel(obj.AGENT_GROUP_NAME_COLUMN);
            agentNames=obj.findColumnDataByLabel(obj.DISPLAY_NAME_COLUMN);
            movementStarts=obj.findColumnDataByLabel(obj.START_LOCATION_COLUMN);
            movementStops=obj.findColumnDataByLabel(obj.FINISH_LOCATION_COLUMN);
            counts=obj.findColumnDataByLabel(obj.COUNT_COLUMN);
            networkUplinks=obj.findColumnDataByLabel(obj.NETWORK_LINKS_COLUMN);
            if isempty(networkUplinks)
                networkUplinks=obj.findColumnDataByLabel(obj.DEPRECATED_UPLINK_COLUMN);
                warning('OLD VERSION OF XLS USED! Needs Subscription Column in Orchestrator')
            end
            subscriptions=obj.findColumnDataByLabel(obj.AGENT_SUBSCRIPTION_COLUMN);
            if isempty(subscriptions)
                warning('OLD VERSION OF XLS USED! Needs Subscription Column in Orchestrator')
                subscriptions=cell(numel(agentNames),1);
            end
            
            for i=1:numel(agentTypes)
                dataEntry=obj.SCENARIO_DATA_STRUCT;
                dataEntry.groupType=agentTypes{i};
                dataEntry.name=agentNames{i};
                dataEntry.id=i;
                dataEntry.movement.start=movementStarts{i};
                dataEntry.movement.stop=movementStops{i};
                dataEntry.count=counts{i};
                dataEntry.networkUplink=obj.splitCSVToArray(networkUplinks{i})-1; %off by 1 due to header
                dataEntry.subscription=obj.splitCSVToArray(subscriptions{i})-1; %off by 1 due to header
                obj.scenarioData{i}=dataEntry;
            end
        end
        
    end
    
end

