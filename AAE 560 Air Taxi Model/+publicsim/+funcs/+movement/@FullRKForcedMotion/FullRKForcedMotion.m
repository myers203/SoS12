classdef FullRKForcedMotion < publicsim.funcs.movement.StateManager
    %FULLRKFORCEDMOTION Simulates 6 DOF forced movement using RK4 integrator
    %   Simulates the movement of objects due to forces by integrating
    %   through time with an RK4 integrator in a 6 DOF environment.
    %
    %   The "getMass" and "getMoment" function is required by all objects 
    %   that use this motion controller
    
    properties (SetAccess = private)
        isFrozen = 0; % 0: Movement is allowed, 1: Movement is not allowed
        forceCalls = {}; % List of function handles to call from the parent to inform the movement
        % Returned data should be [linearForceVector, applicationPoint],
        % where applitcationPoint is optional. If not provided, the force
        % is assumed to act on the center of mass (no torque)
        parent; % The movable object
        maxIntegrationTimestep=0.1; % [s] max timestep for integration
    end
    
    properties (Access = private)
        requiredFcns = {'getMass', 'getMoment'};
        reqStates = {'position', 'velocity', 'acceleration', 'orientation', 'angularVelocity', 'angularAcceleration'};
    end
    
    methods
        
        function obj = FullRKForcedMotion(parent, calls, varargin)
            % Any string inputs shall be interpreted as getter functions to
            % call. The only numeric input shall be the last input
            % (optional) which shall define the number of movement
            % dimensions.
            %
            % All force calls shall return the force in the same cartesian
            % frame as a row vector
            
            % Call superclass constructor
            obj@publicsim.funcs.movement.StateManager();
            
            % Set the parent object
            obj.parent = parent;
            
            % Make sure the parent has the required functions
            for i = 1:numel(obj.requiredFcns)
                assert(ismethod(obj.parent, obj.requiredFcns{i}), ...
                    sprintf('Parent must have ''%s(obj, time)''  method!', obj.requiredFcns{i}));
            end
            
            % Make sure the parent has 6 DOF
            for i = 1:numel(obj.reqStates)
                if ~isfield(obj.parent.spatial, obj.reqStates{i})
                    if ismethod(obj.parent, 'make6DOF')
                        obj.parent.make6DOF();
                        assert(isfield(obj.parent.spatial, obj.reqStates{i}), 'Parent can not be made into a 6 DOF movable!');
                    end
                end
            end
           
            % Get all functions handles to call during motion updates
            for i = 1:numel(calls)
                if isa(calls{i}, 'char')
                    obj.forceCalls{i} = calls{i}; % Store the function name to call
                else
                    obj.parent.disp_WARN('Invalid input arguments');
                end
            end
        end
        
        % These functions just help keep things from moving when you want
        % to make sure they don't move
        function freezeMovement(obj)
            % Freezes the movement of the parent object
            obj.isFrozen = 1;
        end
        
        function unfreezeMovement(obj)
            % Unfreezes the movement of the parent object
            obj.isFrozen = 0;
        end
        
        function [newState, inputOldState] = updateLocation(obj, inputOldState, timeOffset)
            % Update motion using RK4 integration
            
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
            
            totalTimeOffset=timeOffset;
            startTime = obj.parent.movementLastUpdateTime-totalTimeOffset;
            oldState=inputOldState;
            while(totalTimeOffset > 0)
                
                timeOffset=min(totalTimeOffset,obj.maxIntegrationTimestep);
                totalTimeOffset=totalTimeOffset-timeOffset;
                
                
                
                % Calculate intermediate states
                
                
                
                % v_dot = F / m - omegaX * V
                % 
                % omega_dot = inv(I) * (M - omegaX * I * omega)
                % omega = [ p ]
                %         [ q ]
                %         [ r ]
                %
                % I = [ Ixx Ixy Ixz ]
                %     [ Ixy Iyy Iyz ]
                %     [ Ixz Iyz Izz ]
                %
                % omegaX = [ 0 -r  q ]
                %          [ r  0 -p ]
                %          [-q  p  0 ]
                %           
                
                % k1, beginning time of integration
                mass = obj.parent.getMass(startTime);
                Imat = obj.parent.getMoment(startTime);
                Iprinciple = [Imat(1, 1), Imat(2, 2), Imat(3, 3)];
                [netForce, netTorque] = obj.getForceAtTime(startTime, numel(oldState.acceleration));
                k1.acceleration = netForce / mass;
                k1.velocity = oldState.velocity;
                k1.position = oldState.position;
                k1.angularAcceleration = netTorque / Iprinciple; % TODO
                k1.angularVelocity = oldState.angularVelocity;
                k1.orientation = oldState.orientation;
                
                % k2, middile time of integration
                mass = obj.parent.getMass(startTime + timeOffset / 2);
                k2.velocity = k1.velocity + (timeOffset / 2) * k1.acceleration;
                k2.position = k1.position + (timeOffset / 2) * k1.velocity;
                % Set intermediate velocity
                tempState.position = oldState.position;
                tempState.velocity = k2.velocity;
                tempState.acceleration = k1.acceleration;
                obj.parent.setState(tempState);
                
                
                netForce = obj.getForceAtTime(startTime + timeOffset / 2, numel(oldState.acceleration));
                k2.acceleration = netForce / mass;
                
                % k3, middile time of integration
                mass = obj.parent.getMass(startTime + timeOffset / 2);
                k3.velocity = k1.velocity + (timeOffset / 2) * k2.acceleration;
                k3.position = k1.position + (timeOffset / 2) * k2.velocity;
                
                % Set intermediate velocity
                tempState.position = oldState.position;
                tempState.velocity = k3.velocity;
                tempState.acceleration = k2.acceleration;
                obj.parent.setState(tempState);
                
                netForce = obj.getForceAtTime(startTime + timeOffset / 2, numel(oldState.acceleration));
                k3.acceleration = netForce / mass;
                
                % k4, end time of integration
                mass = obj.parent.getMass(startTime + timeOffset);
                k4.velocity = k1.velocity + timeOffset * k3.acceleration;
                k4.position = k1.position + timeOffset * k4.velocity;
                
                % Set intermediate velocity
                tempState.position = oldState.position;
                tempState.velocity = k4.velocity;
                tempState.acceleration = k3.acceleration;
                obj.parent.setState(tempState);
                
                netForce = obj.getForceAtTime(startTime + timeOffset, numel(oldState.acceleration));
                k4.acceleration = netForce / mass;
                
                
                
                % Final results
                newState.acceleration = k4.acceleration; % Actual acceleration at new time
                newState.velocity = oldState.velocity + (timeOffset / 6) * (k1.acceleration + 2 * k2.acceleration + 2 * k3.acceleration + k4.acceleration);
                newState.position = oldState.position + (timeOffset / 6) * (k1.velocity + 2 * k2.velocity + 2 * k3.velocity + k4.velocity);
                startTime=startTime+timeOffset;
                oldState=newState;
            end
            assert(~any(isnan(newState.position)), 'Bad movement');
        end
        
        function [netForce, netTorque] = getForceAtTime(obj, time, nDim)
            % Gets the net force on the parent object at the given time
            netForce = zeros(1, 3);
            netTorque = zeros(1, 3);
            % Call each specified function to sum forces on the object for
            % the current time
            for i = 1:numel(obj.forceCalls)
                if nargout(obj.parent.(obj.forceCalls{i})) == 2
                    [aLinearForce, anAngularForce] = obj.parent.(obj.forceCalls{i})(time);
                else
                    aLinearForce = obj.parent.(obj.forceCalls{i})(time);
                    anAngularForce = [0, 0, 0];
                end
                netForce = netForce + aLinearForce;
                netTorque = netTorque + anAngularForce;
            end
        end
        
    end
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            import publicsim.tests.UniversalTester.*
            tests{1} = 'publicsim.funcs.movement.RKForcedMotion.test_RKForcedMotion';
        end
    end
    
    methods (Static)
        
        function test_RKForcedMotion
            % Tester for RKForcedMotion
            tic;
            
            % Base case: Assume constant thrust, analytical integration
            % over time
            constThrust = randi([5, 20]); % Newtons (x, y, z)
            mass = 1; %randi([10, 20]); % kg
            acc = constThrust / mass;
            
            dt = 0.2;
            dt2 = dt / 10;
            time = 0:dt:20; %randi([10, 20]);
            time2 = 0:dt2:time(end);
            
            truePosition = 0.5 * acc * time.^2;
            trueVelocity = acc * time;
            
            % Compare against ForcedMotion controlled object
            fmObj = publicsim.tests.funcs.movement.RKForcedMotionTest();
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
            
            fmObj = publicsim.tests.funcs.movement.RKForcedMotionTest();
            fmObj.thrust = thrust;
            fmObj.thrustTime = extendedTime;
            fmObj.mass = ones(1, numel(extendedTime)) * mass;
            fmObj.massTime = extendedTime;
            %fmObj.dragCoef = -1;
            initState.position = 0;
            initState.velocity = freq;
            initState.acceleration = 0;
            fmObj.setInitialState(0, initState);
            
            
            
            fmObj2 = publicsim.tests.funcs.movement.RKForcedMotionTest();
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

