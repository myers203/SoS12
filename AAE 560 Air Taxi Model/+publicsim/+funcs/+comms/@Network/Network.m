classdef Network < publicsim.sim.Callee
    %NETWORK Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        switches
        p2p_links
        lastLinkId=0;
        lastSwitchId=0;
    end
    
    properties(Access=private)
        graph;
        nextHopList;
        addNetworkLogs = 1;
    end
    
    properties(Constant)
        loggingPeriod=1.0;
    end
    
    methods
        
        function obj=Network()
            obj.switches=containers.Map('KeyType','int64','ValueType','any');
            obj.p2p_links=containers.Map('KeyType','int64','ValueType','any');
        end
        
        function setAddNetworkLogs(obj, val)
            obj.addNetworkLogs = val;
        end
        
        function p2pLinks=getAllLinks(obj)
            p2pLinks=values(obj.p2p_links);
        end
        
        function networkStatus=getNetworkStatus(obj)
            statusGraph=obj.createWeightedGraphNoChildren();
            statusGraph=rmfield(statusGraph,'edge_links');
            networkStatus=statusGraph;
        end
        
        function linkStatus=getLinkUsages(obj)
            linkStatus = [];
            p2p_linkList=values(obj.p2p_links);
            for i=1:numel(p2p_linkList)
                p2pLink=p2p_linkList{i};
                if isempty(linkStatus)
                    linkStatus = p2pLink.getLinkStatus(obj.loggingPeriod);
                end
                linkStatus(i)=p2pLink.getLinkStatus(obj.loggingPeriod); %#ok<AGROW>
            end
        end
        
        function addStatusListeners(obj,inspector) %#ok<INUSD>
            %{
            p2p_linkList=values(obj.p2p_links);
            for i=1:numel(p2p_linkList)
                p2p_link=p2p_linkList{i};
                p2p_link.addStatusListener(inspector);
            end
            %}
        end
        
        function newSwitch=createSwitch(obj)
            obj.lastSwitchId=obj.lastSwitchId+1;
            switchId=obj.lastSwitchId;
            newSwitch=publicsim.funcs.comms.Switch(obj,switchId);
            obj.switches(switchId)=newSwitch;
        end
        
        function p2pLink=createP2PLink(obj,sourceSwitch,destSwitch,bandwidth,latency,classId)
            if nargin < 6
                classId=[];
            end
            obj.lastLinkId=obj.lastLinkId+1;
            p2pLinkId=obj.lastLinkId;
            p2pLink=publicsim.funcs.comms.PointToPoint(bandwidth,latency);
            p2pLink.setOutputSwitch(destSwitch);
            p2pLink.setInputSwitch(sourceSwitch);
            p2pLink.setLinkId(p2pLinkId);
            p2pLink.setClassId(classId);
            destSwitch.addP2PInputLink(p2pLink);
            obj.p2p_links(p2pLinkId)=p2pLink;
        end
        
        function WLOSLink=createWLOSLink(obj,sourceSwitch,destSwitch,bandwidth,classId)
            if nargin < 5
                classId = [];
            end
            obj.lastLinkId = obj.lastLinkId+1;
            WLOSLinkId = obj.lastLinkId;
            WLOSLink=publicsim.funcs.comms.WLOS(bandwidth);
            WLOSLink.setOutputSwitch(destSwitch);
            WLOSLink.setInputSwitch(sourceSwitch);
            WLOSLink.setLinkId(WLOSLinkId);
            WLOSLink.setClassId(classId);
            destSwitch.addP2PInputLink(WLOSLink);
            obj.p2p_links(WLOSLinkId) = WLOSLink;
        end
        
        function [graph]=createWeightedGraphNoChildren(obj)
            testDataSize=64;
            p2pKeySet=keys(obj.p2p_links);
            edges=zeros(2,numel(p2pKeySet));
            weights=zeros(1,numel(p2pKeySet));
            latencies=zeros(1,numel(p2pKeySet));
            edge_links=cell(numel(p2pKeySet),1);
            childIds=[];
            for i=1:numel(p2pKeySet)
                p2pLink=obj.p2p_links(p2pKeySet{i});
                if p2pLink.isChildLink
                    childIds(end+1)=i; %#ok<AGROW>
                end
                edges(:,i)=[p2pLink.inputSwitch.myDestId p2pLink.outputSwitch.myDestId];
                edge_links{i}=p2pLink;
                weights(i)=p2pLink.getRxTimeWithSize(1e9,testDataSize)-1e9;
                latencies(i)=p2pLink.getRxTimeWithSize(1e9,0)-1e9;
            end
            edges(:,childIds)=[];
            edge_links(childIds)=[];
            weights(childIds)=[];
            latencies(childIds)=[];
            verts=unique(unique(edges));
            
            graph.verts=verts;
            graph.edges=edges;
            graph.edge_links=edge_links;
            graph.weights=weights;
            graph.latencies=latencies;
        end
        
        function [graph]=createWeightedGraph(obj)
            testDataSize=64;
            p2pKeySet=keys(obj.p2p_links);
            edges=zeros(2,numel(p2pKeySet));
            weights=zeros(1,numel(p2pKeySet));
            latencies=zeros(1,numel(p2pKeySet));
            edge_links=cell(numel(p2pKeySet),1);
            for i=1:numel(p2pKeySet)
                p2pLink=obj.p2p_links(p2pKeySet{i});
                edges(:,i)=[p2pLink.inputSwitch.myDestId p2pLink.outputSwitch.myDestId];
                edge_links{i}=p2pLink;
                weights(i)=p2pLink.getRxTimeWithSize(0,testDataSize);
                latencies(i)=p2pLink.getRxTimeWithSize(0,0);
            end
            verts=unique(unique(edges));
            
            graph.verts=verts;
            graph.edges=edges;
            graph.edge_links=edge_links;
            graph.weights=weights;
            graph.latencies=latencies;
            obj.graph=graph;
        end
        
        function updateNextHopList(obj)
            hopList=zeros(obj.lastSwitchId,obj.lastSwitchId);
            obj.createWeightedGraph();
            dg=digraph(obj.graph.edges(1,:),obj.graph.edges(2,:),obj.graph.weights);
            for i=1:numel(obj.graph.verts)
                sourceVertex=obj.graph.verts(i);
                for j=1:numel(obj.graph.verts)
                    destinationVertex=obj.graph.verts(j);
                    if destinationVertex==sourceVertex
                        hopList(sourceVertex,destinationVertex)=0;
                    else
                        P=shortestpath(dg,sourceVertex,destinationVertex);
                        if isempty(P)
                            hopList(sourceVertex,destinationVertex)=0;
                        else
                            edge=[sourceVertex P(2)];
                            p2pLink=obj.graph.edge_links{ismember(obj.graph.edges',edge,'rows')};
                            hopList(sourceVertex,destinationVertex)=p2pLink.id;
                        end
                    end
                end
            end
            obj.nextHopList=hopList;
        end
        
        function p2pLink=getNextHop(obj,srcId,destId)
            if isempty(obj.nextHopList) % Here
                obj.updateNextHopList();
            end
            if srcId > size(obj.nextHopList,1) || destId > size(obj.nextHopList,2)
                obj.updateNextHopList();
            end
            p2pLinkId=obj.nextHopList(srcId,destId);
            if ~isKey(obj.p2p_links,p2pLinkId)
                p2pLink=[];
            else
                p2pLink=obj.p2p_links(p2pLinkId);
            end
        end
        
        function v=getGraph(obj)
            v=obj.graph;
        end
        
        function runAtTime(~)
            %Do nothing yet (sometime update graph)
        end
        
    end
    
    methods(Static)
        
        function dg=vizualizeGraph(network)
            graph=network.createWeightedGraphNoChildren();
            vertNames=cell(max(graph.verts),1);
            for i=1:max(graph.verts)
                vertNames{i}=num2str(i);
            end
            for i=1:length(graph.verts)
                vertNames{i}=num2str(graph.verts(i));
                sw=network.switches(graph.verts(i));
                if ~isempty(sw.parent)
                    %Nothing on Data Client
                    if ~isempty(sw.parent.parent)
                        try
                            vertNames{graph.verts(i)}=[num2str(graph.verts(i)) '-' sw.parent.parent.netName];
                        catch
                        end
                    end
                end
            end
            dg=digraph(graph.edges(1,:),graph.edges(2,:),graph.weights*1000,vertNames);
            plot(dg,'EdgeLabel',round(dg.Edges.Weight,2));
        end
        
        function dg=vizualizeGraphWithParentChild(network)
            graph=network.createWeightedGraph();
            vertNames=cell(length(graph.verts),1);
            for i=1:length(graph.verts)
                vertNames{i}=num2str(graph.verts(i));
                sw=network.switches(graph.verts(i));
                if ~isempty(sw.parent)
                    %Nothing on Data Client
                    if ~isempty(sw.parent.parent)
                        try
                            vertNames{i}=[num2str(graph.verts(i)) '-' sw.parent.parent.netName];
                        catch
                        end
                    end
                end
            end
            dg=digraph(graph.edges(1,:),graph.edges(2,:),graph.weights*1000,vertNames);
            plot(dg,'EdgeLabel',round(dg.Edges.Weight,2));
        end
        
        function network=test_routing()
            import publicsim.*;
            network=funcs.comms.Network();
            parent=tests.sim.Test_Callee;
            numSwitches=15;
            switches=cell(numSwitches,1);
            for i=1:numSwitches
                newSwitch=network.createSwitch();
                newSwitch.setParent(parent);
                switches{i}=newSwitch;
            end
            
            edges=[];
            layer_1=[1]; %#ok<NBRAK,NASGU>
            edges=[edges; 1 2; 1 3;];
            layer_2=[2 3]; %#ok<NASGU>
            edges=[edges; 2 4; 2 5; 3 6; 3 7;];
            layer_3=[4 5 6 7]; %#ok<NASGU>
            edges=[edges; 4 8; 4 9; 5 10; 5 11; 6 12; 6 13; 7 14; 7 15;];
            layer_4=[8 9 10 11 12 13 14 15]; %#ok<NASGU>
            
            bandwidth=115.2e3;
            latency=0.250;
            
            p2pLinks=cell(size(edges,1),2);
            for i=1:size(edges,1)
                s=edges(i,1);
                d=edges(i,2);
                p2pLinks{i,1}=network.createP2PLink(switches{s},switches{d},bandwidth,latency);
                p2pLinks{i,2}=network.createP2PLink(switches{d},switches{s},bandwidth,latency);
            end
            
            graph=network.createWeightedGraph();
            assert(isequal(numel(graph.verts),numSwitches),'Error in Graph!');
            assert(isequal(numel(graph.weights),size(edges,1)*2),'Error in Graph!');
            assert(isequal(numel(graph.edges),size(edges,1)*4),'Error in Graph!');
            
            network.updateNextHopList();
            %Check some network.getNextHop() to see where traffic goes
            
            %Check route from 9 to 12, 4 to 15, 1 to 6
            
            %9 to 12 should be 9->4->2->1->3->6->12
            expectedHopList=[9 4 2 1 3 6 12];
            src=9;
            dest=12;
            hop_list=funcs.comms.Network.test_hopList(network,src,dest);
            assert(isequal(expectedHopList,hop_list),'Failed to Route!');
            
            %4 to 15 should be 4->2->1->3->7->15
            expectedHopList=[4 2 1 3 7 15];
            src=4;
            dest=15;
            hop_list=funcs.comms.Network.test_hopList(network,src,dest);
            assert(isequal(expectedHopList,hop_list),'Failed to Route!');
            
            %1 to 6 should be 1->3->6
            expectedHopList=[1 3 6];
            src=1;
            dest=6;
            hop_list=funcs.comms.Network.test_hopList(network,src,dest);
            assert(isequal(expectedHopList,hop_list),'Failed to Route!');
            
        end
        
        function hop_list=test_hopList(network,src,dest)
            hop_list=[];
            for i=1:100
                hop_list(end+1)=src; %#ok<AGROW>
                nextHop=network.getNextHop(src,dest).outputSwitch.myDestId;
                src=nextHop;
                if src==dest
                    hop_list(end+1)=src; %#ok<AGROW>
                    break;
                end
                assert(i<100,'Failed to Route!');
            end
        end
        
        function test_delivery(network,sendPeriod)
            import publicsim.*;
            src=9;
            dest=12;
            srcSw=network.switches(src);
            destSw=network.switches(dest);
            hop_list=funcs.comms.Network.test_hopList(network,src,dest);
            
            receiver=tests.funcs.comms.NetworkCallee(destSw,0);
            sender=tests.funcs.comms.NetworkCallee(srcSw,dest);
            sender.setSendPeriod(sendPeriod);
            
            bandwidth=115.2e3;
            latency=0.250;
            numTestPackets=100;
            packetSize=100*64;
            packetTime=packetSize/bandwidth+latency;
            totalPacketTime=packetTime*(length(hop_list)-1);
            
            tsim=sim.Instance('./tmp');
            tsim.AddCallee(receiver);
            tsim.AddCallee(sender);
            switchKeys=keys(network.switches);
            for i=1:length(switchKeys)
                tsim.AddCallee(network.switches(switchKeys{i}));
            end
            
            tsim.runUntil(0,Inf);
            
            assert(isequal(length(sender.messageLog),length(receiver.messageLog)),'Message Failures!');
            assert(isequal(sender.messageLog,receiver.messageLog),'Message Failures!');
            
            deliveryDelays=receiver.messageTimes-sender.messageTimes;
            error=sum(deliveryDelays)-length(deliveryDelays)*totalPacketTime-packetTime;
            if sendPeriod == 1
                assert(error<1,'Message Delay Calc Failure!');
            else
                endTime=numTestPackets*packetSize/bandwidth+totalPacketTime;
                testEndTime=receiver.messageTimes(end);
                assert((abs(endTime-testEndTime))<0.1,'Message Delay Calc Failure!');
            end
            
            
            
            
        end
    end
    
    methods(Static,Access=private)
        
        function addPropertyLogs(obj)
            if obj.addNetworkLogs
                obj.addPeriodicLogItems({'getLinkUsages','getNetworkStatus'},obj.loggingPeriod);
            end
        end
        
    end
    
    
    %%%%% TEST FUNCTIONS %%%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.funcs.comms.Network.test_network';
        end
    end
    
    methods (Static)
        
        function test_network()
            import publicsim.*;
            network=funcs.comms.Network.test_routing();
            funcs.comms.Network.test_delivery(network,0.01);
            funcs.comms.Network.test_delivery(network,1);
        end
        
    end
    
end

