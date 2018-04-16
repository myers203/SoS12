classdef Convert
    % Functions to convert units and transform frames
     methods (Static)
        function [val] = unit(input)
            switch input
                % Angle
                case 'rad2deg', val = 180/pi;        % convert from radians to degrees
                case 'deg2rad', val = pi/180;        % convert from degrees to radians
                
                % Length
                case 'ft2m',    val = 0.3048;        % convert from feet to meters
                case 'm2ft',    val = 3.2808399;     % convert from meters to feet
                case 'ft2nmi',  val = 0.00016458;    % convert from feet to nautical miles
                case 'nmi2ft',  val = 6076.11549;    % convert from nautical miles to feet
                case 'nmi2m',   val = 1852;          % convert from nautical miles to meters
                case 'm2nmi',   val = 0.00053996;    % convert from meters to nautical miles
                case 'mi2m',    val = 1609.344;      % convert from miles to meters
                case 'm2mi',    val = 0.00062137;    % convert from meters to miles
                case 'm2deg',   val = 8.99327e-6;    % convert from meters to degree lat long
                case 'deg2m',   val = 1.11194e05;    % convert from degree lat long to meters
                case 'mi2km',   val = 1.60934;       % convert from miles to kilometers
                
                % Speed
                case 'kts2mps', val = 0.51444444;    % convert from knots to m/s
                case 'mps2kts', val = 1.94384449;    % convert from m/s to knots
                case 'kts2mph', val = 1.15077945;    % convert from knots to miles/hr
                case 'mph2kts', val = 0.86897624;    % convert from miles/hr to knots
                case 'kph2mps', val = 0.277778;      % convert from km/hr to m/s
                % Time
                case 'hr2min',  val = 60;            % convert from hours to minutes
                case 'min2hr',  val = 1/60;          % convert from minutes to hours
                case 'min2s',   val = 60;            % convert from minutes to seconds
                case 's2min',   val = 1/60;          % convert from seconds to minutes
                case 'hr2s',    val = 3600;          % convert from hours to seconds
                case 's2hr',    val = 1/3600;        % convert from seconds to hours
                
                otherwise,      keyboard             % invalid option
            end
        end
    end
end