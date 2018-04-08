function nu = getKinematicViscosity(T)
%GETKINEMATICVISCOSITY Returns the kineatic viscosity of air
% Inputs: 
% T: Static temperature [K]
% Outputs
% nu: Kinematic Viscosity of Air [m^2/s]
% Data taken from the Engineering Toolbox, 
% https://www.engineeringtoolbox.com/dry-air-properties-d_973.html

ts = [175 200 225 250 275 300 325 350 375 400 450 500 550 600 650 700 ...
    750 800 850 900 950 1000 1050 1100 1150 1200 1250 1300 1350 1400 ...
    1500 1600 1700 1800 1900];

nus = [0.586 0.753 0.935 1.132 1.343 1.568 1.807 2.056 2.317 2.591 ...
    3.168 3.782 4.439 5.128 5.853 6.607 7.399 8.214 9.061 9.936 10.83 ...
    11.76 12.72 13.7 14.7 15.73 16.77 17.85 18.94 20.06 22.36 24.74 ...
    27.2 29.72 32.34] * 1e-5;

if T < min(ts) || T > max(ts)
    warning('Temperature out of range!')
    if T < min(ts)
        nu = nus(1);
    else
        nu = nus(end);
    end
    return;
end

nu = interp1(ts, nus, T);

end

