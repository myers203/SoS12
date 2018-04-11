function [ dist ] = calc_dist3d( loc1, loc2 )
%CALC_DIST3D Summary of this function goes here
%   Detailed explanation goes here

    dist = sqrt((loc1(1)-loc2(1))^2 + ...
        (loc1(2)-loc2(2))^2 + ...
        (loc1(3)-loc2(3))^2);
end
