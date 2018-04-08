classdef Agent < publicsim.models.excelBased.builders.Builder
    
    properties
        agentData
    end
    
    properties(Access=private,Constant)
        AGENT_NAME_COLUMN='Agent Name';
        AGENT_TYPE_COLUMN='Agent Type';
        AGENT_CONSTRUCTION_COLUMN='Construction Arguments';
        AGENT_CONFIG_COLUMN='Config Name=Config Value';
        AGENT_DATA_STRUCT=struct('name',[],...
            'type',[],...
            'constructs',[],...
            'configs',[]);
    end
    
    methods
        function obj=Agent()
        end
        
        function parse(obj,sheetData)
            obj.sheetData=sheetData;
            obj.buildAgentData()
        end
        
        function buildAgentData(obj)
            agentNames=obj.findColumnDataByLabel(obj.AGENT_NAME_COLUMN);
            agentTypes=obj.findColumnDataByLabel(obj.AGENT_TYPE_COLUMN);
            agentConstructs=obj.findColumnDataByLabel(obj.AGENT_CONSTRUCTION_COLUMN);
            agentConfigs=obj.findColumnDataByLabel(obj.AGENT_CONFIG_COLUMN);
            
            for i=1:numel(agentNames)
                dataEntry=obj.AGENT_DATA_STRUCT;
                dataEntry.name=agentNames{i};
                dataEntry.type=agentTypes{i};
                constructs = [];
                if ~isempty(agentConstructs) && ~isempty(agentConstructs{i}) && all(~isnan(agentConstructs{i}))
                    constructs = agentConstructs{i};
                end
                dataEntry.constructs=constructs;
                configs=[];
                if ~isempty(agentConfigs{i}) && ~any(isnan(agentConfigs{i}))
                    configStrings=strsplit(agentConfigs{i},',');
                    
                    for j=1:numel(configStrings)
                        subConfig=strsplit(configStrings{j},'=');
                        config.name=strtrim(subConfig{1});
                        config.value=strtrim(subConfig{2});
                        if ~isempty(config.value) && config.value(1)=='#'
                            config.value = str2double(config.value(2:end));
                        end
                        configs{end+1}=config; %#ok<AGROW>
                    end
                end
                dataEntry.configs=configs;
                obj.agentData{i}=dataEntry;
            end
        end
    end
    
end

