classdef Destroyable < publicsim.agents.base.Movable
    %DESTROYABLE Agent type that can be destroyed
    
    properties (SetAccess = private)
        fh; % Optional function handle to check before destruction
    end
    
    properties (SetAccess=private,SetObservable)
        isDestroyed = 0; % 0 => Not destroyed, 1 => Destroyed
    end
    
    methods
        
        function obj = Destroyable()
            % Constructor
        end
        
        function destroy(obj, varargin)
            % Destroys the agent
            if ~isempty(obj.fh)
                if obj.fh()
                    obj.isDestroyed = 1;
                end
            else
                obj.isDestroyed = 1;
            end
            
            % Check for child objects
            if isa(obj, 'publicsim.agents.hierarchical.Parent')
                for i = 1:numel(obj.children)
                    if isa(obj.children{i}, 'publicsim.agents.physical.Destroyable')
                        obj.children{i}.destroy();
                    else
                        warning('Child ''%s'' of ''%s'' is not destroyable, may have unintended effects!', ...
                            class(obj.children{i}), class(obj));
                    end
                end
            end
        end
        
        function destroyAtTime(obj, time)
            % Schedules to destroy the object at a later time
            assert(time >= obj.getCurrentTime(), 'Cannot kill object in the past!');
            obj.scheduleAtTime(time, @obj.destroy);
        end
        
        function setDestroyableFH(obj, fh)
            % Sets the function handle to check on destroy()
            obj.fh = fh;
        end
        
        % Overload movable "get" functions
        
        function v = getPosition(obj)
            % Returns the position
            if ~obj.isDestroyed
                v = getPosition@publicsim.agents.base.Movable(obj);
            else
                v = obj.spatial.position;
            end
        end
        
        function v=getVelocity(obj)
            % Returns the velocity
            if ~obj.isDestroyed
                v = getVelocity@publicsim.agents.base.Movable(obj);
            else
                v = obj.spatial.velocity;
            end
        end
        
        function v=getAcceleration(obj)
            % Returns the acceleration
            if ~obj.isDestroyed
                v = getAcceleration@publicsim.agents.base.Movable(obj);
            else
                v = obj.spatial.acceleration;
            end
        end
    end
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.agents.physical.Destroyable.test_customDestroyableFunc';
            tests{2} = 'publicsim.tests.agents.physical.DestroyableTest.test_destroyableAgent';
        end
    end
    
    methods (Static)
        
        function test_customDestroyableFunc()
            % Test for Destroyable agent with a custom destroyable function 
            
            % Make sure we can set a custom function handle that determines
            % if an object can be destroyed or not
            
            % Create dummy destroyable type
            dummy = publicsim.agents.physical.Destroyable();
            isInvincible = 1;
            isDestroyable = 0;
            customFH = @all;
            
            startTime = 0;
            endTime = 60;
            notInvincibleTime = randi([10, 50]);
            isDestroyableTime = randi([10, 50]);
            for i = startTime:endTime
                time = i;
                if (time >= notInvincibleTime)
                    isInvincible = 0;
                end
                if (time >= isDestroyableTime)
                    isDestroyable = 1;
                end
                % Have to do this here to update values
                dummy.setDestroyableFH(customFH([~isInvincible, isDestroyable]));
                dummy.destroy();
                if (time < notInvincibleTime) || (time < isDestroyableTime)
                    assert(dummy.isDestroyed == 0, 'Destroyable type was destroyed before custom function call allowed destruction');
                else
                    assert(dummy.isDestroyed == 1, 'Destroyable type was not destroyed after custom function call allowed destruction');
                end
            end
            
        end
    end
end

