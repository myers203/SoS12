function color = getColorFromMap(colorMap, position)
assert((position >= 0) && (position <= 1), 'The colormap postion must be between 0 and 1, including 0 and 1');
% Create piecewise polys of the colormap RGB values
xData = linspace(0, 1, size(colorMap, 1));
rProfile = pchip(xData, colorMap(:, 1));
gProfile = pchip(xData, colorMap(:, 2));
bProfile = pchip(xData, colorMap(:, 3));

color(1) = ppval(rProfile, position);
color(2) = ppval(gProfile, position);
color(3) = ppval(bProfile, position);
end

