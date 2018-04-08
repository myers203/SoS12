classdef MParticleFilter < publicsim.funcs.trackers.Tracker
% Based on Marginalized Particle Filters for Mixed
% Linear/Nonlinear State-Space Models
% Thomas Schön, Fredrik Gustafsson, and Per-Johan Nordlund
% model 3 with C=0,f^l=0,G^l=1,G^n=1
% The Gaussian noise assumption can be relaxed 
% Since the measurement equation (18c) does not depend
% on the linear state variables or C=0, the measurement noise 
% can be arbitrarily distributed. In this case, (18c) does
% not contain any information about the linear state variables and,
% hence, cannot be used in the Kalman filter. It is solely used in the
% particle filter part of the algorithm, which can handle all probability 
% density functions.
% When
% y_t - az,el,r
% x_t^n - x,y,z 
% x_t^l - velocity,acceleration
% f_t^n (fn) - identity
% A_t^n (An) - pos'=pos+v*dt+a*dt^2/2
% G_t^n - identity
% f_t^l - zero
% A_l^t (Al) - v'=v+a*t,a'=a
% G_t^l - identity
% h_t - ecef2azelr
% C_t - zero
% see also 
% The Marginalized Particle Filter in Practice
% Thomas B. Schon, Rickard Karlsson and Fredrik Gustafsson
    properties(SetAccess=private)
        fm % process model
        N % number of particles
        q % weights
        xnp % nonlinear states of particles
        xlp % linear states of particles
        Plp % covariance for linear states of particles
        nlin % index of nonlinear states
        lin % index of linear states
        iAl % index for A1
        info % divergence indicator
        initq=0.1;
        initPError=1;
        neff=0.5;
        model=2;
        processNoiseModel=2;
        nMeasurementStates
    end
        
    methods
        function xnew=processModel(obj,dt,xx)
            if obj.model==1
                F=obj.fm(dt);
                xnew=F*xx;
            else
                [gx,gy,gz]=publicsim.funcs.trackers.UKF.J2(xx(1),xx(2),xx(3));
                acc=[gx;gy;gz];
                xnew(1:3)=xx(1:3)+xx(4:6)*dt+xx(7:9)*dt^2/2;
                xnew(4:6)=xx(4:6)+xx(7:9)*dt;
                xnew(7:9)=acc;
            end
        end
        function fn=processModelfn(obj,dt,xx)
            if obj.model==1
                F=obj.fm(dt);
                fn=F(obj.nlin,obj.nlin)*xx;
            else
                if obj.nMeasurementStates==3
                    fn=zeros(3,1);
                    fn(1:3,1)=xx(1:3)';
                else
                    fn=zeros(6,1);
                    fn(1:3,1)=xx(1:3)'+xx(4:6)'*dt;
                    fn(4:6,1)=xx(4:6)';
                end
            end
        end
        function An=processModelAn(obj,dt,xx)
            if obj.model==1
                F=obj.fm(dt);
                An=F(obj.nlin,obj.lin);
            else
                if obj.nMeasurementStates==3
                    An = [[dt,0,0,dt^2/2,0,0];
                          [0,dt,0,0,dt^2/2,0];
                          [0,0,dt,0,0,dt^2/2]];
                else
                    An = [[dt^2/2,0,0];
                          [0,dt^2/2,0];
                          [0,0,dt^2/2];
                          [dt,0,0];
                          [0,dt,0];
                          [0,0,dt]];
                end
            end
        end
        function fl=processModelfl(obj,dt,xx)
            if obj.model==1
                F=obj.fm(dt);
                fl=F(obj.lin,obj.nlin)*xx;
            else
                [gx,gy,gz]=publicsim.funcs.trackers.UKF.J2(xx(1),xx(2),xx(3));
                acc=[gx;gy;gz];
                if obj.nMeasurementStates==3
                    fl = [0;0;0;acc];
                else
                    fl = acc;
                end
            end
        end
        function Al=processModelAl(obj,dt,xx)
            if obj.model==1
                F=obj.fm(dt);
                Al=F(obj.lin,obj.lin);
            else
                if obj.nMeasurementStates==3
                    Al = [[1,0,0,dt,0,0];
                          [0,1,0,0,dt,0];
                          [0,0,1,0,0,dt];
                          zeros(3,6)];
                else
                    Al = zeros(3,3);
                end
            end
        end
        function Q=buildProcessNoise(obj,dt)
            if obj.processNoiseModel==1
                % continuous white noise
                qq = obj.qtilda*[[(dt^5)/20, (dt^4)/8, (dt^3)/6];...
                    [ (dt^4)/8, (dt^3)/3, (dt^2)/2];...
                    [ (dt^3)/6, (dt^2)/2, dt]];
            else
                % discrete white noise
                qq = obj.qtilda*[[.25*dt^4, .5*dt^3, .5*dt^2];...
                       [ .5*dt^3,    dt^2,       dt];...
                       [ .5*dt^2,       dt,        1]];
            end
            Q=zeros(obj.nStates,obj.nStates);
            for i=1:(obj.nStates/3)
                for j=1:(obj.nStates/3)
                    Q(3*(i-1)+1,3*(j-1)+1)=qq(i,j);
                    Q(3*(i-1)+2,3*(j-1)+2)=qq(i,j);
                    Q(3*(i-1)+3,3*(j-1)+3)=qq(i,j);
                end
            end
        end
        function obj=MParticleFilter(varargin)
            if nargin >= 1
                nStates=varargin{1};
            else
                nStates=9;
            end
            if nargin >= 2
                nMeasurementStates=varargin{2};
            else
                nMeasurementStates=3;
            end
            if nargin >= 3
                N=varargin{3};
            else
                N=1000;
            end
            obj=obj@publicsim.funcs.trackers.Tracker(nStates);
            obj.buildInitialP(obj.initPError);
            obj.buildInitialQ(obj.initq);
            obj.nMeasurementStates=nMeasurementStates;
            obj.N=N;
            obj.setInputType('AZELR');
            obj.fm=@obj.buildLinearModelMatrix;
            if obj.nMeasurementStates==3
                obj.nlin = 1:3;
                obj.lin = 4:9;
            else
                obj.nlin = 1:6;
                obj.lin = 7:9;
            end
        end
        function initByObs(obj,obsData)
            [observation, sensorPosition, measurementNoise] = obj.parseObservation(...
                obsData);
            obj.t=obsData.time;
            %update Track Purity
            obj.updatePurity(obsData.trueId);
            [xf, Pf] = obj.initialStateEstimate(observation, ...
                measurementNoise, sensorPosition);
            obj.initialize(xf,Pf);
            obj.importanceWeights(observation, measurementNoise, sensorPosition);
            obj.normalizeImportanceWeights();
            [xf, Pf] = obj.stateEstimate();
            obj.x = xf;
            obj.P = Pf;
        end
        function initByState(obj,x0,P0,t)
            obj.x=x0;
            obj.P=P0;
            obj.t=t;
            obj.trackPurity = obj.trackPurity;
        end

        function [xf,Pf] = addObservation(obj,obsData)
            if obsData.time==obj.t
                disp(['not a new observation']);
                xf = obj.x;
                Pf = obj.P;
                return
            end
            if obsData.time<obj.t
                disp(['stale observation']);
                xf = obj.x;
                Pf = obj.P;
                return
            end
            [observation, sensorPosition, measurementNoise] = obj.parseObservation(...
                obsData);
            time = obsData.time;
            obj.applyProcessNoiseEvent(time);
            tDiff = time - obj.t;
            obj.t = time;
            obj.advance(tDiff);
            obj.importanceWeights (observation, measurementNoise, sensorPosition);
            if sum(obj.q)>1e-12
                obj.normalizeImportanceWeights();
                obj.resample();
            else
                disp(['Weights close to zero at t=',num2str(obj.t),' restarting!']);
                [xf, Pf] = obj.initialStateEstimate(observation, ...
                    measurementNoise, sensorPosition);
                obj.initialize(xf, Pf);
                obj.importanceWeights(observation, measurementNoise, sensorPosition);
            end
            [xf, Pf] = obj.stateEstimate();
        end          
        function importanceWeights (obj, observation, measurementNoise, ...
                sensorPosition)
            R = diag(measurementNoise.^2);
            yhat = zeros(obj.nMeasurementStates, obj.N);
            for i=1:obj.N
                yhat(:, i) = obj.cart2azelr(obj.xnp(:, i), sensorPosition);
            end
            e = repmat(observation, 1, obj.N) - yhat;
            % (2) Compute the importance weights according to eq. (25a)
            for i=1:obj.N
                obj.q(i,1) = exp(-(1/2) * (e(:,i)' * (R \ e(:,i))));
            end
        end
        function normalizeImportanceWeights(obj)
            % Normalize the importance weights
            obj.q = obj.q/sum(obj.q);
        end
        function resample(obj)
            % Compute number of effective particles
            n_eff = 1/sum(obj.q.^2);
%            disp(['Effective sample size ',num2str(floor(n_eff))]);
            if n_eff < obj.N*obj.neff
                disp(['Resample at ', num2str(obj.t)]);
                % 3. Resample N particles with replacement
                index = ...
                    publicsim.funcs.trackers.MParticleFilter.sysresample(obj.q);     
                % Resampled nonlinear particles
                obj.xnp = obj.xnp(:,index); 
                % Resampled linear particles
                obj.xlp = obj.xlp(:,index);
                % Resampled covariance matrices for linear states
                obj.Plp = obj.Plp(:,:,index); 
            end
        end
        function advance(obj, tDiff)
            Q = obj.buildProcessNoise(tDiff);
            Qn = Q(obj.nlin,obj.nlin);
            Ql = Q(obj.lin,obj.lin);
            % (4b) Particle filter time update (prediction) according to Eq. (25b)
            xnf = obj.xnp;
            for i = 1:obj.N
                fn = obj.processModelfn(tDiff, xnf(:, i));
                An = obj.processModelAn(tDiff, xnf(:, i));
                Al = obj.processModelAl(tDiff, xnf(:, i));
                NN = An * obj.Plp(:,:,i) * An' + Qn;       % Eq. (23c)
                obj.xnp(:, i) = fn + An * obj.xlp(:, i) + ...
                    sqrtm(NN) * randn(length(obj.nlin), 1);
            end;
            % (4c) Kalman filter time update
            for i = 1:obj.N
                fn = obj.processModelfn(tDiff, xnf(:, i));
                fl = obj.processModelfl(tDiff, xnf(:, i));
                An = obj.processModelAn(tDiff, xnf(:, i));
                Al = obj.processModelAl(tDiff, xnf(:, i));
                NN = An * obj.Plp(:,:,i) * An' + Qn;       % Eq. (23c)
                L = Al * obj.Plp(:,:,i) * An' * inv(NN);   % Eq. (23d)
                z = obj.xnp(:,i) - fn;                     % Eq. (24a)
                obj.xlp(:,i) = Al * obj.xlp(:,i) + fl + ...
                    L * (z - An * obj.xlp(:,i));           % Eq. (23a)
                obj.Plp(:,:,i) = Al * obj.Plp(:,:,i) * Al' + ...
                    Ql - L * NN * L';                      % Eq. (23b)
            end;
        end
        function [xf, Pf] = stateEstimate(obj)
            % Compute estimate for the nonlinear states
            % see 106.2.4 in Particle Filter-Based Target Tracking
            % in Gaussian and Non-Gaussian Environments
            % or Particle Filter Theory and Practice with Positioning
            % Applications, 9b and 9c
            % Compute estimate for the nonlinear states
            obj.x(obj.nlin,1) = obj.xnp*obj.q;
            % Compute estimate for the linear states
            obj.x(obj.lin,1) = mean(obj.xlp,2); 
            % Compute estimate of covariance
            obj.P = zeros(obj.nStates,obj.nStates);
            for i = 1:obj.N
                diff = [obj.xnp(:,i); obj.xlp(:,i)] - obj.x;
                obj.P = obj.P + diff*diff'/obj.N;
            end
            xf = obj.x;
            Pf = obj.P;
        end
        function [observation, sensorPosition, measurementNoise] = ...
            parseObservation(obj, obsData)
            observation = obsData.measurements;
            if size(observation,1)==1 
                observation = observation';
            end
            observation = observation(1:obj.nMeasurementStates,1);
            sensorPosition = obsData.sensorPosition;
            if size(sensorPosition,1)== 1
                sensorPosition = sensorPosition';
            end
            measurementNoise = obsData.errors(1:obj.nMeasurementStates);
        end
        function initialize(obj,x0,P0)
            obj.x = x0;
            obj.P = P0;
            % 1. Initialization
            % Nonlinear states
            obj.xnp = repmat(obj.x(obj.nlin), 1, obj.N) + ...
                chol(obj.P(obj.nlin, obj.nlin)) * randn(numel(obj.nlin), obj.N);  
            % Conditionally linear Gaussian states
            obj.xlp = repmat(obj.x(obj.lin),1,obj.N);          
            % Initial covariance matrix for linear states
            obj.Plp  = repmat(obj.P(obj.lin, obj.lin), [1, 1, obj.N]); 
        end
      
        function [xf, Pf] = initialStateEstimate(obj, observation, measurementNoise, ...
                sensorPosition)
            pos = obj.azelr2cart(observation, sensorPosition);
            xf = [pos; obj.x(obj.lin)];
            NPf = 10000;
            xhat = zeros(obj.nMeasurementStates, NPf);
            for i=1:NPf
                robservation = observation + ...
                    (measurementNoise .* randn(1, obj.nMeasurementStates))';
                xhat(:,i) = obj.azelr2cart(robservation, sensorPosition);
            end
            Ppos = cov((xhat - repmat(xf(obj.nlin), 1, NPf))');
            Pf = blkdiag(Ppos, obj.P(obj.lin, obj.lin));
        end

        function [xf,Pf]=getPositionAtTime(obj,time)
            xf = obj.x;
            Pf = obj.P;
        end
        
        function error=getPositionErrorAtTime(obj,time)
            [~,Pf]=obj.getPositionAtTime(time);
            dP=diag(Pf);
            error=sqrt(sum(dP(1:3).^2));
        end
       function xyz = azelr2cart(obj,azelr,pos_sensor)
            obj.checkWorld();
            az = azelr(1,1);
            el = azelr(2,1);
            r = azelr(3,1);
            % pos_sensor is in ecef
            % convert to lla
            if size(pos_sensor,1) > size(pos_sensor,2)
                pos_sensor=pos_sensor';
            end
            sensor_lla = obj.world.convert_ecef2lla(pos_sensor);
            xyz = obj.world.convert_azelr2ecef(sensor_lla,az,el,r)';
            if size(azelr,1)==4
                rdot = azelr(4,1);
                xdot = rdot * sind (el) * cosd (az);
                ydot = rdot * sind (el) * sind (az);
                zdot = rdot * cosd (el);
                xyz = [xyz; xdot; ydot; zdot];
            end
        end
        function azelr = cart2azelr(obj,pos,pos_sensor)
            obj.checkWorld();
            % pos_sensor is in ecef
            % convert to lla
            sensor_lla = obj.world.convert_ecef2lla(pos_sensor');
            % pos is in ecef
            % convert to lla
            target_lla = obj.world.convert_ecef2lla(pos');
            [az, el, r] = obj.world.convert_lla2azelr(sensor_lla,target_lla);
            azelr = [az;el;r];
            x_sensor = pos_sensor(1,1);
            y_sensor = pos_sensor(2,1);
            z_sensor = pos_sensor(3,1);
            if size(pos,1)==6
                xx = pos(1,1);
                y = pos(2,1);
                z = pos(3,1);
                xdot = pos(4,1);
                ydot = pos(5,1);
                zdot = pos(6,1);
                rdot = ((xx - x_sensor) * xdot + (y - y_sensor) * ydot + ...
                    (z - z_sensor) * zdot) / r;
                azelr = [az;el;r;rdot];
            end
        end
    end
    
    methods(Static)
        function i = sysresample(q)
            qc = cumsum(q);
            M = length(q);
            u = ([0:M-1]+rand(1))/M;
            i = zeros(1,M);
            k = 1;
            for j=1:M
                while (qc(k)<u(j))
                    k = k+1;
                end
                i(j) = k;
            end
        end
        function azelr = add_meas_err (azelr0, sd_azelr0)
            az = azelr0(1,1);
            el = azelr0(2,1);
            r = azelr0(3,1);
            if size(sd_azelr0,1)==1
                sd_azelr0 = sd_azelr0';
            end
            sd_az = sd_azelr0(1,1);
            sd_el = sd_azelr0(2,1);
            sd_r = sd_azelr0(3,1);
            r = r + randn * sd_r;
            az = az + randn * sd_az;
            el = el + randn * sd_el;
            azelr = [az; el; r];
            if size(azelr0,1)==4
                rdot = azelr0(4,1);
                sd_rdot = sd_azelr0(4,1);
                rdot = rdot + randn * sd_rdot;
                azelr = [az; el; r; rdot];
            end
        end
        function obj=deserialize(input)
            dataObject=getArrayFromByteStream(input);
            obj=publicsim.funcs.trackers.MParticleFilter(...
                dataObject.nStates,dataObject.nMeasurementStates,...
                dataObject.N);
            dataObject=rmfield(dataObject,'nStates');
            proplist=fields(dataObject);
            for i=1:numel(proplist)
                obj.(proplist{i})=dataObject.(proplist{i});
            end
        end
        test_MParticleFilter()

    end
end

%            for i = 1:obj.N
                % need to incorporate cross-covariance
                % Qln=obj.Q(obj.nlin,obj.lin)
                % Qn=obj.Q(obj.nlin,obj.nlin)
                % Ql=obj.Q(obj.lin,obj.lin)
                % Albar=Al-Qln*inv(Qn)*An (24b)
                % Qlbar=Ql-Qln'*inv(Qn)*Qln (24c)
                % L=Albar*obj.Plp(:,:,i)*An'*inv(NN) (23d)
%                    z = obj.xnp(:,i) - obj.fn*xnf(:,i);                 % Eq. (24a)
%                    obj.xlp(:,i) = obj.Al*obj.xlp(:,i) + L*(z - obj.An*obj.xlp(:,i)); % Eq. (23a)
                % need to incorporate cross-covariance
                % = Albar*obj.xlp(:,i) + L*(z - An*obj.xlp(:,i)) + 
                % Qln'*inv(Qn)*z (23a)
                % need to incorporate cross-covariance
                % = Albar*obj.Plp(:,:,i)*Albar' + Qlbar - L*NN*L' (23b)
                % obj.Plp - P
                % NN - N
%            end
