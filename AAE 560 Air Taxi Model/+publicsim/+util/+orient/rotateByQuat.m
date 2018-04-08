function pPrime = rotateByQuat(p, q)
%ROTATEBYQUAT Rotates vector p by quaternion rotation q

if numel(p) ~= 3
    error('Vector must live in 3-space!');
end

R = [1 - 2 * (q(3)^2 + q(4)^2), 2 * (q(2) * q(3) - q(4) * q(1)), 2 * (q(2) * q(4) + q(3) * q(1)); ...
    2 * (q(2) * q(3) + q(4) * q(1)), 1 - 2 * (q(2)^2 + q(4)^2), 2 * (q(3) * q(4) - q(2) * q(1)); ...
    2 * (q(2) * q(4) - q(3) * q(1)), 2 * (q(3) * q(4) + q(2) * q(1)), 1 - 2 * (q(2)^2 + q(3)^2)];

if size(p, 1) == 3
    pPrime = R * p;
else
    pPrime = p * R;
end

end

