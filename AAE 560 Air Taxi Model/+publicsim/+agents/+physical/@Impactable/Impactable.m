classdef Impactable < publicsim.agents.physical.Destroyable & publicsim.agents.physical.Worldly
    %IMPACTABLE Agent type which should be destroyed if it impacts the world
    
    properties (Access = private)
        timesImpacted = 0; % How many times the object has been recorded as impacted, rarely used
        impactAltitude = -1; % Altitude below which the object is considered impacted
    end
    
    properties (SetAccess=private,SetObservable)
        impacted = 0; % If the object is impacted or not. 0 => Not impacted, 1 => Impacted
        impactECEF = []; % ECEF location of impact
    end
    
    properties (SetAccess = private)
        impactTime = []; % Time of impact
        lastECEF = []; % Last known ECEF location
        lastTime = []; % Last known time
    end
    
    methods
        
        function obj = Impactable()
            % Constructor
        end
        
        function bool = isImpacted(obj)
            % Returns boolean if the object is impacted or not
            
            % Should be called by all inherited classes to check for impact
            obj.watchForImpact(); % Watch for impact, but impact logic handling may be preferred differently
            if (~obj.impacted && ~obj.isDestroyed)
                % Get the altitude
                lla = obj.world.convert_ecef2lla(obj.getPosition);
                altitude = lla(3);
                if (altitude < obj.impactAltitude) % Hit the ground, mark as impacted and destroy self. -1 to account for floating point error
                    obj.destroy;
                    obj.timesImpacted = obj.timesImpacted + 1;
                    if (obj.isDestroyed) % Account for destroy conditions
                        obj.impacted = 1;
                    end
                end
            end
            
            bool = obj.impacted;
        end
        
        function numTimesImpacted = getTimesImpacted(obj)
            % Returns the number of times an object has been recorded as impacted
            numTimesImpacted = obj.timesImpacted;
        end
        
        function watchForImpact(obj)
            % Checks to see if the object has impacted or not
            
            time = obj.getCurrentTime();
            if (time == obj.lastTime)
                return; % Already checked at this time
            end
            % When used during runAtTime, will record when and where the
            % missile impacts the world
            currECEF = obj.getPosition();
            llaCurr = obj.world.convert_ecef2lla(currECEF);
            if (llaCurr(3) < obj.impactAltitude) && isempty(obj.impactTime) && ~isempty(obj.lastECEF)
                % Calculate the impact point (not using interp1[q] for speed
                % reasons)
                llaLast = obj.world.convert_ecef2lla(obj.lastECEF);
                slope = (time - obj.lastTime) / (llaCurr(3) - llaLast(3));
                obj.impactTime = obj.lastTime + slope * -llaLast(3);
                
                slope = (currECEF - obj.lastECEF) / (time - obj.lastTime);
                obj.impactECEF = obj.lastECEF + slope * (obj.impactTime - obj.lastTime);
                % Log the impact
                obj.setLogLevel(5);
                obj.disp_INFO([class(obj), ' ID: ', num2str(obj.id), ' impacted at time ', num2str(obj.impactTime)]);
                obj.addDefaultLogEntry('spatial', obj.spatial);
            elseif isempty(obj.impactTime)
                obj.lastTime = time;
                obj.lastECEF = currECEF;
            end
        end
    end
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.tests.agents.physical.ImpactableTest.test_impactable';
        end
    end
    
    methods (Static)
        
    end
    
end

