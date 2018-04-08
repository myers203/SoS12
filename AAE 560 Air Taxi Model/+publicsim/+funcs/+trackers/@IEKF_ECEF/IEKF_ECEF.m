classdef IEKF_ECEF < publicsim.funcs.trackers.Tracker

% Provides and implementation of integrated extended kalman filter. 
% Integrated allows switching between 6 states and 9 states filter and
% processing for 2D and 3D measurements. 
    
    properties(SetAccess=private)
        Q
        A
        P = zeros(9,9)
        H
        x = zeros(9,1)
        t
        enableDoppler
        maxIters = 25
        absAccuracy = 1;
        nStates;

       end
    
    methods
    
        function obj=IEKF_ECEF(nStates,doppler)
            
                obj.enableDoppler = doppler;
                obj.nStates       = nStates;
                obj.setInputType('ECEF');
        end
        

        function initByObs(obj,obsData)
            nObs = length(obsData.measurements);
            obj.x(1:nObs)=obsData.measurements';
            obj.t=obsData.time;
        end
        
        function [xt,Ph] = addObservation(obj,obsData)

            observation = obsData.measurements';
            noise       = obsData.errors;
            time        = obsData.time;

            %Define Filter parameters           
            deltaT = time - obj.t;
            obj.setFilterParameters(deltaT,obj.nStates)
          
            
           
            [x_pred,P_pred] = obj.predict(time);
            % Note x_pred and P_pred are in local frame of reference

            % Calculate Update
            [x_hat,P_hat,d2] = obj.filterupdate(x_pred,P_pred,observation,noise,time);
            
        end

        
        function setFilterParameters(obj,deltaT,nStates)
        
            obj.A = [1 deltaT deltaT^2/2; 0 1 deltaT; 0 0 1];
            % Bar-Shalom 1.5.3-2
            % continuous Wiener process acceleration model driven by a zero mean white
            % jerk process noise
            
            if(nStates<6)
                
                %%%%% Define Q tilda here %%% which is a tuning paprmeter and model
                %%%%% specific
                q_tilda=1; 
                C = blkdiag([deltaT^3/3 deltaT^2/2; deltaT^2/2,deltaT],0); % Bar-Shalom
                % Tracking and data fusion 1.5.2-3, acceleration is constant
                % continuous white noise acceleration model driven by a zero mean
                % white acceleration process noise
            else
                
                %%%%% Define Q tilda here %%% which is a tuning paprmeter and model
                %%%%% specific
                q_tilda = 2;
                C = [(deltaT^5)/20,      (deltaT^4)/8,  (deltaT^3)/6;...
                    (deltaT^4)/8,       (deltaT^3)/3,  (deltaT^2)/2;...
                    (deltaT^3)/6,       (deltaT^2)/2,   deltaT]; % Bar-Shalom 1.5.3-3
                % continuous Wiener process acceleration model driven by a zero mean white
                % jerk process noise
            end

            Q_global = q_tilda * blkdiag (C, C, C);
            obj.Q    = Q_global;
        end
        
        function [sigma2,dimension] = processObservation(obj,observation,noise,doppler)
            
            dimension = max(size(observation));
            
            if(dimension == 3)
                % 3D measurement are normalized range variance
                % therefore need to multiply by range^2
                
                range_var = noise(3)*(observation(3).^2);
             
                if(range_var < 20e-3)
                    range_var=20e-3;
                end
                
                if doppler % Revise this for doppler noise
                    sigma2 = [  range_var,...
                        noise(1:2) ];
                    
               else
                    sigma2 = [  range_var,...
                        noise(1:2)];
                   
                end
                
            elseif(dimension == 2)
                sigma2  = measurement.sensor_variance(1:2);
                
            else
                fprintf('Unsupported measurements of dimension [%i]\n',dimension);
            end
            
        end
        
       
        function [x_pred,P_pred] = predict(obj,time)
            
            deltaT = time - obj.t;
            
            %Perform sensor transformation
            
            %Conversion from [x y z x_dot y_dot z_dot ...] to [x x_dot x_ddot y y_dot ...]
            INDEX_SORT = [1:3:9, 2:3:9, 3:3:9];
            P_global = obj.P(INDEX_SORT,INDEX_SORT);
            x_global = obj.x(INDEX_SORT);
            
            %predict state estimate
            G = [0.5*deltaT^2;deltaT;0];
            G = blkdiag(G,G,G);
            %http://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html
             mu_earth = 3.9860e+14; %m^3/sec^2
             r = norm(x_global([1 4 7]));
             g = mu_earth/(r^2);
            
            F_local = blkdiag(obj.A,obj.A,obj.A); % Bar-Shalom 1.5.3-2
            % continuous Wiener process acceleration model driven by a zero mean white
            % jerk process noise
            
            %predict state estimate
            % G * ... term is needed to account for grabity in the process mode
            % X(k+1)=Fx(k)+Bu(k)
            % x_hat = F_local * x_local works as well but incorporating g explicitly
            % is a more accurate process model
            x_hat = F_local * x_global + G * [0; 0; -1.0 * g];
            %predict covariance estimate
            P_hat = F_local * P_global * transpose (F_local) + obj.Q;
            
            
            %Conversion from [x y z x_dot y_dot z_dot ...] to [x x_dot x_ddot y y_dot ...]
            INDEX_SORT = [1:3:9, 2:3:9, 3:3:9];
            P_pred = P_hat(INDEX_SORT,INDEX_SORT);
            x_pred = x_hat(INDEX_SORT);
                       
            
        end
        
        function [x_update,P_update,d2]  = filterupdate(obj,x_old,P_old,observation,noise,time)

           %Conversion from [x y z x_dot y_dot z_dot ...] to [x x_dot x_ddot y y_dot ...]
            INDEX_SORT = [1:3:9, 2:3:9, 3:3:9];
            P_prev = P_old(INDEX_SORT,INDEX_SORT);
            x_prev = x_old(INDEX_SORT);    
            
            
        % calculate sigma values
            [sigma2,dimension] = obj.processObservation(observation,noise,obj.enableDoppler);
        
        delta = inf;
        jj = 1; %counter
        while (delta > obj.absAccuracy && jj <= obj.maxIters)
            % iteratively improve estimates on x_local, P_local
            if (dimension == 3)
                [x_local, P_local, residual, H, R] = obj.KalmanRadarUpdate (x_prev, ...
                    P_prev, observation, sigma2, obj.enableDoppler);
            else
                [x_local, P_local, residual, H, R] = obj.KalmanIRUpdate (x_prev, P_prev, ...
                    observation, sigma2);
            end
            
            delta = norm (x_local - x_prev);
            x_prev = x_local;
            P_prev = P_local;
            jj = jj + 1;
        end
        
        if (obj.nStates == 6)
            P_local (3:3:9, :) = 0;
            P_local (:, 3:3:9) = 0;
            x_local (3:3:9) = 0;
            P_local (3:3:9, 3:3:9) = eye (3);
        end
        
        x_hat = x_local;
        P_hat = P_local;
        INDEX_SORT = [1:3:9, 2:3:9, 3:3:9];
        P_update = P_hat(INDEX_SORT,INDEX_SORT);
        x_update = x_hat(INDEX_SORT);
        
        obj.x=x_update;
        obj.P=P_update;
        obj.t=time;
        
        d2 = residual' * ((H * P_local * H' + R) \ residual); % 2.3.2-3 Bar-Shalom
        
        
        end
        
        function [x, P, residual, H, R] = KalmanRadarUpdate (obj,x_hat, P_hat, ...
                measurement, sigma2, doppler)
            % Note sigma2 = [sigma2_R, sigma2_az, sigma2_el]
            % x_hat is [x x_dot x_ddot y y_dot ...]
            % P_hat is [x x_dot x_ddot y y_dot ...]
            POSITION_INDEX = [1 4 7 2 5 8];
            % x_hat(POSITION_INDEX) is [x y z x_dot y_dot z_dot]
            predicted   = obj.LocalMeasurementModel (x_hat (POSITION_INDEX), doppler);
            
            %Key for preventing discontinuities due to angle wrapping (-180 to 180)
            if(abs(measurement(2) - predicted(2)) > pi)
                if(predicted(2) < measurement(2))
                    predicted(2) = predicted(2) + 2*pi;
                else
                    predicted(2) = predicted(2) - 2*pi;
                end
            end
            %measurement residual (innovation)
            residual = measurement - predicted;
            H = obj.LocalGradientModel (x_hat (POSITION_INDEX), doppler);
            
            %Conversion from radians to milliradians for scaling
            residual(2:3) = residual(2:3)*1000;
            H(2:3,:) = H(2:3,:)*1000;
            if doppler
                R = diag ([sigma2(1), sigma2(2:3) * 1e6, sigma2(4)]);
            else
                R = diag ([sigma2(1), sigma2(2:3) * 1e6]);
            end
            
            %Compute Kalman Update
            %covariance residual (innovation)
            S = H*P_hat*H'+ R;
            %filter gain
            K = (P_hat*H')/(S);
            %update state estimate
            x = x_hat +K*residual;
            
            %Update covariance estimate
            P = (eye(9)-K*H)*P_hat;
            P = (P+transpose(P))/2;  %Helps to insure symetry
        end
        
        function [x,P,residual, H, R] = KalmanIRUpdate(obj,x_hat,P_hat,measurement,sigma2)
            POSITION_INDEX = [1 4 7];
            %Note sigma2 = [sigma2_az, sigma2_el]
            
            predicted   = obj.LocalMeasurementModel (x_hat (POSITION_INDEX), false);
            predicted = predicted(2:3);
            
            %Key for preventing discontinuities due to angle wrapping (-180 to 180)
            if(abs(measurement(1) - predicted(1)) > pi)
                if(predicted(1) < measurement(1))
                    predicted(1) = predicted(1) + 2*pi;
                else
                    predicted(1) = predicted(1) - 2*pi;
                end
            end
            residual = measurement - predicted;
            H = obj.LocalGradientModel (x_hat (POSITION_INDEX), false);
            
            %Conversion from radians to milliradians for scaling
            residual = residual*1000;
            H = H(2:3,:)*1000;
            R = diag(sigma2*1e6);
            
            %Compute Kalman Update
            S = H*P_hat*H'+ R;
            K = (P_hat*H')/(S);
            x = x_hat +K*residual;
            
            %Update Covariance
            P = (eye(9)-K*H)*P_hat;
            P = (P+transpose(P))/2;  %Helps to insure symetry
        end
        
        
        function measure = LocalMeasurementModel (obj,X, doppler)
            % X is [x y z x_dot y_dot z_dot]
            r       = norm (X (1:3)); % Bar-Shalom 1.6.2-3
            bearing = atan2 (X (1), X (2)); % 1.6.2-4
            el      = atan2 (X (3), hypot (X (1), X (2))); % 1.6.2-5
            if doppler
                radial_velocity = sum (X (1:3) .* X (4:6)) / r;
                measure = [r; bearing; el; radial_velocity]; % 1.6.2-6
            else
                measure = [r; bearing; el];
            end
        end
        
        function H = LocalGradientModel(obj,X,doppler)
            % X is [x y z x_dot y_dot z_dot ...]
            % P_hat is [x x_dot x_ddot y y_dot ...]
            % thus H columns are [d/dx d/dx_dot d/dx_ddot d/dy d/dy_dot ...]
            x = X(1);
            y = X(2);
            z = X(3);
            hh = x^2 + y^2;
            rr = hh  + z^2;
            r = sqrt(rr);
            h = sqrt(hh);
            if doppler
                xdot = X(4);
                ydot = X(5);
                zdot = X(6);
                rdot = sum (X (1:3) .* X (4:6)) / r;
                H = [
                    [x/r,              0,   0, y/r,              0,   0, z/r,              0,   0];...
                    [y/hh,             0,   0, -x/hh,            0,   0, 0,                0,   0];...
                    [-(x*z)/(rr*h),    0,   0, -(y*z)/(rr*h),    0,   0, h/rr,             0,   0];...
                    [xdot/r-x*rdot/rr, x/r, 0, ydot/r-y*rdot/rr, y/r, 0, zdot/r-z*rdot/rr, z/r, 0]];
            else
                H = [
                    [x/r,           0, 0, y/r,           0, 0, z/r,  0, 0];...
                    [y/hh,          0, 0, -x/hh,         0, 0, 0,    0, 0];...
                    [-(x*z)/(rr*h), 0, 0, -(y*z)/(rr*h), 0, 0, h/rr, 0, 0]];
                % similar to 1.6.2-7 but fixed the error
            end
        end

        
        function output=serialize(obj)
            dataObject=[];
            proplist=properties(obj);
            for i=1:numel(proplist)
                dataObject.(proplist{i})=obj.(proplist{i});
            end
            output=getByteStreamFromArray(dataObject);
        end
        
        function [x,P]=getPositionAtTime(obj,time)
            [x,P]=obj.predict(time);
        end
        
        function error=getPositionErrorAtTime(obj,time)
            [~,tP]=obj.getPositionAtTime(time);
            dP=diag(tP);
            error=sqrt(sum(dP(1:3).^2));
        end
              
    end
    
     methods(Static)
        function obj=deserialize(input)
            dataObject=getArrayFromByteStream(input);
            obj=publicsim.funcs.trackers.BasicKalman(dataObject.nStates);
            dataObject=rmfield(dataObject,'nStates');
            proplist=fields(dataObject);
            for i=1:numel(proplist)
                obj.(proplist{i})=dataObject.(proplist{i});
            end
        end
     end
     
end
