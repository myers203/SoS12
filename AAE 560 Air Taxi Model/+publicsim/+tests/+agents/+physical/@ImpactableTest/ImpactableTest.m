classdef ImpactableTest < publicsim.agents.base.Periodic & publicsim.agents.physical.Impactable
    %IMPACTABLETEST Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function obj = ImpactableTest(world)
            obj.world = world;
            % Define the movable
            movable = publicsim.funcs.movement.NewtonMotion();
            obj.setMovementManager(movable);
        end
        
        function init(obj)
            obj.scheduleAtTime(obj.movementLastUpdateTime); % Schedule first call update
            obj.initPeriodic(0.1); % Update every 0.1 seconds
        end
        
        function runAtTime(obj, time)
            if (obj.isDestroyed || obj.isImpacted())
                obj.instance.RemoveCallee(obj);
            end
            
            if obj.isRunTime(time)
                obj.updateMovement(time);
            end
        end
        
        function mass = getMass(obj, varargin)
            mass = 1;
        end
        
    end
    
    methods (Static)
        function test_impactable()
            % Create a world
            world = publicsim.util.Earth();
            world.setModel('elliptical');
            
            startTime = 0;
            endTime = 1000; % Will end before this (when impacted)
            
            % Get the impact altitude
            metaImpactable = ?publicsim.agents.physical.Impactable;
            idx = find(strcmp('impactAltitude', {metaImpactable.PropertyList.Name}));
            impactAltitude = metaImpactable.PropertyList(idx).DefaultValue;
            
            % Create an impactable with an initial state
            impactable = publicsim.tests.agents.physical.ImpactableTest(world);
            
            initLLA = [randi([-90, 90]), randi([-180, 180]), randi([50, 100])];
            initState.position = world.convert_lla2ecef(initLLA);
            initState.velocity = [0, 0, 0];
            initState.acceleration = [0, 0, 0];
            impactable.setInitialState(startTime, initState);
            % Now get gravitational acceleration, normalize to 9.81 m/s^2
            gravAccel = impactable.getGravity(0);
            gravAccel = 9.81 * (gravAccel / norm(gravAccel));
            initState.acceleration = gravAccel;
            impactable.setInitialState(startTime, initState);
            
            % Calculate the true time it should impact under a constant
            % -9.81 m/s^2 acceleration
            % a(t) = -9.81
            % v(t) = (-9.81 * t) + v_0
            % x(t) = (0.5 * -9.81 * t^2) + (t * v_0) + x_0
            % if v_0 = 0 and x_0 > 0:
            % => t(x) = sqrt((x - x_0) / (0.5 * -9.81))
            acceleration = -9.81; % m/s^2 towards center of Earth
            predictedImpactTime = sqrt((impactAltitude - initLLA(3)) / (0.5 * acceleration));
            predictedImpactPosition = world.convert_lla2ecef(initLLA  .* [1 1 0]);
            % Add to a sim and run
            simInst = publicsim.sim.Instance('tmp\test');
            simInst.AddCallee(impactable);
            simInst.runUntil(startTime, endTime);
            
            % Make sure it impacted
            assert(impactable.isImpacted() == 1, 'Did not impact the Earth!');
            
            % Make sure that the impact time and location is resonable
            assert(norm(predictedImpactTime - impactable.impactTime) < 0.1, 'Impact time error too great!');
            assert(norm(predictedImpactPosition - impactable.impactECEF) < 1, 'Impact position error too great!');
        end
    end
    
        %%%% TEST METHDOS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests = {};
        end
    end
    
    
end

