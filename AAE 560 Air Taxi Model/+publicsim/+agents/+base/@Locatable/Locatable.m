classdef Locatable < publicsim.sim.Callee
    %LOCATABLE: Agent type that should not move but has a location
    % This agent will automatically log its position initially
    %
    % setInitialState(position) sets the ECEF position
    %
    % setInitialState(position,orientation) sets the ECEF position and
    % orientation
    %
    % position=getPosition() returns the ECEF location/position
    
    
    properties(SetAccess=protected)
        spatial % Struct that defines the current state of the movable
    end
    
    properties(SetAccess=immutable)
        spatial_names = {'position','velocity','acceleration','orientation'}; % Names of a basic spatial
        spatial_struct = struct('position', [], 'velocity', [], 'acceleration', [], 'orientation', []); % Empty struct of a basic spatial
    end
    
    methods
        function obj=Locatable()
            
        end
        
        function setInitialState(obj,varargin)
            % Sets the spatial state and last update time to given values.
            % Takes input of position or position,orientation
            
%             if ~ischar(varargin{1})
%                 warning('Using deprecated input options! Please change to the new input parser!');
                position = varargin{1};
                
                if length(varargin) > 1
                    orientation = varargin{2};
                else
                    orientation = [0,0,0,0]; % TODO: Change to normal orientation from current ECEF?
                end
                velocity = [0, 0, 0];
                acceleration = [0, 0, 0];
%             else
%                 np = publicsim.util.inputParser();
%                 np.addParameter('DOF', 3);
%                 np.addRequired('position', @isnumeric);
%                 np.addParameter('velocity', []);
%                 np.addParameter('acceleration', []);
%                 np.addParameter('orientation', []);
%                 np.addParameter('angularVelocity', []);
%                 np.addParamter('angularAcceleration', []);
%                 np.parse(varargin{:});
%                 
%                 position = np.Results.position;
%                 if np.Results.DOF == 6
%                     % 6 DOF model, adjust the spatial names and struct
%                     obj.spatial_names = {'position','velocity','acceleration','orientation', 'angularVelocity', 'angularAcceleration'}; % Names of a basic spatial
%                     obj.spatial_struct = struct('position', [], 'velocity', [], 'acceleration', [], 'orientation', [], 'angularVelocity', [], 'angularAcceleration', []); % Empty struct of a basic spatial
%                 end
%                 
%                 for i = 1:numel(obj.spatial_names)
%                     if isempty(np.Results.(obj.spatialNames{i}))
%                         eval(sprintf('%s=zeros(1, np.Resutls.DOF);', obj.spatialNames{i}));
%                     else
%                         eval(sprintf('%s=np.Results.%s;', obj.spatialNames{i}, obj.spatialNames{i}));
%                     end
%                 end
%             end
            obj.spatial = obj.spatial_struct;
            obj.spatial.position = position;
            obj.spatial.velocity = velocity;
            obj.spatial.acceleration = acceleration;
            obj.spatial.orientation = orientation;
        end
        
        function v=getPosition(obj)
            % Returns the position
            if isa(obj,'publicsim.agents.hierarchical.Child')
                if isempty(obj.parent)
                    %In case a child is used, but not in the particular
                    %scenario
                    v=obj.spatial.position;
                else
                    v = obj.getNestedProperty('getPosition');
                end
                return
            end
            
            v=obj.spatial.position;
        end
        
        function v=getVelocity(obj) %#ok<MANU>
            % Returns velocity, always zero vector
            v=[0,0,0];
        end
        
        function v=getAcceleration(obj) %#ok<MANU>
            % Returns acceleration, always zero vector
            v=[0,0,0];
        end
        
        function v=getOrientation(obj)
            % Returns the orientation
            v=obj.spatial.orientation;
        end
        
        function addStates(obj)
            % Constructs the the empty spatial struct
            for i = 1:numel(obj.spatial_names)
                obj.spatial.(obj.spatial_names{i})=[];
            end
        end
        
    end
    
    methods (Static,Access=private)
        
        function addPropertyLogs(obj)
            % Adds periodic log for position, only logs once
            %period=2.0; [s]
            %obj.addPeriodicLogItems({'getPosition','getVelocity'},period);
            %obj.addPeriodicLogItems({'getAcceleration'},0.5);
            obj.addPeriodicLogItems({'getPosition'},inf);
        end
        
    end
    
    
    %%%% TEST METHDOS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.agents.base.Locatable.testOrient';
        end
    end
    
    methods (Static)
        function testOrient()
            % Tests orient utility
            import publicsim.util.orient.*;
            
            angle1 = rand() * 15 + 1;
            angle2 = rand() * 20 + 1;
            angle3 = rand() * 25 + 1;
            
            q1 = azEl2quat(angle1, 0, 0);
            q2 = azEl2quat(0, angle2, 0);
            q3 = azEl2quat(0, 0, angle3);
            
            q4 = multiplyQuats(q1, q2, q3);
            [prec, nut, spin] = quat2Euler(q4);
            assert(abs(prec - angle1) < 1e-10);
            assert(abs(nut - angle2) < 1e-10);
            assert(abs(spin - angle3) < 1e-10);
        end
    end
    
end

