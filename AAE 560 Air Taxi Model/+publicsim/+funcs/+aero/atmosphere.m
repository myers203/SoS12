function [T, p, rho, a] = atmosphere(alt)
% atmosphere
% Outputs atmospheric properties at a given geopotential altitude (m) based
% on the US Standard Atmosphere 1976 and code written by Ralph Carmichael
% for PDAS (Public Domain Aeronautical Software).
%
% Inputs
% -------------------------------------------------------------------------
% alt:
%      The geopotential altitude in meters (single input or array)
% -------------------------------------------------------------------------
% 
% Outputs
% -------------------------------------------------------------------------
% T:
%      Temperature (deg C)
% p:
%      pressure (kPa)
% rho:
%      density (kg/m^3)
% a:
%      speed of sound (m/s)
% -------------------------------------------------------------------------

% -- CONSTANT -- %
GMR = 34.163195;                              % hydrostatic constant
n = length(alt);                              % allows for array(alt)

% Table from 1976 Std. Atmosphere
% htab - altitude (km)
% ttab - temperature (K)
% ptab - pressure (Pa)
% gtab - temperature gradient (K/km)
htab = [0 11 20 32 47 51 71 84.852];
ttab = [288.15 216.65 216.65 228.65 270.65 270.65 214.65 186.946];
ptab = [1, 2.233611e-1, 5.403295e-2, 8.5666784e-3, 1.0945601e-3,...
    6.6063531e-4, 3.9046834e-5, 3.68501e-6];
gtab = [-6.5, 0, 1, 2.8, 0, -2.8, -2, 0];

h = alt./1000;                                    % height (km)
T = zeros(n,1);
p = zeros(n,1);
rho = zeros(n,1);
a = zeros(n,1);
for k = 1:n
    if h(k)>84.852                                % in space

        % -- OUTPUTS: SPACE --%
        T(k) = ttab(end)-273.15;                  % Temp unused
        p(k) = 0;                                 % p=0 will give Mach = NaN
        rho(k) = 1.223*exp(-h(k)/9);
        a(k) = 0;

    else                                          % in atmosphere
        if (h(k) < 0) && (h(k) > -1)
            h(k) = 0; % Account for floating point error
        end
        
        [~, i] = min(abs(htab-h(k)));        % find base level of std atmo
        
        if htab(i)>h(k)                           % index should be for level
            i = i-1;                              % below input altitude
        end
        if (i < 1)
            i = 1;
        end

        tgrad = gtab(i);                          % Temperature gradient
        tbase = ttab(i);                          % Base temperature (K)
        deltah = h(k) - htab(i);                     % Difference in altitude
        tlocal = tbase + tgrad*deltah;            % Local temp (K)
        theta = tlocal/ttab(1);                   % Local temp/temp @SL

        if tgrad == 0
            delta = ptab(i)*exp(-GMR*deltah/tbase); % Local p/p @SL
        else
            delta = ptab(i)*(tbase/tlocal)^(GMR/tgrad);
        end
        sigma = delta/theta;                      % Local rho/rho @SL

        % -- OUTPUTS: ATMO -- %
        T(k) = tlocal-273.15;                     % Local Temp., deg C
        p(k) = delta*101.325;                     % Local Pres., kPa
        rho(k) = sigma*1.225;                     % Local Dens., kg/m3
        a(k) = sqrt(1.4*p(k)*1000/rho(k));        % Speed of Sound, m/s
    end
end
return