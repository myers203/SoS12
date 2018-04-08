function [network,agentMgr,obsMgr] = buildModel(simInst,simTimes,numAgents,agentClasses,n_ports) %#ok<INUSD>
    % BUILDMODEL Create link between the aircraft and the ports
    % serviced by the provider
    import publicsim.*;

    % Radio communictions paramenters
    bandwidth    = 10e9; % TODO make real (currently infinite)
    latency      = 0.1 + (5000 / 650e3) * (2.2 - 0.1); % [ms] latency (5000 = 5 km) (orig: 0.200) TODO Correct?
    
    obsMgr       = funcs.groups.ObjectManager(simTimes.startTime);
    agentMgr     = funcs.groups.TopicGroup();
    network      = funcs.comms.Network();
    dataService  = funcs.comms.DataService();
    
    % Level 1: Create traffic control switches: "a" and "b", connect them
    aSwitch = network.createSwitch();
    bSwitch = network.createSwitch();
    simInst.AddCallee(aSwitch);
    simInst.AddCallee(bSwitch);
    network.createP2PLink(aSwitch,bSwitch,bandwidth,latency); % a --> b
    
    % Derive agent class "short name"
    for ii=1:length(agentClasses)
        agentShortClass{ii} = strsplit(agentClasses{ii},'.');
        agentShortClass{ii} = agentShortClass{ii}{end}; %#ok<*AGROW>
    end
    
    % Level 2: Add agent(s) with client switches 
    for ii=1: length(numAgents)
        for jj=1:numAgents(ii)
            clientSwitch = network.createSwitch();  % Create switch for agent
            simInst.AddCallee(clientSwitch);        % Add switch to sim
            eval(['newAgent = ' agentClasses{ii} '(n_ports);']); % Create agent
            simInst.AddCallee(newAgent);            % Add agent to sim
            newAgent.setNetworkName([agentShortClass{ii} ':' num2str(newAgent.id)]); % Label for network graph (was: agentClass)
            agentMgr.appendToTopic([agentShortClass{ii} '/'],newAgent); % For finding agents (was: [newAgent.netName'/' num2str(newAgent.id)])  
            newAgent.addToNetwork(clientSwitch,dataService);  % Add to network

            % Connect to "a" and "b": agent-->a, b-->agent
            network.createP2PLink(newAgent.clientSwitch,aSwitch              ,bandwidth,latency);
            network.createP2PLink(bSwitch              ,newAgent.clientSwitch,bandwidth,latency);
        end
    end
end
