function [cd] = getdragcoef(dragcoefprofile,Machnum,alt)

% Interpolates to determine drag coefficient,Cd, at a specified altitude and
% Mach number at each point during a missile's flight

% Altitude in meters
alt1 = 0;
alt2 = 15240; % [m] ( == 50,000 ft)
alt3 = 30480; % [m] ( == 100,000 ft)
alt4 = 36576; % [m] ( == 120,000 ft)
alt5 = 50000; % [m] ( == 164,000 ft)

DragCoefficientProfiles = dragcoefprofile.dragcoef;

%For each altitude block...
if alt > alt5 % altitude greater than 50 km
    cd = 0.3;  %at higher altitudes, Cd doesn't depend much on Mach number, set at constant, approximate value
elseif alt > alt4 % between 36,576 and 50,000 m
    cd1 = ppval(DragCoefficientProfiles.alt4,Machnum);
    cd2 = ppval(DragCoefficientProfiles.alt5,Machnum);
    percentage = (alt - alt4)/(alt5 - alt4);
    cd = (cd2 - cd1)*percentage + cd1;
elseif alt > alt3 % between 30,480 and 36,576 m
    cd1 = ppval(DragCoefficientProfiles.alt3,Machnum);
    cd2 = ppval(DragCoefficientProfiles.alt4,Machnum);
    percentage = (alt - alt3)/(alt4 - alt3);
    cd = (cd2 - cd1)*percentage + cd1;
elseif alt > alt2 % between 15,240 and 30,480 m
    cd1 = ppval(DragCoefficientProfiles.alt2,Machnum);
    cd2 = ppval(DragCoefficientProfiles.alt3,Machnum);
    percentage = (alt - alt2)/(alt3 - alt2);
    cd = (cd2 - cd1)*percentage + cd1;
elseif alt >= alt1 % between 0 and 15,240 m
    cd1 = ppval(DragCoefficientProfiles.alt1,Machnum);
    cd2 = ppval(DragCoefficientProfiles.alt2,Machnum);
    percentage = (alt - alt1)/(alt2 - alt1);
    cd = (cd2 - cd1)*percentage + cd1;
else % Negative altitude, treat as 0 altitude
    alt = 0;
    cd1 = ppval(DragCoefficientProfiles.alt1,Machnum);
    cd2 = ppval(DragCoefficientProfiles.alt2,Machnum);
    percentage = (alt - alt1)/(alt2 - alt1);
    cd = (cd2 - cd1)*percentage + cd1;
end

end