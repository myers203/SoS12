classdef PointToPoint < handle
    %POINTTOPOINT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        bandwidth % In bits per second
        latency % in seconds
        queueSize=16e6; % In Megabytes
        lossRate=0; %In Probability of Bit Error (BER)
        inputSwitch
        outputSwitch
        isChildLink=0
        classId
        id
        useBitErrorMode=0
    end
    
    properties(SetObservable,SetAccess=private)
        sentBits=0;
        droppedBits=0;
        lastLatency=-1;
        lastSentBits=0;
    end
    
    properties(Access=private)
        messageMap
        messageQueue
        lastMessageId=0
    end
    
    
    methods
        function obj=PointToPoint(bandwidth,latency)
            obj.messageMap=containers.Map('KeyType','int64','ValueType','any');
            obj.messageQueue=java.util.TreeMap;
            obj.bandwidth=bandwidth;
            obj.latency=latency;
        end
        
        function setLinkId(obj,id)
            obj.id=id;
        end
        
        function setBandwidth(obj,bandwidth)
            obj.bandwidth=bandwidth;
        end
        
        function setLossRate(obj,lossRate)
            obj.lossRate=lossRate;
        end
        
        function setLatency(obj,latency)
            obj.latency=latency;
        end
        
        function setClassId(obj,classId)
            obj.classId=classId;
        end
        
        function setChildLink(obj)
            obj.isChildLink=1;
        end
        
        function linkStatus=getLinkStatus(obj,deltaTime)
            linkStatus.id=obj.id;
            linkStatus.classId=obj.classId;
            linkStatus.sentBits=obj.sentBits;
            linkStatus.droppedBits=obj.droppedBits;
            linkStatus.lastLatency=obj.lastLatency;
            linkStatus.bitDiff=obj.sentBits-obj.lastSentBits;
            linkStatus.loadPct=linkStatus.bitDiff/(obj.bandwidth*deltaTime);
            linkStatus.isChildLink=obj.isChildLink;
            obj.lastSentBits=obj.sentBits;
        end
        
        function addStatusListener(obj,inspector)
            inspector.addListenerInspection(obj,'PointToPoint',...
                {'sentBits','droppedBits','lastLatency'});
        end
        
        function setOutputSwitch(obj,outputSwitch)
            obj.outputSwitch=outputSwitch;
        end
        
        function setInputSwitch(obj,inputSwitch)
            obj.inputSwitch=inputSwitch;
        end
        
        function rxTime=getRxTimeWithSize(obj,time,dataBitSize)
            if obj.messageQueue.size==0
                lastDTime=-1;
            else
                lastDTime=obj.messageQueue.lastKey();
            end
            transportDelay=dataBitSize/obj.bandwidth;
            if lastDTime < time
                % use latency() to allow for either constant or function handle latency
                rxTime=time+obj.latency()+transportDelay;
            else
                rxTime=lastDTime+transportDelay;
            end
            rxTime=round(rxTime,6);
        end
        
        function rxTime=getRxTime(obj,time,data)
            dataBitSize=obj.calcMessageSize(data);
            rxTime=obj.getRxTimeWithSize(time,dataBitSize);
        end
        
        %Use this function to override data sizes for messages
        function rxTime=queueMessageWithSize(obj,data,dataBitSize,time)
            obj.lastMessageId=obj.lastMessageId+1;
            obj.messageMap(obj.lastMessageId)={data,dataBitSize};
            obj.sentBits=obj.sentBits+dataBitSize;
            rxTime=obj.getRxTimeWithSize(time,dataBitSize);
            obj.lastLatency=rxTime-time;
            existingIds=obj.messageQueue.get(rxTime);
            newMessageIds=[existingIds' obj.lastMessageId];
            obj.messageQueue.put(rxTime,newMessageIds);
        end
        
        %Use this function to calculate data size before sending
        function rxTime=queueMessage(obj,data,time)
            size=obj.calcMessageSize(data);
            rxTime=obj.queueMessageWithSize(data,size,time);
        end
        
        function [data, numErrors]=getNextMessage(obj,time)
            data=[];
            numErrors=[];
            if obj.messageQueue.size == 0
                return
            else
                nextDTime=obj.messageQueue.firstKey();
                if (nextDTime<=time)
                    entry=obj.messageQueue.pollFirstEntry();
                    dataIdxs=entry.getValue;
                    dataIdx=dataIdxs(1);
                    dataIdxs(1)=[];
                    if ~isempty(dataIdxs)
                        obj.messageQueue.put(entry.getKey,dataIdxs);
                    end
                    dataStruct=obj.messageMap(dataIdx);
                    data=dataStruct{1};
                    dataBitSize=dataStruct{2};
                    remove(obj.messageMap,dataIdx);
                    if ~isempty(obj.lossRate) && obj.lossRate > 0
                        if obj.useBitErrorMode
                            numErrors=sum(rand(dataBitSize,1)<obj.lossRate);
                        else
                            numErrors=rand()<obj.lossRate;
                        end
                    else
                        numErrors=0;
                    end
                end
            end
        end
        
        
    end
    
    methods(Static)
        function [size,overrideSize]=calcMessageSize(data,overrideSize) %in bits
            import publicsim.*;
            size=0;
            if nargin >= 2 && ~isempty(overrideSize)
                size=overrideSize;
                return;
            else
                overrideSize=[];
            end
            if isa(data,'publicsim.funcs.comms.Message')
                overrideSize=data.getMessageSize();
            elseif ~isstruct(data) && ~iscell(data)
                whosTemp = whos('data');
                size=size+whosTemp.bytes*8;
            elseif isstruct(data)
                names=fieldnames(data);
                for i=1:length(names)
                    [addedSize,newOverrideSize]=funcs.comms.PointToPoint.calcMessageSize(data.(names{i}),overrideSize);
                    if ~isempty(newOverrideSize)
                        overrideSize=newOverrideSize;
                    end
                    size=size+addedSize;
                end
            elseif iscell(data)
                for i=1:numel(data)
                    [addedSize,newOverrideSize]=funcs.comms.PointToPoint.calcMessageSize(data{i},overrideSize);
                    if ~isempty(newOverrideSize)
                        overrideSize=newOverrideSize;
                    end
                    size=size+addedSize;
                end
            end
        end
    end
    
    %%%%% TEST METHODS %%%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            import publicsim.tests.UniversalTester.*
            tests{1} = 'publicsim.funcs.comms.PointToPoint.test_calcMessageSize';
            tests{2} = 'publicsim.funcs.comms.PointToPoint.test_deliveryTimes';
        end
    end
    
    methods (Static)
        
        function test_calcMessageSize()
            import publicsim.*;
            test_string='asdfasdf'; %String is utf-16 encoded so 2 bytes per character
            string_bits=funcs.comms.PointToPoint.calcMessageSize(test_string);
            assert(isequal(string_bits,length(test_string)*2*8),'Calc Error!');
            
            test_struct.c1=test_string;
            test_struct.c2=test_string;
            struct_bits=funcs.comms.PointToPoint.calcMessageSize(test_struct);
            assert(isequal(struct_bits,length(test_string)*2*8*2),'Calc Error!');
            
            nested_struct.s1=test_struct;
            nested_struct.s2=test_struct;
            struct_bits=funcs.comms.PointToPoint.calcMessageSize(nested_struct);
            assert(isequal(struct_bits,length(test_string)*2*8*2*2),'Calc Error!');
            
            string_array=[test_string;test_string];
            string_bits=funcs.comms.PointToPoint.calcMessageSize(string_array);
            assert(isequal(string_bits,length(test_string)*2*8*2),'Calc Error!');
            
            test_cell={test_string,test_string};
            string_bits=funcs.comms.PointToPoint.calcMessageSize(test_cell);
            assert(isequal(string_bits,length(test_string)*2*8*2),'Calc Error!');
            
            x=5.5; %#ok<NASGU>
            wt=whos('x');
            size_double=wt.bytes*8;
            testCell=mat2cell(randi(50,20,10),[2,6,12],10);
            expectedSize=sum([2,6,12])*10*size_double;
            actualSize=funcs.comms.PointToPoint.calcMessageSize(testCell);
            assert(isequal(expectedSize,actualSize),'Calc Error!');
        end
        
        function test_deliveryTimes()
            
            import publicsim.*;
            bandwidth=115200;
            latency=0.250;
            p2pc=funcs.comms.PointToPoint(bandwidth,latency);
            numTestPackets=100;
            testData={};
            for i=1:numTestPackets
                testData{i}=randi(10,10); %#ok<AGROW>
            end
            packetSize=100*64;
            packetTime=packetSize/bandwidth;
            intraSendtime=packetTime*0.9; %Intentionally overfill
            time=0;
            for i=1:numTestPackets
                p2pc.queueMessage(testData{i},time);
                time=time+intraSendtime;
            end
            
            
            %Expected number of packets
            rxPackets=0;
            for testTime=0:packetTime/10:packetTime*numTestPackets
                data=p2pc.getNextMessage(testTime);
                if ~isempty(data)
                    rxPackets=rxPackets+1;
                end
                numExpectedPackets=max(floor((testTime-1e-6-latency)/packetTime),0); %Added 1us buffer for precision boundary
                assert(isequal(numExpectedPackets,rxPackets),'Error in Delivery Time!');
            end
            
        end
    end
    
end

