% Empirical Axial Flow Coefficient (drag coefficient) Data
% sa-10c grumble aero propulsion data
% From Leon Mckinney 

% This data is used for the approximation of a drag coeffcient on a missile
% during flight

%Altitude - Sea Level, AOA - Zero
alt1=0;
alt2=50000*.3048; %feet to meters
alt3=100000*.3048;
alt4=120000*.3048;
   
%Data gives range of Mach from 0.1 - 6, extrapolate for Mach numbers greater than 6       
Mach(1:9)=0.1:0.1:0.9;
Mach(10:15)=[0.95 0.98 0.99 1.01 1.02 1.05];
Mach(16:22)=1.1:0.1:1.7;
Mach(23:24)=[2 2.2];
Mach(25:32)=2.5:0.5:6;
Mach(33:36)=[7 10 15 20];

% Altitude - 0 feet
Cd.alt0=[.1721 0.155 0.1456 0.1393 0.1345 0.1306 0.1277 0.1257 0.1305 0.1491 0.1647...
    0.1704 0.1823 0.1884 0.2068 0.2352 0.2644 0.2638 0.257 0.2516 0.2465 0.242...
    0.2297 0.2219 0.2185 0.2032 0.1905 0.1796 0.1741 0.1684 0.163 0.1582 .1535 .1490 .1475 .1465];
%Creates a piecewise functions for Mach number and associated drag
%coefficient at each altitude to allow for interpolation between the
%discrete points
dragcoef.alt1=pchip(Mach,Cd.alt0);  

%Altitude - 50000 feet, AOA - Zero
Cd.alt50000=[0.2331 0.2064 0.1925 0.1832 0.1762 0.1708 0.1666 0.1638 0.1682 0.1859 0.2008...
    0.2063 0.2176 0.2234 0.241 0.268 0.2953 0.294 0.2864 0.2802 0.2744 0.2692 0.255...
    0.2461 0.2411 0.2236 0.209 0.1964 0.1895 0.1826 0.1762 0.1705 .1654 .1604 .1587 .1575];
dragcoef.alt2=pchip(Mach,Cd.alt50000);

%Altitude - 100000 feet, AOA - Zero
Cd.alt100000=[0.3741 0.3233 0.2976 0.2809 0.2686 0.2592 0.252 0.2471 0.2505 0.2663 0.2797 0.2845...
    0.2947 0.2999 0.3155 0.3395 0.3627 0.3595 0.3502 0.3424 0.3351 0.3285 0.3103 0.299...
    0.2907 0.2686 0.2501 0.2342 0.2245 0.2151 0.2067 0.1992 .1932 .1874 .1854 .1841];
dragcoef.alt3=pchip(Mach,Cd.alt100000);

%Altitude - 120000 feet, AOA - Zero
Cd.alt120000=[0.4649 0.3967 0.3628 0.341 0.3252 0.3131 0.3039 0.2977 0.3003 0.315 0.3273...
    0.3318 0.3412 0.346 0.3605 0.3826 0.4033 0.3991 0.3887 0.3799 0.3717 0.3643 0.3438 0.331...
    0.3209 0.2962 0.2754 0.2577 0.2464 0.2357 0.2261 0.2175 .2109 .2046 .2024 .2009];
dragcoef.alt4=pchip(Mach,Cd.alt120000);

%Altitude - 164000 feet, A0A - Zero, extrapolated data (approx values)
for i=1:length(Mach)
    Cd.alt164000(i)=Cd.alt120000(i)+1.5*10^(-6)*44000;
end
dragcoef.alt5=pchip(Mach,Cd.alt164000);

%Saves each of the piecewise functions for the 5 different altitudes into a
%.mat file to be used in the function getdragcoef.m
%filename=sprintf('+artemis/+platforms/@MissilePlatform/DragCoefficientProfiles.mat');
%save(filename,'dragcoef');

%Mach number versus drag coefficient plots for various altitudes, should
%all have the same contour

% plot(Mach,Cd.alt0,'k'), hold on, xlabel('Mach Number'), ylabel('Drag Coefficient')

plot(Mach,Cd.alt50000,'r*-'), axis([0 10 .1 .4])
title('Drag Coefficient v. Mach Number'),xlabel('Mach Number'),ylabel('Drag Coefficient')
% plot(Mach,Cd.alt100000,'b')
% plot(Mach,Cd.alt120000, 'g'),legend('Sea Level','50000 feet','100000 feet','120000 feet','Location','NorthEast')
% plot(Mach,Cd.alt164000,'y')

