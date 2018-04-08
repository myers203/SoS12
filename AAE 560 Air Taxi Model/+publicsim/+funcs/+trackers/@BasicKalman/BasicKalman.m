classdef BasicKalman < publicsim.funcs.trackers.Tracker
    %BASICKALMAN Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        
        function obj=BasicKalman(varargin)
            if  nargin < 1
                nStates=9;
            else
                nStates=varargin{1};
            end
            if  nargin > 1
                error('use initByState!')
            end
            obj=obj@publicsim.funcs.trackers.Tracker(nStates);
            
            positionError=1000;
            initPError=1e4;
            obj.buildInitialP(initPError);
            obj.buildInitialQ(positionError);
            obj.setMeasurementModel(@obj.linearMeasurementModel);
            obj.setProcessModel(@obj.linearProcessModel);
            obj.setInputType('ECEF');
        end
        
        function initByObs(obj,obsData)
            nObs = length(obsData.measurements);
            if nObs > 3
                nObs=3;
            end
            obj.x(1:nObs)=obsData.measurements(1:nObs);
            obj.t=obsData.time;
            
            %update Track Purity
            obj.updatePurity(obsData.trueId);
        end
        
        function initByState(obj,x0,P0,t)
            obj.x=x0;
            obj.P=P0;
            obj.t=t;
            obj.trackPurity = obj.trackPurity;
        end
        
        function [xh,Ph]=predict(obj,time)
            assert(time>=obj.t,'Negative time projection!');
            tDiff=time-obj.t;
            if isempty(obj.processModelFunction)
                obj.recoverDefaultFunctionHandles();
            end
            [xh,Ph]=obj.processModelFunction(tDiff);
        end
        
        function [xt,Ph] = addObservation(obj,obsData)
            
            
            observation = obsData.measurements;
            observation = observation(1:3);
            time = obsData.time;
            noise = obsData.errors;
            noise=noise(1:3);
            
            obj.applyProcessNoiseEvent(time);
            [xh,Ph]=obj.predict(time);
            noise=diag(noise.^2,0);
            H=obj.measurementModelFunction();
            K=Ph*H'/(noise+H*Ph*H');
            if size(observation,1) < size(observation,2)
                observation=observation';
            end
            xt=xh+K*(observation-H*xh);
            Ph=Ph-K*H*Ph;
            
            obj.x=xt;
            obj.P=Ph;
            obj.t=time;

            %update Track Purity
            obj.updatePurity(obsData.trueId);
        end
        
        function [x,P]=getPositionAtTime(obj,time)
            [x,P]=obj.predict(time);
        end
        
    end
    
    methods(Static)
        
        %publicsim.funcs.trackers.BasicKalman.test_BasicKalman()
        function test_BasicKalman()
            n_dims=3;
            movable=publicsim.funcs.movement.NewtonMotion(n_dims);
            movable.setInitialState([10 10 10],[1 1 1],[-0.3 0.5 0.25]);
            
            numStates=9;
            processNoise=0.01;
            numObs=100;
            tDiff=1.1337;
            noise=1;
            observations=zeros(numObs,3);
            times=0:tDiff:tDiff*(numObs-1);
            actualState=zeros(numObs,numStates);
            
            for i=1:numObs
                observations(i,:)=movable.getLocation();
                actualState(i,:)=[movable.getLocation movable.getVelocity movable.getAcceleration];
                movable.updateLocation(tDiff);
            end
            
            
            startTime=times(1);
            bk=publicsim.funcs.trackers.BasicKalman(numStates);
            bk.initState(observations(1,:),startTime);
            
            stateHistory=zeros(numObs,numStates);
            stateHistory(1,:)=bk.getPositionAtTime(times(1));
            projectHistory=zeros(numObs,numStates);
            projectHistory(1,:)=bk.predict(times(1)+5);
            errorHistory=[];
            
            for i=2:numObs
                [~,Pt]=bk.addObservation(observations(i,:)+randn(1,3)*noise,[noise noise noise],times(i));
                dp=diag(Pt);
                errorHistory(end+1)=sqrt(sum(dp(1:3).^2)); %#ok<AGROW>
                stateHistory(i,:)=bk.getPositionAtTime(times(i));
                projectHistory(i,:)=bk.predict(times(i)+5*tDiff);
            end
            
            finalError=actualState(end,:)-stateHistory(end,:);
            
            %assert(all(finalError(end-2:end)<processNoise),'Error larger than process noise!');
            
            %Plotting
            %{
            limitObs=1:numObs;
            figure;
            scatter3([actualState(limitObs,1); stateHistory(limitObs,1)] ,[actualState(limitObs,2); stateHistory(limitObs,2)] ,[actualState(limitObs,3);stateHistory(limitObs,3)],[],[ones(limitObs,1)*1; ones(limitObs,1)*2] );
            limitObs=1:25;
            figure;
            plot3([actualState(limitObs,1), stateHistory(limitObs,1)] ,[actualState(limitObs,2),stateHistory(limitObs,2)] ,[actualState(limitObs,3), stateHistory(limitObs,3)]);
            figure;
            idxShift=3;
            plot3([actualState(limitObs,1+idxShift), stateHistory(limitObs,1+idxShift)] ,[actualState(limitObs,2+idxShift),stateHistory(limitObs,2+idxShift)] ,[actualState(limitObs,3+idxShift), stateHistory(limitObs,3+idxShift)]);
            
            figure;
            plot3([actualState(limitObs+5,1),stateHistory(limitObs,1), projectHistory(limitObs,1)] ,[actualState(limitObs+5,2),stateHistory(limitObs,2),projectHistory(limitObs,2)] ,[actualState(limitObs+5,3),stateHistory(limitObs,3), projectHistory(limitObs,3)]);
            legend('Actual','0 s Projection','7 s Projection');
            
            figure;
            plot(errorHistory);
            %}
        end
    end
    
end

