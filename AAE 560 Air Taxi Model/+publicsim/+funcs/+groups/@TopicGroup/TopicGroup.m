classdef TopicGroup < handle
    %TOPICGROUP Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=private)
        topicMap;
    end
    
    properties(Constant)
        topicStruct=struct('name',[],...
            'objects',[]);
        topicDelimiter='/';
    end
    
    methods
        function obj=TopicGroup()
            obj.topicMap=containers.Map('KeyType','char','ValueType','any');
        end
        
        function topicData=getTopicData(obj,topicString)
            if ~isKey(obj.topicMap,topicString)
                topicData=[];
                return;
            end
            topicData=obj.topicMap(topicString);
        end
        
        function objects=getObjects(obj,topicString)
            topicData=obj.getTopicData(topicString);
            if isempty(topicData)
                objects={};
            else
                objects=topicData.objects;
            end
        end
        
        function appendToTopic(obj,topicString,newObject)
            assert(~isempty(newObject),'Called without object input');
            if ~isKey(obj.topicMap,topicString)
                obj.addTopic(topicString);
            end
            topicData=obj.getTopicData(topicString);
            topicData.objects{end+1}=newObject;
            obj.topicMap(topicString)=topicData;
        end
        
        function removeFromTopic(obj,topicString,rmObject)
            topicData=obj.getTopicData(topicString);
            rmIdx=[];
            for i=1:numel(topicData.objects)
                object=topicData.objects{i};
                if isequal(object,rmObject)
                    rmIdx(end+1)=i; %#ok<AGROW>
                end
            end
            topicData.objects(rmIdx)=[];
            obj.topicMap(topicString)=topicData;
        end
        
        function newTopic=addTopic(obj,topicString)
            assert(~isKey(obj.topicMap,topicString),'Existing topic!');
            newTopic=obj.topicStruct;
            newTopic.name=topicString;
            newTopic.objects={};
            obj.topicMap(topicString)=newTopic;
        end
        
        function topicDataList=getChildTopics(obj,topicString)
            numChars=length(topicString);
            allTopics=keys(obj.topicMap);
            topicDataList={};
            for i=1:numel(allTopics)
                testString=allTopics{i};
                if strncmp(topicString,testString,numChars) == 1
                    if (length(testString) > numChars && testString(numChars+1) == obj.topicDelimiter)
                        topicDataList{end+1}=obj.getTopicData(allTopics{i}); %#ok<AGROW>
                    end
                end
            end
        end
        
        function objects=getChildObjects(obj,topicString)
            topicDataList=obj.getChildTopics(topicString);
            objects={};
            for i=1:numel(topicDataList)
                newObjects=topicDataList{i}.objects;
                objects=[objects newObjects]; %#ok<AGROW>
            end
        end
        
        function allTopics=getAllTopics(obj)
            allTopics=keys(obj.topicMap);
        end
        
        
    end
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.funcs.groups.TopicGroup.test_TopicGroup';
        end
    end
    
    methods(Static)
        function test_TopicGroup()
            import publicsim.*;
            tg=funcs.groups.TopicGroup();
            tg.addTopic('observable/object1');
            tg.addTopic('observable/object2');
            tg.addTopic('observable/object3');
            tg.addTopic('observables');
            tc{1}=tests.sim.Test_Callee();
            tc{1}.setId(1);
            tg.appendToTopic('observable/object1',tc{1});
            tc{2}=tests.sim.Test_Callee();
            tc{2}.setId(2);
            tg.appendToTopic('observable/object2',tc{2});
            tc{3}=tests.sim.Test_Callee();
            tg.appendToTopic('observable/object3',tc{3});
            tc{4}=tests.sim.Test_Callee();
            tc{5}=tests.sim.Test_Callee();
            tc{6}=tests.sim.Test_Callee();
            tg.appendToTopic('observables',tc{4});
            tg.appendToTopic('observables',tc{5});
            tg.appendToTopic('observables',tc{6});
            tc{3}.setId(3);
            tc{4}.setId(4);
            tc{5}.setId(5);
            tc{6}.setId(6);
            
            group1=tg.getChildObjects('observable');
            assert(isequal(group1,tc(1:3)),'Failed child test');
            group2=tg.getObjects('observables');
            assert(isequal(group2,tc(4:6)),'Failed parent test');
            
            tg.removeFromTopic('observables',tc{4});
            group3=tg.getObjects('observables');
            assert(isequal(group3,tc(5:6)),'Failed Removal Test');
        end
    end
    
end

