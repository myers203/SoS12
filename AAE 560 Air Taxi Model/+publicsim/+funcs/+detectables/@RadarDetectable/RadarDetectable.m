classdef RadarDetectable < handle
    %RadarDetectable Makes an object detectable to radar
    
    properties (SetAccess = private)
        length
        width
        polygon = 'cylinder';
        major_axis
    end
    
    properties (Constant)
       pi = 3.141592653; 
    end
    
    methods
        function obj = RadarDetectable()
            %consider making polygon, length, and width immutable
            %properties.  Any reason these should change during a sim?
        end
        
        function setDimensions(obj,length,width)
           assert(isnumeric(length) && numel(length)==1); 
           assert(isnumeric(width) && numel(width)==1); 
           
           obj.length = length;
           obj.width = width;
        end
        
        function length=getLength(obj)
            length=obj.length;
        end
        
        function width=getWidth(obj)
            width=obj.width;
        end
        
        function setPolygon(obj,polygon)
            % for use with getting the projected RCS
            assert(ischar(polygon) && numel(polygon)==1);
            obj.polygon = polygon;
        end
           
        function setHeading(obj,heading_vector)
            
            assert(numel(heading_vector) == 3)
            if norm(heading_vector)~=1
               heading_vector = heading_vector/norm(heading_vector);
            end
            
            if size(heading_vector,2)~=3
               heading_vector = heading_vector'; 
            end
            
            % Assume the heading and the major axis are equivalent.
            obj.major_axis = heading_vector;
            
        end
        
        function rcs = getRCS(obj,radar_position,target_position,signal_wavelength)

            aspect_angle = obj.getAspectAngle(radar_position, target_position);
            
            
            switch obj.polygon
                case 'cylinder'
                    % assume target is a cylinder with a circular flat
                    % plate
                    % perhaps cylinder with a cone is more appropriate
                    radius = obj.width/2;
                    wavenumber = 2*obj.pi/signal_wavelength;
                    if aspect_angle == 90
                        % 2.48 in Radar Systems Design & Analysis using Matlab
                        rcs_cyl = wavenumber*radius*obj.length^2;
                    else
                        % 2.49 in Radar Systems Design & Analysis using Matlab
                        rcs_cyl = signal_wavelength*radius*sind(aspect_angle)/...
                            (8*obj.pi*cosd(aspect_angle)^2);
                    end
                    if aspect_angle == 0
                        % 2.35 in Radar Systems Design & Analysis using Matlab
                        rcs_circ_flat_plate = wavenumber^2*obj.pi*radius^4;
                    else
                        % 2.36 in Radar Systems Design & Analysis using Matlab
                        rcs_circ_flat_plate = signal_wavelength*radius/...
                            (8*obj.pi*sind(aspect_angle)*tand(aspect_angle)^2);
                    end
                    % TO DO - verify if addition is legitimate
                    % Based on listing 2.10 in Radar Systems Design & Analysis using Matlab
                    % simply add rcs of simple objects
                    rcs = rcs_circ_flat_plate+rcs_cyl;
                case 'sphere'
                    radius = obj.width/2;
                    % 2.29 in Radar Systems Design & Analysis using Matlab
                    rcs = obj.pi*radius^2;
                case 'ellipsoid'
                    radius = obj.width/2;
                    % 2.29 in Radar System Analysis & Design using Matlab
                    a_axis = radius;
                    % assume ellipsoid is roll symmetric
                    b_axis = a_axis;
                    c_axis = obj.length/2;
                    rcs = obj.pi*b_axis^4*c_axis^2/...
                        (a_axis^2*sind(aspect_angle)^2+...
                        c_axis^2*cosd(aspect_angle)^2)^2;
                    
                otherwise
                    error('Unsupported polygon type!');
            end
            
        end
        
        function angle = getAspectAngle(obj, radar_position, target_position)
            assert(numel(radar_position) == 3)
            
            if isempty(obj.major_axis)
               error('Major axis/Heading is undefined!'); 
            end
            
            if size(radar_position,2)~=3
                radar_position = radar_position';
            end
            
            vector_to_radar = radar_position-target_position;
            
            vector_in_projection_plane = cross(vector_to_radar,obj.major_axis);
            
            reference_vector = cross(vector_in_projection_plane,vector_to_radar);
            
            angle = acosd( (reference_vector*obj.major_axis') / ( norm(reference_vector)*norm(obj.major_axis) ));
            
            % this projection is less than 90 deg
            
            if angle > 90
                angle = 180-angle;
            end
            
            if isnan(angle)
                angle=0;
            end
            
            assert(angle<=90,'Bad aspect angle calculation!'); %if this isn't true, I screwed up.
        end
        
    end
    
    methods(Static)
        function radarDetectableTest()
            
            radar_position = [0 0 0];
            target_position = [10 10 0];
            test_heading = [0 1 0];
            
            a = publicsim.funcs.detectables.RadarDetectable();
            a.setHeading(test_heading);
            
            aspect_angle = a.getAspectAngle(radar_position,target_position);
            
            assert(aspect_angle-45 <= 1e-10);
            
            disp('Passed RadarDetectable test!');
            
        end
    end
end

