classdef SteadyLevelFlight < publicsim.funcs.movement.StateManager
    %STEADYLEVELFLIGHT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        timestepMax=1.0; % [s] Maximum allowable time step during update
    end
    
    methods
        function obj = SteadyLevelFlight(varargin)
            obj=obj@publicsim.funcs.movement.StateManager();
        end
        
        function [new_state, start_state] = updateLocation(obj,current_state,time_offset)
            % Updates location to maintain SLF
            start_state=current_state; %Not quite sure why this is necessary
            %stateStruct=obj.mapCellToStruct(current_state);
            stateStruct=current_state;
            assert(all(ismember({'startLla','endLla','speed'},fieldnames(stateStruct))));
            
            if ~isfield(stateStruct,'earthModelType')
                stateStruct.earthModelType='elliptical';
            end
            
            if ~isfield(stateStruct,'earthModel')
                earth=publicsim.util.Earth();
                earth.setModel(stateStruct.earthModelType);
                stateStruct.earthModel=earth;
            end

            if ~isfield(stateStruct,'lastPositionEcef')
                stateStruct.lastPositionEcef=...
                    stateStruct.earthModel.convert_lla2ecef(stateStruct.startLla);
            end
            
            if ~isfield(stateStruct,'endPositionEcef')
                stateStruct.endPositionEcef=...
                    stateStruct.earthModel.convert_lla2ecef(stateStruct.endLla);
            end
            
            if ~isfield(stateStruct,'destTime')
                distance=stateStruct.earthModel.gcdist(...
                    stateStruct.startLla(1),stateStruct.startLla(2),...
                    stateStruct.endLla(1),stateStruct.endLla(2));
                stateStruct.destTime=distance/stateStruct.speed;
            end
            
            if ~isfield(stateStruct,'flightTime')
                stateStruct.flightTime=0;
                stateStruct.loitering=0;
            end
            
            
            usedOffset=0;
            directionEcef=[];
            while(usedOffset < time_offset && stateStruct.loitering==0)
                stepSize=min(time_offset-usedOffset,obj.timestepMax);
                usedOffset=usedOffset+stepSize;
                
                directionEcef=...
                    (stateStruct.endPositionEcef-stateStruct.lastPositionEcef)/...
                    norm(stateStruct.endPositionEcef-stateStruct.lastPositionEcef);
                movementEcef=directionEcef*stepSize*stateStruct.speed;
                movementEcef=stateStruct.lastPositionEcef+movementEcef;
                %stepStartLla=stateStruct.earthModel.convert_ecef2lla(stateStruct.lastPositionEcef);
                stepEndLla=stateStruct.earthModel.convert_ecef2lla(movementEcef);
                plannedAititude=(stateStruct.endLla(3)-stateStruct.startLla(3))*(stateStruct.flightTime/stateStruct.destTime)+stateStruct.startLla(3);
                stepEndLla(3)=plannedAititude; 
                stepEndEcef=stateStruct.earthModel.convert_lla2ecef(stepEndLla);
                
                %Re-calc based on altitude
                directionEcef=(stepEndEcef-stateStruct.lastPositionEcef)/...
                    norm(stepEndEcef-stateStruct.lastPositionEcef);
                
                
                movement=directionEcef*stepSize*stateStruct.speed;
                stateStruct.lastPositionEcef=stateStruct.lastPositionEcef+movement;
                
                stateStruct.flightTime=stateStruct.flightTime+stepSize;
                if stateStruct.flightTime >= stateStruct.destTime
                    stateStruct.loitering=1;
                end
            end
            
            stateStruct.position=stateStruct.lastPositionEcef;
            if isempty(directionEcef)
                directionEcef=...
                        (stateStruct.endPositionEcef-stateStruct.lastPositionEcef)/...
                        norm(stateStruct.endPositionEcef-stateStruct.lastPositionEcef);
            end
            stateStruct.velocity=directionEcef*stateStruct.speed; 
            stateStruct.acceleration=[0 0 0];
            stateStruct.orientation=[norm(stateStruct.velocity) 0]';
            
            new_state=stateStruct;
        end
    end
    
    methods (Static)
        
        function outStruct=mapCellToStruct(inCell)
            % Converts field-value cell arrays to a struct
            outStruct=struct();
            for i=1:numel(inCell)/2
                fieldName=inCell{2*i-1};
                fieldValue=inCell{2*i}; 
                outStruct.(fieldName)=fieldValue;
            end
        end
        
        function outCell=mapStructToCell(inStruct)
            % Converts structs to field-value cell arrays
            fNames=fieldNames(inStruct);
            outCell=cell(numel(fNames)*2,1);
            for i=1:numel(fNames)
                outCell{2*i-1}=fNames{i}; 
                outCell{2*i}=inStruct.(fNames{i}); 
            end
        end
    end
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.funcs.movement.SteadyLevelFlight.test_steadyLevelFlight';
        end
    end
    
    methods (Static)
        
        function test_steadyLevelFlight()
            % Tester for SteadyLevelFlight
            
            slaAgent=publicsim.agents.base.Movable();
            slaInst=publicsim.funcs.movement.SteadyLevelFlight();
            slaAgent.setMovementManager(slaInst);
            
            T = 60*60*2.1;  % total seconds
            dt = 2.3; % time step
            t = 0:dt:T;
            
            slaSpeed=440; %[m/s]
            
            slaAgent.setInitialState(t(1),{'startLla',[20 20 5000],'endLla',[40 40 8000],'speed',slaSpeed});
            
            earth=publicsim.util.Earth();
            earth.setModel('elliptical');
                
            positionLog=[];
            loiterLog=[];
            positionLogLla=[];
            for i = t
               slaAgent.updateMovement(i); 
               positionLog=[positionLog; slaAgent.spatial.position]; %#ok<AGROW>
               loiterLog=[loiterLog; slaAgent.spatial.loitering]; %#ok<AGROW>
               positionLogLla=[positionLogLla; earth.convert_ecef2lla(slaAgent.spatial.position)]; %#ok<AGROW>
            end
            
            figure; scatter3(positionLog(:,1),positionLog(:,2),positionLog(:,3));
            
            %not sure what to assert
        end
        
    end
    
    
end

