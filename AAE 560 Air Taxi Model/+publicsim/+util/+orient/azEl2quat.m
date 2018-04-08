function q = azEl2Quat(az, el, spin)
% Converts azimuth, elevation to quaternion. Input in degrees

% Primary rotation through azimuth
% Secondary rotation through elevation
% Tertiary rotation through spin (optional)

% Equivalent to Euler Body 3-2-1 rotation sequence by angles psi, theta,
% and phi, respectively (rotating in order: 3, 2, 1)

psi = deg2rad(az);
theta = deg2rad(el);
if nargin == 2
    spin = 0;
end
phi = deg2rad(spin);

c1 = cos(psi / 2);
c2 = cos(theta / 2);
c3 = cos(phi / 2);
s1 = sin(psi / 2);
s2 = sin(theta / 2);
s3 = sin(phi / 2);

q = zeros(1, 4);
q(1, 1) = c1 * c2 * c3 + s1 * s2 * s3;
q(1, 2) = -c1 * s2 * s3 + s1 * c2 * c3;
q(1, 3) = c1 * s2 * c3 + s1 * c2 * s3;
q(1, 4) = c1 * c2 * s3 - s1 * s2 * c3;

% Assertive normalization procedure to avoid imaginary numbers in future
% operations
n = norm(q);
q = q ./ n;

assert(abs(norm(q)) - 1 < 1e-10, 'Invalid quaternion!');
end

