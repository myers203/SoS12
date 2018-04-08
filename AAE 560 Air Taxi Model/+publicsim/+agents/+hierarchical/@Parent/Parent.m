classdef Parent < publicsim.agents.base.Networked
    %PARENT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        useSingleNetwork=1 %Automatically connect children via switches
        parentGroupId
    end
    
    properties(SetAccess=private, Transient)
        children
        childDataService
    end
    
    methods
        
        function obj=Parent()
        end
        
        function addToNetwork(obj,clientSwitch,dataService)
            addToNetwork@publicsim.agents.base.Networked(obj,clientSwitch,dataService);
            assert(~isempty(obj.instance),'Must be called after adding to instance');
            obj.childDataService=dataService;
        end
        
        function setGroupId(obj,id)
            obj.parentGroupId=id;
        end
        
        function addChild(obj,child,doInit)
            if nargin <= 2
                doInit=1;
            end
            assert(isa(child,'publicsim.agents.hierarchical.Child'),...
                'Only heirarchical.Child classes may be added');
            assert(~isempty(obj.instance),'Must be added to instance before calling');
            obj.children{end+1}=child;

            % Check if the child is already in the instance before adding
            if isempty(child.id)
                obj.instance.AddCallee(child);
            end
            child.setParent(obj);
            if obj.useSingleNetwork
                assert(~isempty(obj.childDataService),...
                    'Must be added to network with useSingleNetwork');
                %Connect everything together
                network=obj.clientSwitch.network;
                newSwitch=network.createSwitch();
                obj.instance.AddCallee(newSwitch);
                child.addToNetwork(newSwitch,obj.childDataService);
                bandwidth=inf;
                latency=0;
                childLink=network.createP2PLink(obj.clientSwitch,child.clientSwitch,bandwidth,latency);
                childLink.setChildLink();
                childLink=network.createP2PLink(child.clientSwitch,obj.clientSwitch,bandwidth,latency);
                childLink.setChildLink();
            end
            if ~isempty(obj.instance)
                if ~child.hasBeenInit && doInit == 1
                    child.init();
                    if ismethod(child,'initLog')
                        child.initLog();
                    end
                    child.hasBeenInit=1;
                end
            end
        end
        
        function matchedChildren=getChildrenOfType(obj,type)
            matchedChildren={};
            for i=1:numel(obj.children)
                if isa(obj.children{i},type)
                    matchedChildren{end+1}=obj.children{i}; %#ok<AGROW>
                end
            end
        end
        
    end
    
    methods(Abstract)
    end
    
end

