classdef Event < handle
    %EVENT Framework for detecting complex events and signaling listeners
    % Houses the event detectors
    
    properties (Access = private)
        runFunctionHandle; % Function to run to detect an event First argument is always time. If using persistent data, second argument must be the persistent data struct
        initFunctionHandle; % In some cases, an initialization for a function may need to be called
        eventSubscribers = {}; % Function handles to call when the event is triggered
        subscriberArgs = {}; % Cell array of input arguments for each subscriber
        subscriberReturnMessages = {}; % Cell array of return messages when a subscriber is triggered
        numSubscribers = 0; % Number of subscribers to the event
    end
    
    properties (SetAccess = private)
        name = ''; % Name of the event
    end
    
    methods
        function obj = Event(name)
            % Constructor, enforce giving the event a name
            obj.name = name;
        end
        
        function runAtTime(obj, time)
            % Runs the event detector and triggers subscribers if needed
            if obj.numSubscribers == 0
                return;
            end
            
            % Runs the event detector function. If an event is triggered,
            % notify all subscribers
            
            % Handle any subscriber arguments
            if isempty(obj.subscriberArgs)
                bool = obj.runFunctionHandle(time);
            else
                bool = obj.runFunctionHandle(time, obj.subscriberArgs);
            end

            % If an event occurs, trigger and signal the subscribers
            if any(bool)
                obj.trigger(bool);
            end
        end
        
        function trigger(obj, triggeredSubs)
            if all(triggeredSubs)
                % If this is not a case-by-case basis, signal all
                % subscribers
                for i = 1:obj.numSubscribers
                    obj.eventSubscribers{i}();
                end
            else
                % Signal only the subscribers that are triggered
                triggered = find(triggeredSubs);
                for i = 1:numel(triggered)
                    if isempty(obj.subscriberReturnMessages{i});
                        obj.eventSubscribers{triggered(i)}();
                    else
                        obj.eventSubscribers{triggered(i)}(obj.subscriberReturnMessages{triggered(i)});
                    end
                end
            end
        end
        
        function addSubscriber(obj, subscriberHandle, varargin)
            % Adds a subscriber to the event
            % INPUTS:
            % subscriberHandle: Function handle that should be called when the
            % event is triggered
            % varargin: Inputs needed for the specific event detector
            assert(isa(subscriberHandle, 'function_handle'), 'Subscribers must be supplied as a function handle!');
            obj.numSubscribers = obj.numSubscribers + 1;
            obj.eventSubscribers{obj.numSubscribers} = subscriberHandle;
            % If input arguments are present, convert from name-value pairs
            % to struct
            if ~isempty(varargin)
                if strcmp(varargin{1}, 'returnMessage')
                    startInd = 3;
                    obj.subscriberReturnMessages{end + 1} = varargin{2};
                else
                    startInd = 1;
                    obj.subscriberReturnMessages{end + 1} = [];
                end
                obj.subscriberArgs{obj.numSubscribers} = obj.parseInputsToStruct(varargin{startInd:end});
            end
        end
        
        function setRunFunction(obj, runFunctionHandle)
            % Sets the run function handle of the event
            assert(isa(runFunctionHandle, 'function_handle'), 'Run functions must be supplied as a function handle!');
            if ~isempty(obj.runFunctionHandle)
                warning('Run function handle already set! Continuing to set new function handle...')
            end
            obj.runFunctionHandle = runFunctionHandle;
        end
        
        function setInitFunction(obj, initFunctionHandle)
            % Sets the initialization function of an event detector
            assert(isa(initFunctionHandle, 'function_handle'), 'Initialization functions must be supplied as a function handlea!');
            if ~isempty(obj.initFunctionHandle)
                warning('Initialization function handle already set! Continuing to set new Initialization handle...')
            end
            obj.initFunctionHandle = initFunctionHandle;
        end
        
        function init(obj)
            % Runs the initialization function, if needed
            if ~isempty(obj.initFunctionHandle)
                obj.initFunctionHandle();
            end
        end
    end
    
    methods (Access = private)
        function newStruct = parseInputsToStruct(obj, varargin) %#ok<INUSL>
            % Parses name-value pairs to a struct
            assert(mod(numel(varargin), 2) == 0, 'Must declare name-value pairs!');
            newStruct = struct();
            for i = 1:numel(varargin) / 2
                assert(isa(varargin{(i - 1) * 2 + 1}, 'char'));
                newStruct.(varargin{(i - 1) * 2 + 1}) = varargin{i * 2};
            end
        end
    end
    
end

