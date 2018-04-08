classdef ForcedMotion < publicsim.funcs.movement.NewtonMotion
    %FORCEDMOTION Simulates forced movement
    %   Simulates the movement of objects due to forces by integrating
    %   through time using Heun's method
    %   The "getMass" function is required by all objects that use this
    %   motion controller
    
    properties
        isFrozen = 0; % 0: Movement is allowed, 1: Movement is not allowed
        forceCalls = {}; % List of function handles to call from the parent to inform the movement
        parent; % The movable object
        maxIntegrationTimestep = 0.1; %[s] Maximimum amount of time allowed during integration
    end
    
    methods
        
        function obj = ForcedMotion(parent, calls, varargin)
            % Any string inputs shall be interpreted as getter functions to
            % call. The only numeric input shall be the last input
            % (optional) which shall define the number of movement
            % dimensions.
            %
            % All force calls shall return the force in the same cartesian
            % frame as a row vector
            
            % Have to use super constructor first
            nDims = [];
            if ~isempty(varargin)
                nDims = varargin{1};
            end
            
            % Call superclass constructor
            obj@publicsim.funcs.movement.NewtonMotion(nDims);
            
            % Set the parent object
            obj.parent = parent;
            
            % Get all functions handles to call during motion updates
            for i = 1:numel(calls)
                if isa(calls{i}, 'char')
                    obj.forceCalls{i} = calls{i}; % Store the function name to call
                else
                    obj.parent.disp_WARN('Invalid input arguments');
                end
            end
        end
        
        function freezeMovement(obj)
            % Freezes the movement of the parent object
            obj.isFrozen = 1;
        end
        
        function unfreezeMovement(obj)
            % Unfreezes the movement of the parent object
            obj.isFrozen = 0;
        end
        
        function [newState, inputOldState] = updateLocation(obj, inputOldState, timeOffset)
            % Update motion using Heun's method
            
            % Don't move if frozen
            if obj.isFrozen
                newState = inputOldState;
                return;
            end
            % Save time if no time update
            if (timeOffset == 0)
                newState = inputOldState;
                return;
            end
            
            % Set the total amount of time to integrate through
            totalTimeOffset = timeOffset;
            
            % Start time of the current integration loop
            startTime = obj.parent.movementLastUpdateTime - totalTimeOffset;
            
            % Start at the input state
            oldState = inputOldState;
            
            while (totalTimeOffset > 0) % Integrate until the complete time offset is run through
                % Limit integration step to max time step, but preserve total integration time
                timeOffset = min(totalTimeOffset, obj.maxIntegrationTimestep);
                totalTimeOffset = totalTimeOffset - timeOffset;
                startState = oldState;
                for iter = 1:2
                    mass = obj.parent.getMass(startTime + timeOffset);
                    assert(mass > 0, 'Objects with physical movement must have mass!');
                    
                    netForce = zeros(1, numel(oldState.position));
                    % Call each specified function to sum forces on the object for
                    % the current time
                    for i = 1:numel(obj.forceCalls)
                        netForce = netForce + obj.parent.(obj.forceCalls{i})(startTime + timeOffset * (iter - 1));
                    end
                    
                    startState.acceleration = netForce / mass;
                    [middleState{iter}, ~] = updateLocation@publicsim.funcs.movement.NewtonMotion(obj, startState, timeOffset); %#ok
                    obj.parent.setState(middleState{iter});
                end
                % Update state using Huen's method
                newState.acceleration = ((middleState{1}.acceleration + middleState{2}.acceleration) / 2);
                newState.velocity = (oldState.velocity + 0.5 * timeOffset * (startState.acceleration + newState.acceleration));
                newState.position = (oldState.position + 0.5 * timeOffset * (startState.velocity + newState.velocity));
                assert(~any(isnan(newState.position)), 'Bad movement');
                % Step to the current integration time
                startTime = startTime + timeOffset;
                % Remeber the current state for the next integration loop
                oldState = newState;
            end
        end
    end
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.funcs.movement.ForcedMotion.test_forcedMotion';
        end
    end
    
    methods (Static)
        
        function test_forcedMotion()
            % Tester for ForcedMotion
            tic;
            
            
            % Base case: Assume constant thrust, analytical integration
            % over time
            constThrust = 20; %randi([5, 20]); % Newtons (x, y, z)
            mass = 1; %randi([10, 20]); % kg
            acc = constThrust / mass;
            
            dt = 0.5;
            dt2 = dt / 10;
            time = 0:dt:20; %randi([10, 20]);
            time2 = 0:dt2:time(end);
            
            truePosition = 0.5 * acc * time.^2;
            trueVelocity = acc * time;
            
            % Compare against ForcedMotion controlled object
            fmObj = publicsim.tests.funcs.movement.ForcedMotionTest();
            extendedTime = 0:(dt2 / 2):(time(end) + dt);
            fmObj.thrust = ones(1, numel(extendedTime)) * constThrust;
            fmObj.thrustTime = extendedTime;
            fmObj.mass = ones(1, numel(extendedTime)) * mass;
            fmObj.massTime = extendedTime;
            initState.position = 0;
            initState.velocity = 0;
            initState.acceleration = 0;
            fmObj.setInitialState(0, initState);
            for i = 1:numel(time)
                fmObj.setTime(time(i));
                testPosition(i) = fmObj.getPosition();
                testVelocity(i) = fmObj.getVelocity();
            end
            
            % In this simple test case, numerical and analytical
            % integration should both be pretty much exact
            assert(max(abs(testVelocity - trueVelocity)) < 1e-10, 'Velocity propogation mismatch');
            assert(max(abs(testPosition - truePosition)) < 1e-10, 'Position propogation mismatch');
            
            
            % Second test: Linearly vary thrust with time
            
            const = randi([5, 10]);
            var = randi([1, 3]) / 5;
            const = 10;
            var = 1;
            % thrust = const + var * time
            
            
            thrust = [];
            freq = 1 * pi;
            for i = 1:numel(extendedTime)
                thrust(i) = -freq^2 * sin(extendedTime(i) * freq);
            end
            
            trueVelocity = [];
            truePosition = [];
            
            for i = 1:numel(time)
                trueVelocity(i) = freq * cos(time(i) * freq);
                truePosition(i) = sin(time(i) * freq);
            end
            
            for i = 1:numel(time2)
                trueVelocity2(i) = freq * cos(time2(i) * freq);
                truePosition2(i) = sin(time2(i) * freq);
            end
            
            fmObj = publicsim.tests.funcs.movement.ForcedMotionTest();
            fmObj.thrust = thrust;
            fmObj.thrustTime = extendedTime;
            fmObj.mass = ones(1, numel(extendedTime)) * mass;
            fmObj.massTime = extendedTime;
            %fmObj.dragCoef = -1;
            initState.position = 0;
            initState.velocity = freq;
            initState.acceleration = 0;
            fmObj.setInitialState(0, initState);
            
            
            
            fmObj2 = publicsim.tests.funcs.movement.ForcedMotionTest();
            fmObj2.thrust = thrust;
            fmObj2.thrustTime = extendedTime;
            fmObj2.mass = ones(1, numel(extendedTime)) * mass;
            fmObj2.massTime = extendedTime;
            %fmObj2.dragCoef = -1;
            fmObj2.setInitialState(0, initState);
            
            for i = 1:numel(time)
                fmObj.setTime(time(i));
                testPosition(i) = fmObj.getPosition();
                testVelocity(i) = fmObj.getVelocity();
            end
            
            for i = 1:numel(time2)
                fmObj2.setTime(time2(i));
                testPosition2(i) = fmObj2.getPosition();
                testVelocity2(i) = fmObj2.getVelocity();
            end
            
            % Debug stuff
            %                 figure;
            %                 hold on;
            %                 plot(time2, truePosition2);
            %                 plot(time, testPosition, '--');
            %                 plot(time2, testPosition2, '--');
            %                 legend('True', 'Test 2', 'Test 2');
            %                 xlabel('Time (s)');
            %                 ylabel('Position (m)');
            %                 title('Variable Thrust: Position');
            %
            %                 figure;
            %                 hold on;
            %                 plot(time2, trueVelocity2);
            %                 plot(time, testVelocity, '--');
            %                 plot(time2, testVelocity2, '--');
            %                 legend('True', sprintf('Test, dt = %0.2f', dt), sprintf('Test, dt = %0.2f', dt2));
            %                 xlabel('Time (s)');
            %                 ylabel('Velocity (m/s)');
            %                 title('Variable Thrust: Velocity');
            
            fprintf('Error at time step of %0.2f\n', dt);
            fprintf('--------------------------\n');
            fprintf('Maximum velocity error: %0.9f\n', max(abs(testVelocity - trueVelocity)));
            fprintf('Maximum position error: %0.9f\n\n', max(abs(testPosition - truePosition)));
            
            fprintf('Error at time step of %0.2f\n', dt2);
            fprintf('--------------------------\n');
            fprintf('Maximum velocity error: %0.9f\n', max(abs(testVelocity2 - trueVelocity2)));
            fprintf('Maximum position error: %0.9f\n', max(abs(testPosition2 - truePosition2)));
            toc;
        end
    end
    
end

