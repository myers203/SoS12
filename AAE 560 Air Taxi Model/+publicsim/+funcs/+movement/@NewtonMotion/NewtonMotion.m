classdef NewtonMotion < publicsim.funcs.movement.StateManager
    % Moves an object using newton updates to position and velocity.
    properties
    end
    
    methods
        function obj = NewtonMotion(varargin)
            obj=obj@publicsim.funcs.movement.StateManager();
        end
    end
    
    methods
        
        function [new_state, start_state] = updateLocation(obj,current_state,time_offset) %#ok<INUSL>
            % Updates motion using simple integration
            
            start_state = current_state;
            
            X = current_state.position;
            V = current_state.velocity;
            A = current_state.acceleration;
            
            assert(all(~isempty([X,V,A])));
            
            X_new = X + V*time_offset + 1/2*A*time_offset^2;
            V_new = V + A*time_offset;
            
            new_state = struct('position',X_new,'velocity',V_new,'acceleration',A);
        end
    end
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.funcs.movement.NewtonMotion.test_newton';
        end
    end
    
    methods (Static)
        function test_newton()
            % Tester for NewtonMotion
            
            import publicsim.*;
            pos = [0,100,3];
            vel = [3,0,0];
            acc = [0,-10,1];
            
            particle = agents.base.Movable();
            manager = funcs.movement.NewtonMotion();
            particle.setMovementManager(manager);
            
            T = 10;  % total seconds
            dt = .1; % time step
            t = 0:dt:T;
            
            particle.setInitialState(t(1),{'position',pos,'velocity',vel,'acceleration',acc});
            
            for i = t
                particle.updateMovement(i);
            end
            
            end_pos = particle.spatial.position;
            true_end_pos = pos+vel*T+1/2*acc*T^2;
            
            error = norm(true_end_pos-end_pos);
            travel = norm(true_end_pos-pos);
            
            assert(error/travel <= 0.03);
            disp('Passed Newton Test!');
        end
    end
end

