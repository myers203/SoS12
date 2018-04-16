function [m,b] = slopeInterceptFromPoints(p1,p2)
%SLOPEINTERCEPT Summary of this function goes here
%   Detailed explanation goes here
    coeffs = polyfit([p1(1) p2(1)],[p1(2) p2(2)],1);
    m = coeffs(1);
    b = coeffs(2);    
end
