function earth_map(axis_handle,mapbounds, varargin)
%EARTH_MAP plots a surface colored to match the earth 
% axis_handle is the axis to plot on
% mapbounds is [1x4] of:
% [lat_min lon_min lat_max lon_max]
% or
% mapbounds is [1x6] of:
% [lat_min lon_min lat_max lon_max lat_grid_spacing lon_grid_spacing]
%
% All values of mapbounds in degrees
% ortho = imread('/maps/Earth2.png');

if numel(varargin) > 0
    if strcmp(varargin{1}, 'HD')
        mapFileName = 'Earth_HD.jpg';
    end
else
    mapFileName = 'Earth_2tone.png';
end

ortho = imread(['+publicsim/+util/+visualization/maps/', mapFileName]);
image_size = size(ortho(:,:,1));

held = ishold(axis_handle);

lat_lims = mapbounds([1 3]);
lon_lims = mapbounds([2 4]);

% Limit the limits to lat/long actual limits
lat_lims(1) = max([-90, lat_lims(1)]);
lat_lims(2) = min([90, lat_lims(2)]);
lon_lims(1) = max([-180, lon_lims(1)]);
lon_lims(2) = min([180, lon_lims(2)]);

if(length(mapbounds) > 4)
    lat_spacing = mapbounds(5);
    lon_spacing = mapbounds(6);
else  %default to 5 deg spacing
    lat_spacing = 5;
    lon_spacing = 5;
end

% Convert to indicies of the image
indx = round((lon_lims + 180) / 360 * image_size(2));
indy = -round((lat_lims - 90) / 180 * image_size(1));

% Eliminate any zeros
indx = indx + (indx == 0);
indy = indy + (indy == 0);


% Convert quantized values back to lat and lon limits
lon_lims = (indx / image_size(2)) * 360 - 180;
lat_lims = -(indy / image_size(1)) * 180 + 90;

vis2 = ortho(indy(2):indy(1),indx(1):indx(2),:);
[X,map] = rgb2ind(vis2,255);
colormap(map)

[xdata,ydata] = meshgrid(linspace(lon_lims(1), lon_lims(2), abs(diff(indx)) + 1),linspace(lat_lims(1), lat_lims(2), abs(diff(indy)) + 1));
Z = zeros(size(xdata));


surf(axis_handle,xdata,ydata,Z,flipud(X),...
    'FaceColor','texturemap',...
    'EdgeColor','none',...
    'CDataMapping','direct');

hold(axis_handle,'on')

x_grid = lon_lims(1)-lon_spacing:lon_spacing:lon_lims(2)+lon_spacing;
y_grid = lat_lims(1)-lat_spacing:lat_spacing:lat_lims(2)+lat_spacing;
mesh(axis_handle,x_grid,y_grid,zeros(length(y_grid),length(x_grid)),...
    'EdgeColor',[.7 .7 .7],'LineStyle',':','FaceColor','none')
set(axis_handle,'YLim',lat_lims,'XLim',lon_lims)
axis_handle.Clipping = 'off';
%Resets hold state
if(~held)
    hold(axis_handle,'off');
end
end


