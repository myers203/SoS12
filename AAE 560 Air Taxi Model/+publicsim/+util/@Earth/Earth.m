classdef Earth < handle
    % Earth
    %
    % MODEL OVERVIEW:                 
    % ---------------------------------------------------------------------
    % The Earth Model (EM) allows the user to choose the type of EM to use
    % and centralizes all the conversion, coordinate transformation, and
    % distance/bearing calculations. Current options are spherical and
    % elliptical (both non-rotating).
    %
    % INPUTS:
    % ---------------------------------------------------------------------
    % EM takes in the type of model desired. This is only allowed to be set
    % once per simulation run; any further attempts to change the EM result
    % in an error.
    %
    % MODEL FUNCTIONALITY:
    % ---------------------------------------------------------------------
    % Earth sets the EM to be used in a DAF instance and provides all the
    % necessary conversion tools agents and platforms could use. All
    % geospacial information or conversions agents/platforms need should
    % come through this model.
    %
    %                               
    % OUTPUTS:
    % ---------------------------------------------------------------------
    % Earth sets the EM used in a DAF instance.
    %
    %
    % NOTES:
    % ---------------------------------------------------------------------
    % Detailed topographical maps may be obtained from the Shuttle Radar
    % Topography Mission data (see http://www2.jpl.nasa.gov/srtm/ and
    % http://dds.cr.usgs.gov/srtm/). These may be useful for implementing
    % non-smooth EMs. Another possible source is DTED (Digital Terrain
    % Elevation Data), which is a National Geospacial-Intelligence Agency
    % product. Three format levels provide data of different accuracies.
    % (30m-900m spacing).

    properties
    end
    
    properties (Access = protected)
        % These are the properties that are set based on the EM chosen
        earth_type      % EM chosen (spherical, elliptical, etc.)
        earth_radius    % [m] mean Earth radius
        polar_radius    % [m] polar radius
        flattening_coef % flattening coefficient
        eccentricity2   % first eccentricity of ellipsoid, squared
        e2sqr           % second eccentricity of ellipsoid, squared
        ellipsoid       % ellipsoid array containing radius and eccentricity
        gravitational_mu % (m^3/s^2) Gravitational Parameter
    end
    
    properties (Access = protected, Hidden)
        model_set_flag = 0;
    end
    
    properties (Constant)
        rad2deg = 180/pi;   % convert radians to degrees
        deg2rad = pi/180;   % convert degrees to radians
    end
    
    properties (Constant, Hidden)
        EARTH_RADIUS = 6378137; % [m] mean Earth radius at the equator
        
        % Elliptical Earth based on WGS84 model
        POLAR_RADIUS = 6356752.3142; % [m] polar radius
        ELLIPTICAL_FLATTENING = 1/298.257223563; % Flattening coefficient used in WGS84 elliptical Earth model
        
        % Spherical Earth
        SPHERICAL_FLATTENING = 0; % Flattening coefficient used in spherical Earth model
        
        % Other Earth parameters
        MU_EARTH = 3.98600e14;   % (m^3/s^2) Gravitational Parameter
    end
   
    methods
        function obj = Earth()
            
        end
               
        function setModel(obj,earth_type)
            % Make sure this function can only be called once. The EM
            % should only be set once (when DAF instance is being built)
            % and never again.
            if obj.model_set_flag
                error(['+publicsim/+util/@Earth/' mfilename ': Earth model can only be set once. Something tried to call Earth.setModel again.'])
            end
            
            % In case no earth type is specified in call to this function,
            % set earth_type to 'unspecified'
            if nargin < 1
                earth_type = 'unspecified';
            end
            
            % Set the properties of the EM based on the model chosen
            switch lower(earth_type)
                case 'spherical'
                    obj.earth_type = earth_type;
                    obj.earth_radius = obj.EARTH_RADIUS;
                    obj.polar_radius = obj.EARTH_RADIUS; % recall this is spherical
                    obj.flattening_coef = obj.SPHERICAL_FLATTENING;
                case 'elliptical'
                    obj.earth_type = earth_type;
                    obj.earth_radius = obj.EARTH_RADIUS;
                    obj.polar_radius = obj.POLAR_RADIUS;
                    obj.flattening_coef = obj.ELLIPTICAL_FLATTENING;
                otherwise
                    disp('Earth model not specified or unavailable, defaulting to elliptical')
                    obj.earth_type = 'elliptical';
                    obj.earth_radius = obj.EARTH_RADIUS;
                    obj.polar_radius = obj.POLAR_RADIUS;
                    obj.flattening_coef = obj.ELLIPTICAL_FLATTENING;
            end
            obj.eccentricity2 = 1 - (1 - obj.flattening_coef)^2;
            obj.e2sqr = obj.eccentricity2 / (1 - obj.eccentricity2);
            obj.ellipsoid = [obj.earth_radius sqrt( 1 - ( 1 - obj.flattening_coef )^2 )];
            
            obj.gravitational_mu = obj.MU_EARTH;
            
            % Now that the EM has been set, flip the flag to make sure this
            % function cannot be called again.
            obj.model_set_flag = 1;
        end
    end
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%% CONVERSION TOOLS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    methods     % Functions are listed in alphabetical order
        function target_ecef = convert_azelr2ecef(obj,lla,azimuth,elevation,range)
            % Converts sensor position [deg deg m] and local azimuth angle
            % [deg], elevation angle [deg], and slant range [m] into an
            % ECEF position [m m m].
            
            source_ecef = obj.convert_lla2ecef(lla);
            DCM_ECEF2NED = obj.convert_lla2dm(lla);
            
            azMat   = [cosd(azimuth) -sind(azimuth) 0; sind(azimuth) cosd(azimuth) 0; 0 0 1];
            elevMat = [cosd(elevation) 0 sind(elevation); 0 1 0; -sind(elevation) 0 cosd(elevation)];
            localVel = azMat*elevMat*[range;0;0];
            
            target_ecef = source_ecef+localVel'*DCM_ECEF2NED;
        end
        
        function [azimuth, elevation, range] = convert_ecef2azelr(obj, source_ecef, target_ecef)
            % Returns the azimuth [deg], elevation [deg], and range [m]
            % from one (source) ECEF location [m m m] to a target ECEF
            % location [m m m].
            
            source_lla = obj.convert_ecef2lla(source_ecef);
            target_lla = obj.convert_ecef2lla(target_ecef);
            
            [azimuth, elevation, range] = obj.convert_lla2azelr(source_lla,target_lla);
        end
        
        function lla = convert_ecef2lla(obj,ecef)
            % Converts from ECEF [m m m] to LLA. ecef is an n x 3 matrix 
            % where n different ECEF locations can be specified. lla is
            % also an n x 3 matrix [deg deg m].
            %
            % References
            % ---------
            % * Paul R. Wolf and Bon A. Dewitt, "Elements of Photogrammetry with
            % Applications in GIS," 3rd Ed., McGraw-Hill, 2000 (Appendix F-3).
            % * Bowring, B.R. (1985) "The Accuracy of Geodetic Latitude and
            % Height Equations," Survey Review, vol. 28, no. 218, pp. 202-206.
            
            x = ecef(:,1);
            y = ecef(:,2);
            z = ecef(:,3);
            
            % Ellipsoid parameters
            f = obj.flattening_coef;
            e2 = obj.eccentricity2;
            ep2 = obj.e2sqr;
            
            % Distance from Z-axis
            rho = hypot(x,y);
            
            % Bowring's formula for initial parametric (beta) and geodetic (phi) latitudes
            beta = atan2(z, (1 - f) * rho);
            phi = atan2(z + obj.polar_radius * ep2 * sin(beta).^3,...
                      rho - obj.earth_radius * e2  * cos(beta).^3);
            
            % Fixed-point iteration with Bowring's formula
            % (typically converges within two or three iterations)
            betaNew = atan2((1 - f)*sin(phi), cos(phi));
            count = 0;
            while any(beta(:) ~= betaNew(:)) && count < 5
                beta = betaNew;
                phi = atan2(z + obj.polar_radius * ep2 * sin(beta).^3,...
                          rho - obj.earth_radius * e2  * cos(beta).^3);
                betaNew = atan2((1 - f)*sin(phi), cos(phi));
                count = count + 1;
            end
            
            % Calculate ellipsoidal height from the final value for latitude
            sinphi = sin(phi);
            N = obj.earth_radius ./ sqrt(1 - e2 * sinphi.^2);
            alt = rho .* cos(phi) + (z + e2 * N .* sinphi) .* sinphi - N;
            
            lat = phi .* obj.rad2deg;
            lon = atan2(y,x) .* obj.rad2deg;
            lla = [lat lon alt];
        end
        
        function [AzimuthAngle, ElevationAngle, SlantRange] = convert_lla2azelr(obj,lla1,lla2)
            % Computes the azimuth angle, elevation angle, and slant range
            % of Point 2 from the viewpoint of Point 1. Inputs lla1 and
            % lla2 are vectors of the form [latitude longitude altitude].
            % The altitudes are height (in meters) and the lat and lon
            % values are in degrees.  The output azimuth and elevation
            % angles are in degrees and the slant range in meters.
            
            % Check that the input is formatted correctly
            if size(lla1,1) ~= 1 || size(lla1,2) ~= 3 || size(lla2,1) ~= 1 || size(lla2,2) ~= 3
                error('convert_lla2azelr can accept only one LLA pair')
            end
            
            % Change the latitude and longitude angles from degrees to radians
            phi1 = lla1(1) * obj.deg2rad;
            lambda1 = lla1(2) * obj.deg2rad;
            
            Angle1 = [sin(phi1),cos(phi1),sin(lambda1),cos(lambda1)];
            
            % get the ECEF coordinates
            ecef = obj.convert_lla2ecef([lla1 ; lla2]);
            
            % Calculate the difference between the point 2 and the local (point 1)
            [x, y, z] = obj.getPoint(ecef(1,1), ecef(1,2), ecef(1,3), ecef(2,1), ecef(2,2), ecef(2,3), Angle1);
            
            % Convert to spherical coordinates from Cartesian and angles to degrees.
            % The azimuth angle limits are [-180,180].
            r = hypot(x,y);
            SlantRange = hypot(r,z);
            ElevationAngle = atan2(z,r) * obj.rad2deg;
            AzimuthAngle = atan2(x,y) * obj.rad2deg;
        end
        
        function [azelr_mat] = getTrajAzElR(obj,sensor_ecef,traj_ecef)
            % take a sensor ECEF vector, and an array of trajectory ecef
            % values (n x 3) and generates an n x 3 az, el, r matrix.
            
            assert(length(sensor_ecef)==3);  % make sure we get what we ask for
            assert(size(traj_ecef,2)==3);
            
            azelr_mat = nan(size(traj_ecef));
            sensor_lla = obj.convert_ecef2lla(sensor_ecef);
            
            phi    = sensor_lla(1) * obj.deg2rad;
            lambda = sensor_lla(2) * obj.deg2rad;
            
            angle = [sin(phi), cos(phi), sin(lambda), cos(lambda)];
            
            for i = 1:size(traj_ecef,1)
                current_threat_ecef = traj_ecef(i,:);
                [x, y, z] = obj.getPoint(sensor_ecef(1), sensor_ecef(2), sensor_ecef(3),...
                    current_threat_ecef(1), current_threat_ecef(2), current_threat_ecef(3), angle);
                
                r = hypot(x,y);
                slant_range     = hypot(r,z);
                elevation_angle = atan2(z,r) * obj.rad2deg;
                azimuth_angle   = atan2(x,y) * obj.rad2deg;
                
                local_azelr = [azimuth_angle, elevation_angle, slant_range];
                azelr_mat(i,:) = local_azelr;
            end
            
            
            
        end
        
        function dcm = convert_lla2dm(obj, lla)
            % Converts latitude and longitude to direction cosine matrix.
            % lla is an n x 3 matrix with n different locations [deg deg m]
            % specified. dcm is a 3 x 3 x n matrix containing M direction
            % cosine matrices.
            %
            % dcm is used for coordinate transformation of a vector in ECEF
            % into a vector in north-east-down (NED) axes.
            % 
            % NOTE: No EM dependence
            
            angles = [lla(:,1) lla(:,2)] .* obj.deg2rad;
            
            dcm = zeros(3,3,size(angles,1));
            cang = cos( angles );
            sang = sin( angles );
            
            dcm(1,1,:) = -cang(:,2).*sang(:,1);
            dcm(1,2,:) = -sang(:,2).*sang(:,1);
            dcm(1,3,:) = cang(:,1);
            dcm(2,1,:) = -sang(:,2);
            dcm(2,2,:) = cang(:,2);
            dcm(2,3,:) = 0.0;
            dcm(3,1,:) = -cang(:,2).*cang(:,1);
            dcm(3,2,:) = -sang(:,2).*cang(:,1);
            dcm(3,3,:) = -sang(:,1);
        end
        
        function rECEF = convert_lla2ecef(obj,lla)
            % Converts latitude-longitude-altitude [deg deg m] to ECEF.
            % lla coordinates are in an n x 3 matrix where n different LLA
            % locations can be specified. rECEF is also an n x 3 matrix.
            phi = lla(:,1);
            lambda = lla(:,2);
            h = lla(:,3);
            
            sinphi = sind(phi);
            cosphi = cosd(phi);
            N  = obj.earth_radius ./ sqrt(1 - obj.eccentricity2 * sinphi.^2);
            x = (N + h) .* cosphi .* cosd(lambda);
            y = (N + h) .* cosphi .* sind(lambda);
            z = (N*(1 - obj.eccentricity2) + h) .* sinphi;
            
            rECEF = [x y z];
        end
        
        function [x,y,z] = convert_enu2ecef(obj,e,n,u,lat,lon,alt)
            % This function converts a local East-North-Up Reference to
            % ECEF using the current earth model for reference
            
            % First, convert the position on the globe to ECEF
            rECEF = obj.convert_lla2ecef([lat,lon,alt]);
%             rECEF(3) = rECEF(3)/1000;
            % Create the DCM to change to ECEF
            DCM = [-sind(lon), -sind(lat)*cosd(lon), cosd(lat)*cosd(lon);...
                    cosd(lon) ,-sind(lat)*sind(lon), cosd(lat)*sind(lon);...
                    0         , cosd(lat)          , sind(lat)];
                
            % Initialize outputs
            x = zeros(size(e,1),size(e,2));
            y = zeros(size(e,1),size(e,2));
            z = zeros(size(e,1),size(e,2));

            % Iterate over all columns and transform ENU components to ECEF
            for i = 1:size(e,2) % Number of columns
                enu = [e(:,i), n(:,i), u(:,i)]'; % [3xn] vector;
                ecef = DCM*enu + repmat(rECEF',1,size(e,1));
                x(:,i) = ecef(1,:)';
                y(:,i) = ecef(2,:)';
                z(:,i) = ecef(3,:)';
            end
        end
        
        function [lat2, lon2, varargout] = fwdGeodesic(obj, lat1, lon1, az, range)
            % Calculates the lat/lon from a given point, range, and azimuth
            [lat2, lon2, backAz] = obj.forwardGeodesic(lat1, lon1, az, range, obj.ellipsoid);
            varargout{1} = backAz;
        end
        
        function [d,varargout] = gcdist(obj,lat1, lon1, lat2, lon2)
            % Calculate an approximate geodesic (great circle-like)
            % distance between points on an ellipsoid. lat1, lon1, lat2,
            % and lon2 are in degrees. Inputs can be scalars or vectors of
            % equivalent length.
            %
            % d is a length and has the same units as the semi-major axis
            % of the ellipsoid (usu. meters). If the inputs are vectors, d
            % will be a vector of the same length. fwd_az is the azimuth
            % bearing from Location 1 to Location 2 and back_az is the same
            % from Location 2 to Location 1.
            
            [d, fwd_az, back_az] = obj.inverseGeodesic(lat1, lon1, lat2, lon2,obj.ellipsoid);
            varargout{1} = fwd_az;
            varargout{2} = back_az;
        end
        
        function [ rECEF, evECEF ] = getrvECEF(obj, lla, Az, Elev, Speed)
            % Converts LLA and Azimuth/Elevation(Attitude, in degrees) with
            % Speed information to XYZ coordinates in the ECEF frame and
            % velocity relative to a fixed earth expressed in ECEF
            
            rECEF = obj.convert_lla2ecef(lla);
            DCM_ECEF2NED = obj.convert_lla2dm(lla);
            
            azMat   = [cosd(Az) -sind(Az) 0; sind(Az) cosd(Az) 0; 0 0 1];
            elevMat = [cosd(Elev) 0 sind(Elev); 0 1 0; -sind(Elev) 0 cosd(Elev)];
            localVel = azMat*elevMat*[Speed;0;0];
            
            evECEF = DCM_ECEF2NED'*localVel;
        end
        
        function deg = m2deg(obj,m)
            % Converts distances from meters to degrees as measured along a
            % great circle on a spherical Earth.
            %
            % ASSUMES SPHERICAL EARTH
            %
            % Future: Can this work with another EM?
            
            deg = (m / obj.earth_radius) * obj.rad2deg;
        end
        
    end
    
    methods(Static)
        function distm = ecef_distance(ecef1,ecef2)
            % Returns the straight-line distance (in meters) between two
            % locations, expressed in ECEF locations.
            
            distm = sqrt((ecef1(1)-ecef2(1))^2 + (ecef1(2)-ecef2(2))^2 + (ecef1(3)-ecef2(3))^2);
        end
        
        function [x, y, z] = getPoint(x1, y1, z1,x2, y2, z2,Angle1)
            % Calculates the Cartesian difference between points 2 and 1 in
            % the local frame.
            %
            
            % Calculate the matrix for conversion to the local vertical
            % frame from the Cartesian geocentric.   
            M = [-Angle1(3) Angle1(4)  0;
                 -Angle1(1)*Angle1(4) -Angle1(1)*Angle1(3) Angle1(2);
                  Angle1(2)*Angle1(4)  Angle1(2)*Angle1(3) Angle1(1)];
            
            P = [x2 - x1 ; y2 - y1 ; z2 - z1];
            P = M*P;
            
            x = P(1);
            y = P(2);
            z = P(3);
        end
        
        [range, az12, az21] = inverseGeodesic(lat1,lon1,lat2,lon2,ellipsoid);
        [lat2, lon2, varargout] = forwardGeodesic(lat1, lon1, az, range, ellipsoid);
    end
    
    methods     % Misc getters
        function ellipsoid = getEllipsoid(obj)
            ellipsoid = obj.ellipsoid;
        end
        
        function earth_type = getType(obj)
            earth_type = obj.earth_type;
        end
        
        function earth_radius = getRadius(obj)
            earth_radius = obj.earth_radius;
        end
        
        function grav = getGravParam(obj)
            grav = obj.gravitational_mu;
        end
        
        function polarRadius = getPolarRadius(obj)
            polarRadius = obj.polar_radius;
        end
    end
end