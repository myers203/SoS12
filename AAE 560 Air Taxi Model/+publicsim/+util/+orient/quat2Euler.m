function [az, el, spin] = quat2Euler(q)
% Converts quaternion to precession, nutation, spin assuming 3-2-1 Euler rotation
% NOT ERROR CHECKED FOR SINGULARITIES
% Error check
elQ = 2 * (q(1) * q(3) - q(2) * q(4));
if norm(2 * (q(1) * q(3) - q(2) * q(4))) > 1
    elQ = 1 * sign(elQ);
end
el = asind(elQ);
az = atan2d((2 * (q(1) * q(2) + q(3) * q(4))), (1 - 2 * (q(2)^2 + q(3)^2)));
spin = atan2d((2 * (q(1) * q(4) + q(2) * q(3))), (1 - 2 * (q(3)^2 + q(4)^2)));

end

