classdef UKF < publicsim.funcs.trackers.Tracker
    % The Unscented Kalman Filter
    % by Eric A. Wan and Rudolph van der Merwe
      
    properties
        alpha=1e-3; % scaling parameter
        % determines the spread of the sigma points around xbar
        % is usually set to a small positive value (e.g., 1e-3).
        beta=2; % used to incorporate prior knowledge of the distribution of x 
        % (for Gaussian distributions, beta=2 is optimal)
        ki=0; % secondary scaling parameter usually set to 0
        nMeasurementStates % length of measurement vector
        fm % process model
        lambda % = alpha^2*(nStates+ki)-nStates
        c % = nStates+lambda
        Wm % weights of sample mean
        Wc % weights of sample covariance
        eps=0.001; % correct for underflow
        processDynamics=1; % 1=Newton 2=Keppler
        processNoise=2; % 1=continuous white 2=discrete
    end
    
    methods
        function xnew=processModel(obj,dt,xx)
            if obj.processDynamics==1
                F=obj.fm(dt);
                xnew=F*xx;
            else
                [gx,gy,gz]=publicsim.funcs.trackers.UKF.J2(xx(1),xx(2),xx(3));
                acc=[gx;gy;gz];
                xnew(1:3)=xx(1:3)+xx(4:6)*dt+acc*dt^2/2;
                xnew(4:6)=xx(4:6)+acc*dt;
                xnew(7:9)=acc;
            end
        end
        function ynew=measurementModel(obj,y,sensorPosition)
            ynew=obj.cart2azelr(y,sensorPosition);
        end
        function Q=buildProcessNoise(obj,dt)
            % https://github.com/rlabbe/Kalman-and-Bayesian-Filters-in-Python
            if obj.processNoise==1
                % continuous white noise, sec 7.3.1
                % handles varying time samples much more easily 
                % than the second model since 
                % the noise is integrated across the time period
                % obj.qtilda is spectral density
                q = obj.qtilda*[[(dt^5)/20, (dt^4)/8, (dt^3)/6];...
                    [ (dt^4)/8, (dt^3)/3, (dt^2)/2];...
                    [ (dt^3)/6, (dt^2)/2, dt]];
            else
                % discrete white noise, sec 7.3.2
                % rule of thumb to set sqrt(obj.qtilda) to [du/2 du]
                % where du is the maximum amount that the acceleration
                % will change between sample periods.
                q = obj.qtilda*[[.25*dt^4, .5*dt^3, .5*dt^2];...
                       [ .5*dt^3,    dt^2,       dt];...
                       [ .5*dt^2,       dt,        1]];
            end
            Q=zeros(obj.nStates,obj.nStates);
            for i=1:(obj.nStates/3)
                for j=1:(obj.nStates/3)
                    Q(3*(i-1)+1,3*(j-1)+1)=q(i,j);
                    Q(3*(i-1)+2,3*(j-1)+2)=q(i,j);
                    Q(3*(i-1)+3,3*(j-1)+3)=q(i,j);
                end
            end
        end        
        function obj=UKF(varargin)
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
            q=0.1;
            initPError=1e4;
            obj=obj@publicsim.funcs.trackers.Tracker(nStates);
            obj.buildInitialP(initPError);
            obj.buildInitialQ(q);
            obj.nMeasurementStates=nMeasurementStates;
            obj.setInputType('AZELR');
            
            obj.fm=@obj.buildLinearModelMatrix;
            
            obj.lambda=obj.alpha^2*(nStates+obj.ki)-nStates;
            obj.c=nStates+obj.lambda;
            % 7.34
            obj.Wm=[obj.lambda/obj.c 0.5/obj.c+zeros(1,2*nStates)];
            obj.Wc=obj.Wm;
            obj.Wc(1)=obj.Wc(1)+(1-obj.alpha^2+obj.beta);
        end
        
        function initByObs(obj,obsData)
            [observation, sensorPosition, measurementNoise] = obj.parseObservation(...
                obsData);
            pos = obj.azelr2cart(observation,sensorPosition);
            [gx,gy,gz]=publicsim.funcs.trackers.UKF.J2(pos(1),pos(2),pos(3));
            if obj.nMeasurementStates==3
                obj.x=[pos;0;0;0;gx;gy;gz];
            else
                obj.x=[pos;gx;gy;gz];
            end
            tDiff=0.1;
            Q=obj.buildProcessNoise(tDiff);
            [xbar,Pxx]=obj.ukf1(tDiff,Q);
            obj.x=xbar;
            obj.P=Pxx;
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
        
        function [observation, sensorPosition, measurementNoise] = ...
            parseObservation(obj, obsData)
            observation = obsData.measurements;
            if size(observation,1)==1 
                observation = observation';
            end
            observation = observation(1:numel(observation),1);
            sensorPosition = obsData.sensorPosition;
            if size(sensorPosition,1)== 1
                sensorPosition = sensorPosition';
            end
            measurementNoise = obsData.errors(1:numel(observation));
        end
        function [xt,Ph] = addObservation(obj,obsData)
            %for RF observation length is 3 or 4 (with Doppler)
            %for IR observation length is 2
            [observation, sensorPosition, measurementNoise] = obj.parseObservation(...
                obsData);
            time = obsData.time;
            obj.applyProcessNoiseEvent(time);            
            [xt,Ph] = obj.ukf(obj.t,time,observation,sensorPosition,...
                obj.buildProcessNoise(time-obj.t),...
                diag(measurementNoise.^2));
            obj.x=xt;
            obj.P=Ph;
            obj.t=time;
            
            %update Track Purity
            obj.updatePurity(obsData.trueId);
        end
        
        function [x,P]=getPositionAtTime(obj,time)
            [x,P]=obj.predict(time);
        end
        
        function error=getPositionErrorAtTime(obj,time)
            if isempty(obj.t)
                error=inf;
            else
                [~,tP]=obj.getPositionAtTime(time);
                dP=diag(tP);
                error=sqrt(sum(dP(1:3).^2));
            end
        end

        function [xbar,Pxx]=predict(obj,time)
            tDiff = time - obj.t;
            Q=obj.buildProcessNoise(tDiff);
            [xbar,Pxx]=obj.ukf1(tDiff,Q);
        end
        function [xbar,Pxx,LX] = ukf1(obj,tDiff,Q)
            % 7.52 define sigma points around obj.x
            X=publicsim.funcs.trackers.UKF.sigmas(obj.x,obj.P,obj.c);
            % 7.53 propagate in time sigma points using plant dynamics 
            LX=size(X,2);
            Xa=zeros(obj.nStates,LX);
            for k=1:LX
                Xa(:,k)=obj.processModel(tDiff,X(:,k));
            end
            % 7.54 reconstruct the mean at the final time
            xbar=zeros(obj.nStates,1);
            for k=1:LX
                xbar=xbar+obj.Wm(k)*Xa(:,k);
            end
            % 7.55 reconstruct the covariance at the final time
            dX=Xa-xbar(:,ones(1,LX));
            Pxx=dX*diag(obj.Wc)*dX'+Q;
        end
        function [x,P]=ukf(obj,t1,t2,y,sensorPosition,Q,R)
            tDiff = t2 - t1;
            % propagate state
            [xbar,Pxx,LX]=obj.ukf1(tDiff,Q);
            % 7.56 gemerate sigma points around xbar
            X=publicsim.funcs.trackers.UKF.sigmas(xbar,Pxx,obj.c);
            % 7.57 what is predicted observation
            Y=zeros(obj.nMeasurementStates,LX);
            for k=1:LX
                if obj.nMeasurementStates==3 % RF without Doppler
                    pos = X(1:3,k);
                else % RF with Doppler
                    pos = X(1:6,k);
                end
                Y(:,k)=obj.measurementModel(pos,sensorPosition);
            end
            % leave only azel if IR
			if numel(y)==2 % IR
				YY(:,:)=Y(1:2,:);
			else % RF
				YY=Y;
			end
            % 7.58 calculate the predicted observation
            ybar=zeros(numel(y),1);
            for k=1:LX
                ybar=ybar+obj.Wm(k)*YY(:,k);
            end
            % 7.59 calculate the innovation covariance matrix
            dY=YY-ybar(:,ones(1,LX));
            Pyy=dY*diag(obj.Wc)*dY'+R;
            % 7.60 calculate the state-measurement cross correlation matrix
            Pxy=(X-xbar(:,ones(1,LX)))*diag(obj.Wc)*dY';                        
            % 7.61 compute Kalman gain
            K=Pxy/Pyy;
            % 7.62 measurement update state
            x=xbar+K*(y-ybar);                              
            % 7.63 measurement update covariance                             
            P=Pxx-K*Pyy*K';                                
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
        function obj=deserialize(input)
            dataObject=getArrayFromByteStream(input);
            obj=publicsim.funcs.trackers.UKF(dataObject.nStates);
            dataObject=rmfield(dataObject,'nStates');
            proplist=fields(dataObject);
            for i=1:numel(proplist)
                obj.(proplist{i})=dataObject.(proplist{i});
            end
        end
        function [gx,gy,gz]=J2(x,y,z)
            % J2 gravity model
            % see Comparison of Four Gravity Models
            % by David Y.Hsu
            kM=3986005e+8; % gravitational constant*mass of earth m3/s2
            Omega=7.292115e-5; % earth rotation rate rad/s
            J2=108263e-8;
            a=6378137; % semi-major axis of refference ellipsoid
            r=sqrt(x^2+y^2+z^2);
            gx=-x*kM/r^3*(1+3*J2*a^2/(2*r^2)-15*J2*a^2*z^2/(2*r^4))+x*Omega^2;
            gy=-y*kM/r^3*(1+3*J2*a^2/(2*r^2)-15*J2*a^2*z^2/(2*r^4))+y*Omega^2;
            gz=-z*kM/r^3*(1+9*J2*a^2/(2*r^2)-15*J2*a^2*z^2/(2*r^4));
        end        
        function azelr = add_meas_err (azelr0, sd_azelr0)
            if size(azelr0,1)==1
                azelr0 = azelr0';
            end
            if size(sd_azelr0,1)==1
                sd_azelr0 = sd_azelr0';
            end
            az = azelr0(1,1);
            el = azelr0(2,1);
            sd_az = sd_azelr0(1,1);
            sd_el = sd_azelr0(2,1);
            az = az + randn * sd_az;
            el = el + randn * sd_el;
            if numel(azelr0)==2
                azelr = [az; el];
            end
            if numel(azelr0)==3
                r = azelr0(3,1);
                sd_r = sd_azelr0(3,1);
                r = r + randn * sd_r;
                azelr = [az; el; r];
            end
            if size(azelr0,1)==4
                rdot = azelr0(4,1);
                sd_rdot = sd_azelr0(4,1);
                rdot = rdot + randn * sd_rdot;
                azelr = [az; el; r; rdot];
            end
        end
        
        function [y,P,Y1]=ut(Y,Wm,Wc,n)
            L=size(Y,2);
            y=zeros(n,1);
            for k=1:L
                y=y+Wm(k)*Y(:,k);
            end
            Y1=Y-y(:,ones(1,L));
            P=Y1*diag(Wc)*Y1';
        end
        function X=sigmas(x,P,c)
            [cholP,p]=chol(P,'lower');
            if p~=0
                fprintf('ukf1: non+definite\n');
                cholP=chol(P+obj.eps*eye(size(P,1)),'lower');
            end
            Y = x(:,ones(1,numel(x)));
            X = [x Y+cholP*sqrt(c) Y-cholP*sqrt(c)];
        end
        test_UKF()
        test_tracker(tracker)
    end
    
end

