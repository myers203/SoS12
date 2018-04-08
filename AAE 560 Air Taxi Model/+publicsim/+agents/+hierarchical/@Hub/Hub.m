classdef Hub < publicsim.agents.base.Networked
    %HUB A central agent that connects to multiple spokes in a template
    %   Detailed explanation goes here
    
    properties(Transient)
        spokes
        spokeDataService
    end
    
    methods
        
        function obj=Hub()
        end
        
        function addToNetwork(obj,clientSwitch,dataService)
            addToNetwork@publicsim.agents.base.Networked(obj,clientSwitch,dataService);
            assert(~isempty(obj.instance),'Must be called after adding to instance');
            obj.spokeDataService=dataService;
        end
        
        function addSpoke(obj,spoke,bandwidth,latency)
            assert(isa(spoke,'publicsim.agents.hierarchical.Spoke'),...
                'Only heirarchical.Spoke classes may be added');
            assert(~isempty(obj.instance),'Must be added to instance before calling');
            obj.spokes{end+1}=spoke;
            
            % Check if the child is already in the instance before adding
            if isempty(spoke.id)
                obj.instance.AddCallee(spoke);
            end
            spoke.addHub(obj);
            assert(~isempty(obj.spokeDataService),...
                'Must be added to network before adding spokes');
            %Connect everything together
            network=obj.clientSwitch.network;
            newSwitch=network.createSwitch();
            obj.instance.AddCallee(newSwitch);
            spoke.addToNetwork(newSwitch,obj.spokeDataService);
            network.createP2PLink(obj.clientSwitch,spoke.clientSwitch,bandwidth,latency);
            network.createP2PLink(spoke.clientSwitch,obj.clientSwitch,bandwidth,latency);
            
            if ~isempty(obj.instance)
                if ~spoke.hasBeenInit
                    spoke.init();
                    if ismethod(spoke,'initLog')
                        spoke.initLog();
                    end
                    spoke.hasBeenInit=1;
                end
            end
        end
        
        function addNetworkedSpoke(obj,spoke)
            obj.spokes{end+1}=spoke;
        end
        
        function matchedSpokes=getSpokesOfType(obj,type)
            matchedSpokes={};
            for i=1:numel(obj.spokes)
                if isa(obj.spokes{i},type)
                    matchedSpokes{end+1}=obj.spokes{i}; %#ok<AGROW>
                end
            end
        end
        
    end
    
end

