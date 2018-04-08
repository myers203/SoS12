classdef NetworkCallee < publicsim.sim.Callee
    %NETWORKCALLEE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        messageLog={};
        messageTimes=[];
        networkSwitch;
        destNode;
        sendPeriod=1;
        numTestPackets=100;
    end
    
    methods
        function obj=NetworkCallee(networkSwitch,destNode)
            obj.networkSwitch=networkSwitch;
            obj.networkSwitch.setParent(obj);
            obj.destNode=destNode;
        end
        
        function init(obj)
            if obj.destNode ~= 0
                obj.scheduleAtTime(0);
            end
        end
        
        function setSendPeriod(obj,sendPeriod)
            obj.sendPeriod=sendPeriod;
        end
        
        function runAtTime(obj,time)
            if obj.destNode==0 %Receiver
                msgQueue=obj.networkSwitch.getMessageQueue();
                obj.messageTimes(end+1)=time;
                for i=1:length(msgQueue)
                    obj.messageLog{end+1}=msgQueue{i};
                end
            else %Transmitter
                message=randi(10,10);
                obj.messageLog{end+1}=message;
                obj.messageTimes(end+1)=time;
                obj.networkSwitch.sendMessage(message,obj.destNode);
                if length(obj.messageLog) < obj.numTestPackets
                    obj.scheduleAtTime(time+obj.sendPeriod);
                end
            end
        end
    end
    
end

