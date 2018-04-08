function new_azimuth_vect = fixAzimuthBounds( azimuth_vect )
% could do this smarter, whatever.  Will fix later.
new_azimuth_vect = nan(size(azimuth_vect));

for i = 1:numel(azimuth_vect)
        az = azimuth_vect(i);
        while az > 180
            az = az-360;
        end
        
        while az <= -180
            az = az+360;
        end
        new_azimuth_vect(i) = az;
end


