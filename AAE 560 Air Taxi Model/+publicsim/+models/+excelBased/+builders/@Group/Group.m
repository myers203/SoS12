classdef Group < publicsim.models.excelBased.builders.Builder

    properties
        groupData
    end
    
    properties(Access=private,Constant)
        GROUP_NAME_COLUMN='Group Name';
        RELATIONSHIP_COLUMN='Relationship';
        CENTRAL_AGENT_COLUMN='Central Agent (Outside World Link)';
        AGENT_NAME_PREFIX='Agent';
        GROUP_NAME_PREFIX='Group';
        AGENT_LINK_SUFFIX=' Link';
        NUMBER_OF_PRE_AGENT_FIELDS=3;
        GROUP_DATA_STRUCT=struct('name',[],...
            'relationship',[],...
            'centralId',[],...
            'agents',[]);
        MAX_AGENTS=999;
    end
    
    properties(Constant)
        RELATIONSHIP_STAR='Star-Peer';
        RELATIONSHIP_PARENT_CHILD='Parent/Child';
        RELATIONSHIP_NONE='None';
    end
    
    methods
        function obj=Group()
        end
        
        function parse(obj,sheetData)
            obj.sheetData=sheetData;
            obj.buildGroupData()
        end
        
        function buildGroupData(obj)
            groupNames=obj.findColumnDataByLabel(obj.GROUP_NAME_COLUMN);
            relationships=obj.findColumnDataByLabel(obj.RELATIONSHIP_COLUMN);
            centralAgentIds=obj.findColumnDataByLabel(obj.CENTRAL_AGENT_COLUMN);
            totalFields=size(obj.sheetData,2);
            totalAgentFields=totalFields-obj.NUMBER_OF_PRE_AGENT_FIELDS;
            for i=1:obj.MAX_AGENTS
                nameKey=[obj.AGENT_NAME_PREFIX '-' num2str(i)];
                if isempty(obj.findColumnDataByLabel(nameKey))
                    break;
                end
            end
            totalAgents=i-1;
            %TODO: Check if groups in use and re-calculate fields
            %assert(totalAgents==floor(totalAgents) && totalAgents==ceil(totalAgents),'Column Prefix Count Error');
            agentNames={};
            subGroupNames={};
            agentLinks={};
            for i=1:totalAgents
                nameKey=[obj.AGENT_NAME_PREFIX '-' num2str(i)];
                subGroupName=[obj.GROUP_NAME_PREFIX '-' num2str(i)];
                linkKey=[obj.AGENT_NAME_PREFIX '-' num2str(i) obj.AGENT_LINK_SUFFIX];
                agentNames{i}=obj.findColumnDataByLabel(nameKey); %#ok<AGROW>
                subGroupNames{i}=obj.findColumnDataByLabel(subGroupName); %#ok<AGROW>
                agentLinks{i}=obj.findColumnDataByLabel(linkKey); %#ok<AGROW>
            end
            
            for i=1:numel(groupNames)
                dataEntry=obj.GROUP_DATA_STRUCT;
                dataEntry.name=groupNames{i};
                dataEntry.relationship=relationships{i};
                dataEntry.centralId=centralAgentIds{i};
                agents={};
                subGroups={};
                for j=1:numel(agentNames)
                    agentName=agentNames{j};
                    if ~isempty(agentName) && length(agentName) >= i
                        agentName=agentName{i};
                    else
                        agentName=NaN;
                    end
                    subGroupName=subGroupNames{j};
                    if ~isempty(subGroupName) && length(subGroupName) >= i
                        subGroupName=subGroupName{i};
                    else
                        subGroupName=NaN;
                    end
                    agentLink=agentLinks{j};
                    agentLink=agentLink{i};
                    if ~any(isnan(agentName))
                        agent.name=agentName;
                        agent.link=agentLink;
                        agent.groupIndex=j;
                        agents{end+1}=agent; %#ok<AGROW>
                        %subGroups{end+1}=[]; %#ok<AGROW>
                    elseif ~any(isnan(subGroupName))
                        subGroup.name=subGroupName;
                        subGroup.link=agentLink;
                        subGroup.groupIndex=j;
                        subGroups{end+1}=subGroup; %#ok<AGROW>
                        %agents{end+1}=[]; %#ok<AGROW>
                    end
                    if ~any(isnan(agentName)) && ~any(isnan(subGroupName))
                        warning('Only 1 of agent or group in agent groups tab may be specified. Agent takes precedence');
                    end
                end
                idx=1;
				newCentralId=0;
                for j=1:numel(agents)
                    if dataEntry.centralId == agents{j}.groupIndex
                        newCentralId=idx;
                    end
                    idx=idx+1;
                end
                for j=1:numel(subGroups)
                    if dataEntry.centralId == subGroups{j}.groupIndex
                        newCentralId=idx;
                    end
                    idx=idx+1;
                end
                dataEntry.centralId=newCentralId;
                dataEntry.agents=agents;
                dataEntry.subGroups=subGroups;
                obj.groupData{i}=dataEntry;
            end
        end
    end
    
end

