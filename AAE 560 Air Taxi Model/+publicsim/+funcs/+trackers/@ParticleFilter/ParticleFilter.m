classdef ParticleFilter < publicsim.funcs.trackers.Tracker
% Based on tutorial 10, 
% Kalman and Particle filters
% by Orlande, Colaço, Dulikravich, Vianna, da Silva, da Fonseca, Fudym
% Matlab code in appendix for particle filter
% Samplinng Importance Resampling Algorithm
% see also Particle Filter Theory and Practice with Positioning
% Applications by Fredrik Gustafsson
    
    properties(SetAccess=private)
        P_w % weights
        X_est % state estimate
        X_P % particles
        P % covariance
        W % process noise in (x y z xdot ydot zdot xdotdot ydotdot zdotdot)
        V % measurement noise in (az el r)
        N % number of particles
        t % time
    end
    
    properties(SetAccess=immutable)
        nStates
    end
    
    methods
        function obj=ParticleFilter(nStates,varargin)
            % numStates,numParticles,processNoise,measurementNoise
            if nargin==4 
                obj.N=varargin{1};
                obj.W=varargin{2};
                obj.V=varargin{3};
            end
            assert(nStates==size(obj.W,2),'# of states is incompatible');
            obj.P_w=ones(obj.N,1)/obj.N;
            obj.nStates=nStates;
            obj.setInputType('AZELR');
        end
        
        function initByState(obj,x0,P0,time)
            % initialize filter
            obj.X_est=x0;
            obj.t=time;
            P_tmp=zeros(obj.nStates,obj.nStates);
            for p=1:obj.N
                d=randn(obj.nStates,1)'.*obj.W;
                obj.X_P(p,:)=obj.X_est+d;
                P_tmp=P_tmp+d'*d/obj.N;
            end
            obj.P=P_tmp;
        end
                
        function [x,P] = addObservation(obj,obsData)
            observation = obsData.measurements';
            measNoise       = obsData.errors;
            time        = obsData.time;
            sensorPos = obsData.sensorPosition';
            % advancing particles
            tDiff=time-obj.t;
            F=diag(ones(obj.nStates,1),0);
            if obj.nStates>3
                F=F+diag(ones(obj.nStates-3,1)*tDiff,3);
            end
            if obj.nStates>6
                F=F+diag(ones(obj.nStates-6,1)*tDiff^2/2,6);
            end
            obj.t=time;           
            for p=1:obj.N
                % step 1. Predict the particles one step forward
                obj.X_P(p,:)=(F*obj.X_P(p,:)')'+randn(obj.nStates,1)'.*obj.W;
                ZDiff=publicsim.funcs.trackers.ParticleFilter.cart2azelr(...
                    obj.X_P(p,1:3),obj.X_P(p,4:6),sensorPos)-observation;
                % step 2. Compute the importance weights
                q=exp(-0.5*(sum((ZDiff./measNoise).*(ZDiff./measNoise))));
                obj.P_w(p)=q;
            end
            if sum(obj.P_w)<1e-12
                disp(['Weights close to zero at t=',num2str(obj.t),' !!!']);
                return;
            end
            obj.P_w=obj.P_w/sum(obj.P_w); % Normalize the importance weights
            % update estimate
            obj.X_est=obj.P_w'*obj.X_P;
            % step 3. Resample
            index = publicsim.funcs.trackers.ParticleFilter.sysresample(obj.P_w); 
            obj.X_P=obj.X_P(index,:);
            for p=1:obj.N
                d=obj.X_P(p,:)-obj.X_est;
                obj.P=obj.P+d'*d/obj.N;
            end
            x=obj.X_est;
            P=obj.P;
        end      
        function output=serialize(obj)
            dataObject=[];
            proplist=properties(obj);
            for i=1:numel(proplist)
                dataObject.(proplist{i})=obj.(proplist{i});
            end
            output=getByteStreamFromArray(dataObject);
        end
    end
    
    methods(Static)
        
        function obj=deserialize(input)
            dataObject=getArrayFromByteStream(input);
            obj=publicsim.funcs.trackers.ParticleFilter(dataObject.nStates);
            dataObject=rmfield(dataObject,'nStates');
            proplist=fields(dataObject);
            for i=1:numel(proplist)
                obj.(proplist{i})=dataObject.(proplist{i});
            end
        end
       %publicsim.funcs.trackers.ParticleFilter.test_ParticleFilter()
        function i=sysresample(q)
            qc=cumsum(q);
            M=length(q);
            u=([0:M-1]+rand(1))/M;
            i=zeros(1,M);
            k=1;
            for j=1:M
                while (qc(k)<u(j))
                    k=k+1;
                end
                i(j)=k;
            end
        end
        
        function azelr = add_meas_err (azelr0, sd_azelr0)
            az=azelr0(1);
            el=azelr0(2);
            r=azelr0(3);
            rdot=azelr0(4);
            sd_az=sd_azelr0(1);
            sd_el=sd_azelr0(2);
            sd_r=sd_azelr0(3);
            sd_rdot=sd_azelr0(4);
            r = r+randn*sd_r;
            az = az+randn*sd_az;
            el = el+randn*sd_el;
            rdot = rdot+randn*sd_rdot;
            azelr=[az el r rdot];
        end

        function azelr = cart2azelr(pos,vel,pos_sensor)
            x=pos(1);
            y=pos(2);
            z=pos(3);
            xdot = vel(1);
            ydot = vel(2);
            zdot = vel(3);
            x_sensor=pos_sensor(1);
            y_sensor=pos_sensor(2);
            z_sensor=pos_sensor(3); 
%            [az, el, r] = cart2sph (x - x_sensor, y - y_sensor, z - z_sensor);
            r = sqrt ((x - x_sensor) ^ 2 + (y - y_sensor) ^ 2 + (z - z_sensor) ^ 2);
            el = acosd ((z - z_sensor) / r);
            az = atan2d (y - y_sensor, x - x_sensor);
            rdot = ((x - x_sensor) * xdot + (y - y_sensor) * ydot + ...
                (z - z_sensor) * zdot) / r;
            azelr=[az el r rdot];
        end        

        function xyz = azelr2cart(azelr,pos_sensor)
            az=azelr(1);
            el=azelr(2);
            r=azelr(3);
            rdot=azelr(4);
            x_sensor=pos_sensor(1);
            y_sensor=pos_sensor(2);
            z_sensor=pos_sensor(3); 
%            [x_tmp, y_tmp, z_tmp] = sph2cart (az, el, r);
            x_tmp = r * sind (el) * cosd (az);
            y_tmp = r * sind (el) * sind (az);
            z_tmp = r * cosd (el);
            x = x_sensor + x_tmp;
            y = y_sensor + y_tmp;
            z = z_sensor + z_tmp;
            xdot = rdot * sind (el) * cosd (az);
            ydot = rdot * sind (el) * sind (az);
            zdot = rdot * cosd (el);
            xyz=[x y z xdot ydot zdot];
        end

        function test_ParticleFilter()           
            movable=publicsim.agents.test.SensorTarget();
            manager = publicsim.funcs.movement.NewtonMotion();
            movable.setMovementManager(manager);            
            movable.setInitialState(0,struct('position',[10 10 10],'velocity',...
                [1 1 500],'acceleration',[0 0 -10]));
            
            numObs=100;
            tDiff=1;
            measNoise=[0.01 0.01 5 0.1];
            procNoise=[0,0,0,0,0,0,1,1,1];
            numStates=length(procNoise);
            numMeasStates=length(measNoise);
            trueObservations=zeros(numObs,numMeasStates);
            times=0:tDiff:tDiff*(numObs-1);
            trueState=zeros(numObs,numStates);
            sensorPos=[100 50 0];
            
            for i=1:numObs
                trueObservations(i,:)=...
                    publicsim.funcs.trackers.ParticleFilter.cart2azelr(...
                    movable.spatial.position,movable.spatial.velocity,sensorPos);
                trueState(i,:)=[movable.spatial.position movable.spatial.velocity ...
                    movable.spatial.acceleration];
                if i==50
                    movable.setInitialState(tDiff*(i-1),struct(...
                        'position',movable.spatial.position,...
                        'velocity',movable.spatial.velocity,...
                        'acceleration',movable.spatial.acceleration+[0 1 0]));
                end
                if i==60
                    movable.setInitialState(tDiff*(i-1),struct(...
                        'position',movable.spatial.position,...
                        'velocity',movable.spatial.velocity,...
                        'acceleration',movable.spatial.acceleration+[0 -1 0]));
                end
                movable.updateMovement(tDiff*i);
            end
            limitObs=1:numObs;
            figure;
            plot3(trueState(limitObs,1),trueState(limitObs,2),...
                trueState(limitObs,3),'b');
            xlim([min([trueState(:,1)]) max([trueState(:,1)])]);
            ylim([min([trueState(:,2)]) max([trueState(:,2)])]);
            zlim([min([trueState(:,3)]) max([trueState(:,3)])]);
            
            
            startTime=times(1);
            pf=publicsim.funcs.trackers.ParticleFilter(numStates,1000000,...
                procNoise,measNoise);
            pf.initState(trueState(1,:),startTime);            
            observations=zeros(numObs,numMeasStates);
            posvel=zeros(numObs,6);
            stateHistory=zeros(numObs,numStates);
            stateHistory(1,:)=trueState(1,:);
            for i=1:numObs
                observations(i,:)=...
                    publicsim.funcs.trackers.ParticleFilter.add_meas_err(...
                    trueObservations(i,:),measNoise);
                posvel(i,:)=...
                    publicsim.funcs.trackers.ParticleFilter.azelr2cart(...
                    observations(i,:),sensorPos);
            end
%            limitObs=1:numObs;
%            figure;
%            plot3(trueState(limitObs,1),trueState(limitObs,2),...
%                trueState(limitObs,3),'b');
%            hold on;
%            plot3(posvel(limitObs,1),posvel(limitObs,2),...
%                posvel(limitObs,3),'r');
%            hold on;
%            plot3(sensorPos(1),sensorPos(2),sensorPos(3),'g');
%            xlim([min([trueState(:,1);posvel(:,1)]) max([trueState(:,1);posvel(:,1)])]);
%            ylim([min([trueState(:,2);posvel(:,2)]) max([trueState(:,2);posvel(:,2)])]);
%            zlim([min([trueState(:,3);posvel(:,3)]) max([trueState(:,3);posvel(:,3)])]);
            
            for i=2:numObs
                [x,P]=pf.addObservation(observations(i,:),measNoise,times(i),sensorPos);
                stateHistory(i,:)=x;
            end          
            limitObs=1:numObs;
            figure;
            plot3(trueState(limitObs,1),trueState(limitObs,2),...
                trueState(limitObs,3),'b');
            hold on;
            plot3(posvel(limitObs,1),posvel(limitObs,2),...
                posvel(limitObs,3),'r');
            hold on;
            plot3(stateHistory(limitObs,1),stateHistory(limitObs,2),...
                stateHistory(limitObs,3),'y');
            xlim([min([trueState(:,1);posvel(:,1);stateHistory(:,1)])...
                max([trueState(:,1);posvel(:,1);stateHistory(:,1)])]);
            ylim([min([trueState(:,2);posvel(:,2);stateHistory(:,2)])...
                max([trueState(:,2);posvel(:,2);stateHistory(:,2)])]);
            zlim([min([trueState(:,3);posvel(:,3);stateHistory(:,3)])...
                max([trueState(:,3);posvel(:,3);stateHistory(:,3)])]);
            err=zeros(numObs,1);
            for i=1:numObs
                err(i,1)=sqrt(sum((stateHistory(i,1:3)-trueState(i,1:3)).^2));
            end
            figure;
            plot(err);
        end
    end
    
end

