function Pr = getPrandtlNumber(T)
%GETPRANDTLNUMBER Returns the Prandtl number for air
% T: Static temperature [K]
% Outputs
% nu: Prantdl Number
% Data from the Engineering Toolbox
% https://www.engineeringtoolbox.com/dry-air-properties-d_973.html

ts = [175 200 225 250 275 300 325 350 375 400 450 500 550 600 650 700 ...
    750 800 850 900 950 1000 1050 1100 1150 1200 1250 1300 1350 1400 ...
    1500 1600 1700 1800 1900];

Prs = [0.744, 0.736, 0.728, 0.720, 0.713, 0.707, 0.701, 0.697, 0.692, ...
    0.688, 0.684, 0.680, 0.680, 0.680, 0.682, 0.684, 0.687, 0.690, ...
    0.693, 0.696, 0.699, 0.702, 0.704, 0.707, 0.709, 0.711, 0.713, ...
    0.715, 0.717, 0.719, 0.722, 0.724, 0.726, 0.728, 0.730];

if T < min(ts) || T > max(ts)
    warning('Temperature out of range!')
    if T < min(ts)
        Pr = Prs(1);
    else
        Pr = Prs(end);
    end
    return;
end

Pr = interp1(ts, Prs, T);

end

