classdef Switch < publicsim.sim.Callee
    %SWITCH Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        p2p_links_inputs={}
        myDestId
        network
        parent
        parentMessageQueue={}
    end
    
    methods
        function obj=Switch(network,destId)
            obj.myDestId=destId;
            obj.network=network;
        end
        
        function addP2PInputLink(obj,p2plink)
            obj.p2p_links_inputs{end+1}=p2plink;
        end
        
        function setParent(obj,parent)
            obj.parent=parent;
        end
        
        function sendMessage(obj,message,destId)
            time=obj.getCurrentTime();
            if obj.myDestId==destId %Loopback
                obj.parentMessageQueue{end+1}=message;
                obj.parent.scheduleAtTime(0);
            else
                p2pLink=obj.network.getNextHop(obj.myDestId,destId);
                if ~isempty(p2pLink)
                    data={destId,message};
                    rxTime=p2pLink.queueMessage(data,time);
                    p2pLink.outputSwitch.scheduleRx(rxTime);
                end
            end
        end
        
        function scheduleRx(obj,rxTime)
            obj.scheduleAtTime(rxTime);
        end
        
        function queue=getMessageQueue(obj)
            queue=obj.parentMessageQueue;
            obj.parentMessageQueue={};
        end
        
        function runAtTime(obj,time)
            for i=1:numel(obj.p2p_links_inputs)
                p2pLink=obj.p2p_links_inputs{i};
                while (1)
                    [data,numErrors]=p2pLink.getNextMessage(time);
                    if isempty(data)
                        break;
                    end
                    if numErrors > 0
                        continue;
                    end
                    destId=data{1};
                    message=data{2};
                    if destId==obj.myDestId
                        obj.parentMessageQueue{end+1}=message;
                        obj.parent.scheduleAtTime(time);
                    else
                        obj.sendMessage(message,destId);
                    end
                end
            end
        end
        
    end
    
end

