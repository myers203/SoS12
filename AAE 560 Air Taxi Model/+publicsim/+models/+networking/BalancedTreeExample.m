function BalancedTreeExample()

import publicsim.*;
numNodes=[1 1 5 3]; %4 level binary tree

network=funcs.comms.Network();
dataService=funcs.comms.DataService();
testSim=sim.Instance('./tmp');


bandwidth=100e3;
latency=0.200;
connectFunc=@(parent,child) fullConnectFunc(parent,child,bandwidth,latency,network);

nodeFunc=@(depth,parentId) newNodeFunc(testSim,network,dataService);

nodes=models.networking.BalancedTree(numNodes,nodeFunc,connectFunc); %#ok<NASGU>


network.updateNextHopList();
network.vizualizeGraph(network);


end

function node=newNodeFunc(testSim,network,dataService)
    import publicsim.*;
    clientSwitch=network.createSwitch();
    testSim.AddCallee(clientSwitch);
    networkAgent=agents.base.Networked();
    testSim.AddCallee(networkAgent);
    networkAgent.addToNetwork(clientSwitch,dataService);
    node=networkAgent;
end

function fullConnectFunc(parent,child,bandwidth,latency,network)
    network.createP2PLink(parent.clientSwitch,child.clientSwitch,bandwidth,latency);
    network.createP2PLink(child.clientSwitch,parent.clientSwitch,bandwidth,latency);
end