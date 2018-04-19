function dist = min_dist( track1, t1_speed, track2, t2_speed, n )
%MIN_DIST Summary of this function goes here
%   Detailed explanation goes here
    d1 = linspace(0,t1_speed,n)';
    d2 = linspace(0,t2_speed,n)';
    
    % distance between each point along the trajectory
    d = (track2.P0 + d2 .* track2.v) - (track1.P0 + d1 .* track1.v);
    dist = min(sqrt(sum(d.*d,2)));   % minimum norm of each vector
end