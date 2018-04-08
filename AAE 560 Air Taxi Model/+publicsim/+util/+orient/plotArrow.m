function plotArrow(fig, from, q, length)
%PLOTARROW Plots an arrow with quaternions

if nargin < 4
    length = 1;
end

[az, el, spin] = publicsim.util.orient.quat2Euler(q);
vect = length * [cosd(az) * cosd(el) , sind(az) * cosd(el), sind(el)];
to = from + vect;

figure(fig);

x = [from(1), to(1)];
y = [from(2), to(2)];
z = [from(3), to(3)];

h = plot3(x, y, z);

% Now make the little arrow portion


length = length * 0.1;
q1 = publicsim.util.orient.azEl2Quat(0, 90, 0);
%q2 = publicsim.util.orient.azEl2Quat(spin - 90, 90, 0);
vect = publicsim.util.orient.rotateByQuat(vect / norm(vect), publicsim.util.orient.multiplyQuats(q, q1));
vect = length * vect;

from = to; % New start point
to = from + vect;
x = [from(1), to(1)];
y = [from(2), to(2)];
z = [from(3), to(3)];

plot3(x, y, z, 'Color', h.Color);
end

