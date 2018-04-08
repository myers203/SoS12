function [ nodes,network ] = buildNetwork( simInst )
%BUILDNETWORK Summary of this function goes here
%   Detailed explanation goes here

import publicsim.*;
bandwidth=100e3;
latency=0.200;

network=funcs.comms.Network();
dataService=funcs.comms.DataService();

connectFunc=@(parent,child) fullConnectFunc(parent,child,bandwidth,latency,network);
nodeFunc=@(depth,parentId) newNodeFunc(simInst,network,dataService,depth);

numNodes=[1 3 5];

nodes=models.networking.BalancedTree(numNodes,nodeFunc,connectFunc);



end


function node=newNodeFunc(testSim,network,dataService,depth)
    import publicsim.*;
    clientSwitch=network.createSwitch();
    testSim.AddCallee(clientSwitch);
    if depth==1
        newAgent=tests.integration.netsens.NetworkedObserver();
    elseif depth==2
        newAgent=agents.base.Networked();
        newAgent.setNetworkName('Switch');
    else
        newAgent=tests.integration.netsens.NetworkedSensor();
    end
    testSim.AddCallee(newAgent);
    newAgent.addToNetwork(clientSwitch,dataService);
    node=newAgent;
end

function fullConnectFunc(parent,child,bandwidth,latency,network)
    network.createP2PLink(parent.clientSwitch,child.clientSwitch,bandwidth,latency);
    network.createP2PLink(child.clientSwitch,parent.clientSwitch,bandwidth,latency);
end