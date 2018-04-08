classdef excelModelBuilder < handle
    
    properties
        fileName
        simInst
        simNetwork
        simDataService
        simEarth
        orchestratorBuilder
        scenarioBuilder
        agentBuilder
        groupBuilder
        linkBuilder
        locationBuilder
        simObservableManager
        simTwoWayConnectFunc
        lastUniqueNetworkId=10000;
    end
    
    properties(Constant)
        ORCHESTRATION_SHEET='Orchestration';
        SCENARIO_SHEET='Scenario';
        AVAILABLE_AGENT_SHEET='Available Agents';
        AGENT_GROUP_SHEET='Agent Groups';
        NETWORK_LINKS_SHEET='Network Links';
        LOCATIONS_SHEET='Locations';
    end
    
    methods
        function obj=excelModelBuilder(fileName,logPath)
            
            if nargin >= 1 && ~isempty(fileName)
                obj.loadXlsFile(fileName);
            end
            
            if nargin >= 2 && ~isempty(logPath)
                obj.orchestratorBuilder.logPath=logPath;
            end
            
            if nargin >= 1
                obj.buildBaseHandles();
                obj.buildScenario();
            end
        end
        
        function addXlsFile(obj,fileName)
            obj.loadXlsFile(fileName);
            obj.buildScenario();
        end
        
        function loadXlsFile(obj,fileName)
            obj.fileName=fileName;
            
            if isempty(obj.orchestratorBuilder)
                obj.orchestratorBuilder=publicsim.models.excelBased.builders.Orchestrator();
                [~,~,orchestrationData]=xlsread(fileName,obj.ORCHESTRATION_SHEET);
                obj.orchestratorBuilder.parse(orchestrationData);
            end
            
            obj.scenarioBuilder=publicsim.models.excelBased.builders.Scenario();
            [~,~,scenarioData]=xlsread(fileName,obj.SCENARIO_SHEET);
            obj.scenarioBuilder.parse(scenarioData);
            
            obj.agentBuilder=publicsim.models.excelBased.builders.Agent();
            [~,~,agentData]=xlsread(fileName,obj.AVAILABLE_AGENT_SHEET);
            obj.agentBuilder.parse(agentData);
            
            obj.groupBuilder=publicsim.models.excelBased.builders.Group();
            [~,~,groupData]=xlsread(fileName,obj.AGENT_GROUP_SHEET);
            obj.groupBuilder.parse(groupData);
            
            obj.linkBuilder=publicsim.models.excelBased.builders.Link();
            [~,~,linkData]=xlsread(fileName,obj.NETWORK_LINKS_SHEET);
            obj.linkBuilder.parse(linkData);
            
            obj.locationBuilder=publicsim.models.excelBased.builders.Location();
            [~,~,locationData]=xlsread(fileName,obj.LOCATIONS_SHEET);
            obj.locationBuilder.parse(locationData);
        end
        
        function buildBaseHandles(obj)
            obj.simInst=publicsim.sim.Instance(obj.orchestratorBuilder.logPath);
            observableManager=publicsim.funcs.groups.ObjectManager(obj.orchestratorBuilder.startTime);
            obj.simObservableManager=observableManager;
            
            if ~(strcmpi(obj.orchestratorBuilder.earthModel, 'elliptical') || ...
                    strcmpi(obj.orchestratorBuilder.earthModel, 'spherical'))
                obj.simEarth = eval(obj.orchestratorBuilder.earthModel);
            else
                earth = publicsim.util.Earth();
                earth.setModel(obj.orchestratorBuilder.earthModel);
                obj.simEarth=earth;
            end
            
            network=publicsim.funcs.comms.Network();
            obj.simNetwork=network;
            obj.simInst.AddCallee(obj.simNetwork);
            dataService=publicsim.funcs.comms.DataService();
            obj.simDataService=dataService;
            twoWayConnectFunc=@(source,dest,bandwidth,latency,linkType) obj.twoWayConnect(source,dest,bandwidth,latency,linkType,obj.simNetwork,obj.simDataService);
            obj.simTwoWayConnectFunc=twoWayConnectFunc;
            
        end
        
        function buildScenario(obj)
            
            %Aliases
            network=obj.simNetwork;
            twoWayConnectFunc=obj.simTwoWayConnectFunc;
            
            centralAgentSet={};
            for i=1:numel(obj.scenarioBuilder.scenarioData)
                newAgent=obj.scenarioBuilder.scenarioData{i};
                
                centralAgents={};
                newGroup=obj.groupBuilder.findEntryByName(obj.groupBuilder.groupData,newAgent.groupType);
                for l=1:newAgent.count
                    
                    addedAgentSet = {};
                    
                    for j=1:numel(newGroup.agents)
                        newSubAgentName=newGroup.agents{j}.name;
                        agent=obj.buildNewAgent(newSubAgentName,newAgent);
                        addedAgentSet{end+1}=agent; %#ok<AGROW>
                    end
                    
                    for j=1:numel(newGroup.subGroups)
                        subGroupCentralAgent=obj.buildNewGroup(newGroup.subGroups{j}.name,newAgent);
                        addedAgentSet{end+1}=subGroupCentralAgent; %#ok<AGROW>
                    end
                    
                    centralAgent=obj.addGroupNetworking(addedAgentSet,newAgent.groupType);
                    if ~isempty(centralAgent)
                        centralAgents{end+1}=centralAgent; %#ok<AGROW>
                    end
                    
                end
                centralAgentSet{i}=centralAgents; %#ok<AGROW>
            end
            
            %Central Networking
            
            for i=1:numel(obj.scenarioBuilder.scenarioData)
                newAgent=obj.scenarioBuilder.scenarioData{i};
                
                newGroup=obj.groupBuilder.findEntryByName(obj.groupBuilder.groupData,newAgent.groupType);
                if isnan(newGroup.centralId) || newGroup.centralId == 0
                    newGroup.centralId=1;
                end
                smashedAgentGroup=[newGroup.agents, newGroup.subGroups];
                linkType=smashedAgentGroup{newGroup.centralId}.link;
                linkData=obj.linkBuilder.findEntryByName(obj.linkBuilder.linkData,linkType);
                
                centralAgents=centralAgentSet{i};
                for m=1:numel(centralAgents)
                    centralAgent=centralAgents{m};
                    if ~isempty(newAgent.networkUplink) && ~any(isnan(newAgent.networkUplink)) && ~isempty(centralAgent)
                        for j=1:numel(newAgent.networkUplink)
                            try
                                uplinkAgent=centralAgentSet{newAgent.networkUplink(j)}{1}; %does not support many-to-many
                            catch e
                                warning('If dimension exceeded, check for uplink rows greater than number of rows');
                                rethrow(e);
                            end
                            %This is for compatibility:
                            if isprop(uplinkAgent, 'parentGroupId')
                                if ismethod(centralAgent,'setGroupId')
                                    centralAgent.setGroupId(uplinkAgent.parentGroupId);
                                end
                            end
                            assert(isa(uplinkAgent,'publicsim.agents.base.Networked') && ...
                                isa(centralAgent,'publicsim.agents.base.Networked'),...
                                ['Agent ' uplinkAgent.commonName ' or ' centralAgent.commonName ' not Networked agent!']);
                            
                            position1=obj.simEarth.convert_ecef2lla(centralAgent.getPosition());
                            position2=obj.simEarth.convert_ecef2lla(uplinkAgent.getPosition());
                            distance=obj.simEarth.gcdist(position1(1),position1(2),position2(1),position2(2));
                            distanceLatency=distance/(299792458.0)/linkData.distanceLatencyFactor;
                            twoWayConnectFunc(centralAgent,uplinkAgent,linkData.bandwidth,...
                                linkData.fixedLatency+distanceLatency,linkType);
                            %Upstream: central agent
                            %Downstream: leaf agent
                            centralAgent.addUpstreamNetworkId(uplinkAgent.getLocalNetworkId());
                            uplinkAgent.addDownstreamNetworkId(centralAgent.getLocalNetworkId());
                        end
                    end
                    if ~isempty(newAgent.subscription) && ~any(isnan(newAgent.subscription)) && ~isempty(centralAgent)
                        for j=1:numel(newAgent.networkUplink)
                            uplinkAgent=centralAgentSet{newAgent.networkUplink(j)}{1}; %does not support many-to-many
                            centralAgent.addExplicitSubscriptionId(uplinkAgent.getLocalNetworkId());
                        end
                    end
                end
            end
            
            network.updateNextHopList();
            obj.simNetwork=network;
            
            
            
            %network.vizualizeGraph(network);
        end
        
        function run(obj)
            obj.simInst.runUntil(obj.orchestratorBuilder.startTime,obj.orchestratorBuilder.endTime);
        end
        
        function log=getLogger(obj)
            log=publicsim.sim.Logger(obj.orchestratorBuilder.logPath);
            log.restore();
        end
        
        function twoWayConnect(obj,source,dest,bandwidth,latency,linkType,network,dataService)
            if isempty(source.clientSwitch)
                sourceSwitch=network.createSwitch();
                obj.simInst.AddCallee(sourceSwitch);
                source.addToNetwork(sourceSwitch,dataService);
            end
            
            if isempty(dest.clientSwitch)
                destSwitch=network.createSwitch();
                obj.simInst.AddCallee(destSwitch);
                dest.addToNetwork(destSwitch,dataService);
            end
            
            network.createP2PLink(source.clientSwitch,dest.clientSwitch,bandwidth,latency,linkType);
            network.createP2PLink(dest.clientSwitch,source.clientSwitch,bandwidth,latency,linkType);
        end
        
        function centralAgent=buildNewGroup(obj,groupType,newScenarioAgent)
            newGroup=obj.groupBuilder.findEntryByName(obj.groupBuilder.groupData,groupType);
            addedAgentSet={};
            for i=1:numel(newGroup.agents)
                newSubAgentName=newGroup.agents{i}.name;
                agent=obj.buildNewAgent(newSubAgentName,newScenarioAgent);
                addedAgentSet{end+1}=agent; %#ok<AGROW>
            end
            centralAgent=obj.addGroupNetworking(addedAgentSet,groupType);
        end
        
        function centralAgent=addGroupNetworking(obj,addedAgentSet,groupType)
            newGroup=obj.groupBuilder.findEntryByName(obj.groupBuilder.groupData,groupType);
            
            %Add local networking
            if isnan(newGroup.centralId) || newGroup.centralId == 0
                newGroup.centralId=1;
            end
            centralAgent=[];
            if isequal(newGroup.relationship,obj.groupBuilder.RELATIONSHIP_STAR)
                centralAgent=addedAgentSet{newGroup.centralId};
                for j=1:numel(addedAgentSet)
                    if j~=newGroup.centralId
                        agent=addedAgentSet{j};
                        linkType=newGroup.agents{j}.link;
                        linkData=obj.linkBuilder.findEntryByName(obj.linkBuilder.linkData,linkType);
                        obj.simTwoWayConnectFunc(centralAgent,agent,linkData.bandwidth,linkData.fixedLatency,linkType);
                        %Upstream: central agent
                        %Downstream: leaf agent
                        centralAgent.addDownstreamNetworkId(agent.getLocalNetworkId());
                        agent.addUpstreamNetworkId(centralAgent.getLocalNetworkId());
                        if isa(agent,'publicsim.agents.hierarchical.Spoke')
                            agent.addHub(centralAgent);
                        end
                        if isa(centralAgent,'publicsim.agents.hierarchical.Hub')
                            centralAgent.addNetworkedSpoke(agent);
                        end
                    end
                end
            elseif isequal(newGroup.relationship,obj.groupBuilder.RELATIONSHIP_PARENT_CHILD)
                centralAgent=addedAgentSet{newGroup.centralId};
                centralSwitch=obj.simNetwork.createSwitch();
                centralAgent.addToNetwork(centralSwitch,obj.simDataService);
                obj.simInst.AddCallee(centralSwitch);
                for j=1:numel(addedAgentSet)
                    if j~=newGroup.centralId
                        agent=addedAgentSet{j};
                        %May be over-written by the parent/child
                        %logic but added for consistency.
                        %Downstream removed because children lists
                        %should be used in place
                        %centralAgent.addDownstreamNetworkId(agent.getLocalNetworkId());
                        %Upstream: central agent
                        agent.addUpstreamNetworkId(centralAgent.getLocalNetworkId());
                        centralAgent.addChild(agent,0);
                    end
                end
            else %Assume networked but not connected
                if numel(addedAgentSet) >= newGroup.centralId
                    centralAgent=addedAgentSet{newGroup.centralId};
                end
                if isa(centralAgent,'publicsim.agents.base.Networked')
                    centralAgent=addedAgentSet{newGroup.centralId};
                    centralSwitch=obj.simNetwork.createSwitch();
                    centralAgent.addToNetwork(centralSwitch,obj.simDataService);
                    obj.simInst.AddCallee(centralSwitch);
                end
            end
        end
        
        function agent=buildNewAgent(obj,newSubAgentName,newScenarioAgent)
            newSubAgent=obj.agentBuilder.findEntryByName(obj.agentBuilder.agentData,newSubAgentName);
            
            try
                % Build the agent. If any construction
                % parameters are defined, use them
                if ~isempty(newSubAgent.constructs)
                    agent = eval([newSubAgent.type, '(', newSubAgent.constructs, ')']);
                else
                    agent=eval(newSubAgent.type);
                end
            catch
                error(['Agent ' newScenarioAgent.name ' attempted to create a ' newSubAgent.type ' but it was not valid!']);
            end
            for k=1:numel(newSubAgent.configs)
                config=newSubAgent.configs{k};
                try
                    agent.(config.name)=config.value;
                catch
                    warning(['Param ' config.name ' for agent ' newScenarioAgent.name ' not settable!']);
                end
            end
            obj.simInst.AddCallee(agent);
            mediumName=[newScenarioAgent.name ' ' newSubAgent.name];
            if isa(agent,'publicsim.agents.base.Networked')
                agent.setNetworkName(mediumName);
            end
            agent.setCommonName(mediumName);
            %This is for compatibility:
            if ismethod(agent,'setGroupId')
                agent.setGroupId(newScenarioAgent.id);
            end
            if isa(agent,'publicsim.agents.base.Networked')
                agent.setLocalNetworkId(obj.lastUniqueNetworkId);
                obj.lastUniqueNetworkId=obj.lastUniqueNetworkId+1;
            end
            
            if isa(agent,'publicsim.funcs.detectables.IRDetectable') || ...
                    isa(agent,'publicsim.funcs.detectables.RadarDetectable')
                obj.simObservableManager.addObservable(agent);
            end
            
            if isa(agent,'publicsim.agents.functional.Sensing') ||...
                    isa(agent, 'itar.agents.threats.ThreatBuilder') ||...
                    isa(agent, 'publicsim.agents.functional.ObservableInspector') || ...
                    ismethod(agent,'setObservableManager')
                agent.setObservableManager(obj.simObservableManager);
            end
            
            if isa(agent,'publicsim.agents.physical.Worldly')
                agent.setWorld(obj.simEarth);
            end
            
            if isa(agent,'publicsim.agents.base.Locatable')
                skipManagerAdd=0;
                startLocationName=newScenarioAgent.movement.start;
                startLla=obj.locationBuilder.getLocationLla(startLocationName);
                startEcef=obj.simEarth.convert_lla2ecef(startLla);
                if ~isa(agent,'publicsim.agents.base.Movable')
                    agent.setInitialState(startEcef);
                else
                    if isempty(agent.movementManager)
                        movable=publicsim.funcs.movement.NewtonMotion();
                        agent.setMovementManager(movable);
                        agent.setInitialState(obj.orchestratorBuilder.startTime,{'position',startEcef,'velocity',[0 0 0],'acceleration',[0 0 0]});
                        if ismethod(agent, 'setHeading')
                            agent.setHeading([0 0 0]);
                        end
                    else
                        skipManagerAdd=1;
                    end
                    agent.setOrchestrationParams(startLla,[]);
                end
                
                stopLocationName=newScenarioAgent.movement.stop;
                
                if ~isequal(startLocationName,stopLocationName)
                    stopLla=obj.locationBuilder.getLocationLla(stopLocationName);
                    stopEcef=obj.simEarth.convert_lla2ecef(stopLla);
                    %TODO: HARD CODED NEEDS FIXING
                    simTimeDiff=obj.orchestratorBuilder.endTime-obj.orchestratorBuilder.startTime;
                    velocityEcef=(stopEcef-startEcef)/simTimeDiff;
                    accelerationEcef=[0 0 0];
                    if skipManagerAdd~=1
                        movable=publicsim.funcs.movement.NewtonMotion();
                        agent.setMovementManager(movable);
                        agent.setInitialState(obj.orchestratorBuilder.startTime,{'position',startEcef,'velocity',velocityEcef,'acceleration',accelerationEcef});
                        if ismethod(agent,'setHeading')
                            agent.setHeading(velocityEcef);
                        end
                    end
                    agent.setOrchestrationParams(startLla,stopLla);
                end
            end
        end
    end
    
end

