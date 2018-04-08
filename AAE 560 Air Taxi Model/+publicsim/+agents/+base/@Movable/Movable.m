classdef Movable < publicsim.agents.base.Locatable
    %MOVABLE: Agent type that is allowed to move
    %
    % position=getPosition() returns current position in ECEF
    % velocity=getVelocity() returns current velocity in ECEF-vector
    % acceleration=getAcceleration() returns current acceleration in ECEF
    %
    % setInitialState(struct) where struct has position, velocity,
    % acceleration as fields
    %
    % setInitialState(cell) where cell has: {'position',[position
    % values],...
    %
    % Movement Management:
    % setMovementManager(manager) movement manager is a funcs.movement
    % manager that controls the relationship between states
    %
    % setMovableId(id) set the unique ID for sensing/observing purposes and
    % other tracking needs
    %
    % updateMovement(time) advances the movable, automatically handled by
    % getPosition and used only by external managers
    
    properties(SetAccess=private)
        movementManager; % The movement manager that propogates movement, usually as a publicsim.funcs.movement.StateManager
        movementLastUpdateTime=-Inf; % [s] Last movement time
        movableId; % Settable ID for external manager reference
        orchestrationParams=struct('startLla',[],'stopLla',[]); % Parameters passed from orchestration, useful for movement overloading
        initialStateCalculated=0; % If the input state is not the same as the output state, then an initial update may be required
    end
    
    methods
        function obj=Movable(varargin)
            if nargin>1
                % if it takes an input, we'd like it to be a cell array of
                % strings describing the position-related states.
                % Position, velocity, and acceleration in cartesian
                % coordinates is required.
                
                assert(iscell(varargin{1}));
                assert(ischar(varargin{1}{1}));
                warning('The line after this should not work!');
                obj.spatial_names = [obj.spatial_names, sort(varargin{1})];
            end
        end
        
        function make6DOF(obj)
            extraStates = {'angularVelocity', 'angularAcceleration', 'orientation'};
            defaultStateValues = {[0, 0, 0], [0, 0, 0], [0, 0, 0, 0]};
            for i = 1:numel(extraStates)
                if ~isfield(obj.spatial, extraStates{i})
                    obj.spatial.(extraStates{i}) = defaultStateValues{i};
                end
            end
        end
        
        function v=getPosition(obj)
            % Returns the position at the current time
            if isa(obj,'publicsim.agents.hierarchical.Child')
               v = obj.getNestedProperty('getPosition');
               return;
            end
            
            time = obj.getCurrentTime();
            obj.updateMovement(time)
            v=obj.spatial.position;
        end
        
        function v=getVelocity(obj)
            % Returns the velocity at the current time
            if isa(obj,'publicsim.agents.hierarchical.Child')
               v = obj.getNestedProperty('getVelocity');
               return
            end
            
            time = obj.getCurrentTime();
            obj.updateMovement(time)
            v=obj.spatial.velocity;
        end
        
        function v=getAcceleration(obj)
            % Returns the acceleration at the current time
            if isa(obj,'publicsim.agents.hierarchical.Child')
               v = obj.getNestedProperty('getAcceleration');
               return
            end
            
            time = obj.getCurrentTime();
            obj.updateMovement(time)
            v=obj.spatial.acceleration;
        end
        
        function v=getOrientation(obj)
            % Returns the orientation
            if isa(obj,'publicsim.agents.hierarchical.Child')
               v = obj.getNestedProperty('getOrientation');
               return
            end
            
            time = obj.getCurrentTime();
            obj.updateMovement(time)
            v=obj.spatial.orientation;
        end
        
        function setMovableId(obj,id)
            % Set the movable ID to the given value
            obj.movableId=id;
        end
        
        function setMovementManager(obj,manager)
            % Sets the movement manager to the given manager
            obj.movementManager=manager;
        end
        
        function setInitialState(obj,time,state)
            % Sets the spatial state and last update time to given values
            if isa(state, 'cell')
                obj.setState(state);
            elseif isa(state, 'struct')
                assert(all(publicsim.util.struct.fastIsMember({'position','velocity','acceleration'},fieldnames(state))));
                %assert(sum(publicsim.util.struct.fastIsMember(fields(state), fields(obj.spatial_struct))) == numel(fields(state)));
                obj.spatial = state;
            end
            obj.movementLastUpdateTime=time;
            
        end
        
        function updateMovement(obj,targetTime)
            % Updates movement using the movement manager
            timeDiff=targetTime-obj.movementLastUpdateTime();
            assert(timeDiff >= 0, 'Movement backwards in time!');
            if timeDiff == 0 && obj.initialStateCalculated == 1
                return;
            end
            obj.movementLastUpdateTime=targetTime;
            [newState,oldState] = obj.movementManager.updateLocation(obj.spatial(),timeDiff); %#ok<ASGLU>
            if ~isempty(newState)
                obj.unpackState(newState);
            end
            obj.initialStateCalculated=1;
        end

        
        function unpackState(obj,newState)            
            % Sets and verifies the spatial to the new state
            
            %currentFields = fields(obj.spatial);
            newFields = fields(newState);
            %matches = 0;
            
            assert(all(publicsim.util.struct.fastIsMember(...
                {'position','velocity','acceleration'},...
                fieldnames(newState))),...
                'The movable needs to have these states at a minimum');
            
            %assert(numel(currentFields) == numel(newFields), 'New spatial struct is not the correct format');
            %PW: This does not allow new states to evolve in the model,
            %e.g. bearing speed and altitude to position, velocity, etc.
            
           % for i = 1:numel(currentFields)
                for j = 1:numel(newFields)
           %         if strcmp(currentFields{i}, newFields{j})
                        %obj.spatial.(currentFields{i}) = newState.(currentFields{i});
                        obj.spatial.(newFields{j}) = newState.(newFields{j});
           %             matches = matches + 1;
           %             break;
           %         end
                end
           % end
            
            %assert(matches == numel(currentFields), 'New spatial struct is not the correct format');
            %PW: see above comment
        end
        
        
        function setState(obj,newState)
            % Sets the spatial to the new state with minimal verification
            if isa(newState, 'cell')
                % same format of inputs for assigning entries to a structure.
                %check to make sure we have an even number of entries
                assert(~mod(numel(newState),2));
                
                %all the state names need to be in the list or we gonna have
                %problems later.
                name_idxs = 1:2:numel(newState);
                %assert(all(publicsim.util.struct.fastIsMember(newState(name_idxs),obj.spatial_names)));
                %PW: This artifically enforces a particular state model
                
                for i = name_idxs
                    obj.spatial.(newState{i})= newState{i+1};
                end
            elseif isa(newState, 'struct')
                assert(all(publicsim.util.struct.fastIsMember({'position','velocity','acceleration'},fieldnames(newState))));
                % assert(all(publicsim.util.struct.fastIsMember(fields(newState), fields(obj.spatial_struct)))); % Doesn't allow for adding
                % new fields
                obj.spatial = newState;
            end
            
        end
        
        function runAtTime(obj,~) %#ok<INUSD>
            % The method is meant to be overloaded
        end
        
        function setOrchestrationParams(obj,startLla,stopLla)
            obj.orchestrationParams.startLla=startLla;
            obj.orchestrationParams.stopLla=stopLla;
        end
        
    end
    
    
    
    methods (Static,Access=private)
        
        function addPropertyLogs(obj)
            % Adds periodic logs of position, velocity, and acceleration
            %period=2.0; [s]
            %obj.addPeriodicLogItems({'getPosition','getVelocity'},period);
            %obj.addPeriodicLogItems({'getAcceleration'},0.5);
            %obj.addPeriodicLogItems({'getPosition','getVelocity','getAcceleration'});
            obj.addPeriodicLogItems({'getPosition','getVelocity','getAcceleration'});
        end
        
    end
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.tests.agents.base.MovableTest.test_Movable';
        end
    end
    
    
end

