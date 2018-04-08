classdef RailcarMotion < publicsim.funcs.movement.StateManager
    % Moves a platform using inputs from a file.
    properties (SetAccess = private)
        pathData % Position, velocity, and acceleration time series data
        parent % The movable object
    end
    
    methods
        function obj = RailcarMotion(parent)
            obj=obj@publicsim.funcs.movement.StateManager();
            obj.parent = parent;
        end
    end
    
    methods
        function setPathData(obj,path_data)
            % Sets the path data
            
            obj.pathData = path_data; % Set the path data
            
            % Schedule a run at the last time in the path data
            % This is so that, if it's not destroyed beforehand, the parent
            % has an opportunity to end itself according to whatever ended
            % the path data during generation (i.e. A missile will set its
            % last data point at impact with the world, but the time might
            % be non-integer and can easily be over-stepped)
            obj.parent.scheduleAtTime(obj.pathData.time(end));
            % Check if object is also periodic. If it is, add the time to OK
            % times
            supers = superclasses(obj.parent);
            if any(strncmp('publicsim.agents.base.Periodic', supers, numel('publicsim.agents.base.Periodic')))
                obj.parent.addOkTime(obj.pathData.time(end));
            end
            
        end
        
        function loadPathData(obj,file_name)
            % Loads the path data from the file name and sets the path data
            path_data_import = load(file_name);
            obj.setPathData(path_data_import);
        end
        
        function [newSpatial, oldSpatial] = updateLocation(obj, oldSpatial, timeDiff)
            % Updates the location to the given time from path data
            
            currentTime = obj.parent.getCurrentTime;
            if currentTime > obj.pathData.time(end)
                currentTime = obj.pathData.time(end); % if we ask for an update beyond the end time of the data, just use the endpoint.
            end
            
            newSpatial = obj.getStateAtTime(currentTime);
        end
        
        function newSpatial = getStateAtTime(obj, time)
            % Returns the spatial struct at the given time by interpolation
            assert(time <= obj.pathData.time(end), 'Cannot extrapolate path data');
            
            newSpatial.position = interp1q(obj.pathData.time, obj.pathData.position, time);
            newSpatial.velocity = interp1q(obj.pathData.time, obj.pathData.velocity, time);
            newSpatial.acceleration = interp1q(obj.pathData.time, obj.pathData.acceleration, time);
            
        end
    end
    
    methods(Static)
        function traj = generateLinearTrajectory(p1,p2,timeVector)
            % Creates a linear trajectory between two points through time
            
            % two ecef inputs.  Starting at p1 ending at p2.
            assert(size(p1,1)==1 && size(p2,1)==1);
            assert(size(p1,2)==size(p2,2));
            
            if size(timeVector,1)==1
                timeVector = timeVector';
            end
            
            assert(timeVector(1) == 0);
            assert(size(timeVector,2)==1);
            
            n_dims = size(p1,2);
            
            n_points = length(timeVector);
            increments = linspace(0,1,n_points);
            
            diff_vect = p2-p1;
            unit_vect = diff_vect/norm(diff_vect);
            diff_length=norm(diff_vect);
            
            start_mat = repmat(p1,n_points,1);
            diff_mat = repmat(unit_vect,n_points,1).*repmat(increments'*diff_length,1,n_dims);
            
            traj.position = start_mat+diff_mat;
            traj.velocity = repmat((p2 - p1) / (timeVector(end) - timeVector(1)), [size(traj.position, 1), 1]);
            traj.acceleration = zeros(size(traj.position));
            traj.time = timeVector;
        end
    end
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.funcs.movement.RailcarMotion.test_railcar()';
        end
    end
    
    methods (Static)
        function test_railcar()
            % Tester for RailcarMotion
            
            generate.startTime = 0;
            generate.endTime = generate.startTime + randi([20, 30]);
            startTime = generate.startTime + randi([1, 3]);
            endTime = 19.5; %0.5 + randi([15, 19]);
            
            startPos = rand(1, 3);
            endPos = 10 * rand(1, 3);
            
            import publicsim.*;
            
            movable = agents.base.Movable();
            simInst = sim.Instance('tmp\test');
            simInst.AddCallee(movable);
            movable.setMovementManager(funcs.movement.RailcarMotion(movable));
            movable.movementManager.setPathData(funcs.movement.RailcarMotion.generateLinearTrajectory(startPos,endPos,generate.startTime:generate.endTime));
            movable.setInitialState(0, {'position', startPos, 'velocity', [0, 0, 0], 'acceleration', [0, 0, 0]});
            
            simInst.runUntil(startTime, endTime);
            
            assert(norm(movable.spatial.position - (startPos + (movable.movementLastUpdateTime / (generate.endTime - generate.startTime)) * (endPos - startPos)))<=1e-10)
            disp('Passed Railcar Test!');
        end
    end
end

