function [ out_ecef ] = circularDistribution(center_x_y,R,n_objects)

theta = linspace(0,2*pi,n_objects+1);
theta = theta(1:end-1); % We don't want any two objects ending on the same point since 0 and 2*pi are equivalent angles.

out_ecef = R*[cos(theta'), sin(theta')];

out_ecef = out_ecef + repmat(center_x_y,n_objects,1);

end

