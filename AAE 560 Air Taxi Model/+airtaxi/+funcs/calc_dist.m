function [ dist ] = calc_dist( loc1, loc2 )
%CALC_DIST Summary of this function goes here
%   Detailed explanation goes here
    dist = sqrt((loc1(1)-loc2(1))^2 + (loc1(2)-loc2(2))^2);
end

