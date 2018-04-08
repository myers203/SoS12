function [fig, handles] = plotWorld3d(world, varargin)
%PLOTWORLD3D Creates a 3D and mapped world model

scale = 1; % All units in meters
if numel(varargin) > 0
    if strcmp(varargin{1}, 'HD')
        mapFileName = 'Earth_HD.jpg';
    end
else
    mapFileName = 'Earth.png';
end

opengl hardware; % Hardware accelerated graphics, if available

% Create ellipsoid
fig = figure;
[x, y, z] = ellipsoid(0, 0, 0, world.getRadius() / scale, world.getRadius() / scale, world.getPolarRadius / scale, 100);
handles.world = surf(x, y, z);
handles.axis = gca;
handles.axis.Clipping = 'off';
image = imread(['+publicsim\+util\+visualization\maps\', mapFileName]);
set(handles.world, 'CData', flip(image, 1), 'EdgeColor', 'none', 'FaceColor', 'texturemap');
axis off;
axis equal;
hold on;

end

