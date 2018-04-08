classdef Conical < publicsim.funcs.geometric.frustum.Frustum
    %CONICAL Conical frustum
    
    properties (SetAccess = private)
        fieldOfView; % [deg] Angle of the cone at its vertex
        line; % Pointing line of the cone, in direction of cone opening
    end
    
    methods
        
        function obj = Conical(varargin)
            % Create the cone
            obj@publicsim.funcs.geometric.frustum.Frustum(varargin{:});
            obj.line = publicsim.funcs.geometric.euclidean.Line();
        end
        
        function setFieldOfView(obj, fov)
            % Set the field of view
            assert(fov <= 90, 'Cone apex angle cannot exceed 90 degrees!');
            obj.fieldOfView = fov;
        end
        
        function setPosition(obj, position)
            setPosition@publicsim.funcs.geometric.frustum.Frustum(obj, position);
            if ~isempty(obj.line.slope)
                obj.orientFrustum(obj.line.slope);
            end
        end
        
        function orientFrustum(obj, pointingVector)
            % Align the frustum to the vector
            obj.line.constructFromVectors(obj.position, pointingVector);
        end
        
        function bool = isPointInFrustum(obj, points)
            % Returns a boolean array of the points in the frustum
            bool = false(1, size(points, 1));
            for i = 1:size(points, 1)
                [dist, ~, t] = obj.line.distToPoint(points(i, :));
                rad = obj.getRadiusAtDistance(t);
                bool(i) = dist <= rad;
            end
        end
        
        function fh = plot(obj, varargin)
            warning('This does not work yet!');
            return
            if ~isempty(varargin)
                fh = varargin{:};
                xl = xlim;
                yl = ylim;
                zl = zlim;
            else
                fh = figure;
                
                xl = [-10 10] + obj.spatial.position(1);
                yl = [-10 10] + obj.spatial.position(2);
                zl = [-10 10] + obj.spatial.position(3);
            end
            
            figure(fh);
            hold on;
            dist = 1e3; % Large distance from the cone
            
            nRotations = 24;
            
            x = zeros(1 + nRotations, 1);
            y = zeros(1 + nRotations, 1);
            z = zeros(1 + nRotations, 1);
            k = zeros(nRotations);
            x(1) = spatial.position(1);
            y(1) = spatial.postiion(2);
            z(1) = spatial.position(3);
            
            theta = 0;
            dTheta = 360 / nRotations;
            rad = obj.getRadiusAtDistance(dist);
            for i = 2:nRotations + 1;
                theta = theta + dTheta;
            end
            
        end
    end
    
    methods (Access = private)
        function r = getRadiusAtDistance(obj, distance)
            % Returns the radius of the cone at a distance along the centerline
            if obj.fieldOfView == 90
                r = inf;
            else
                r = tand(obj.fieldOfView) * distance;
            end
        end
    end
    
    %%%% TEST METHODS %%%%
    
    methods (Static, Access = {?publicsim.tests.UniversalTester})
        function tests = test()
            % Run all tests
            tests{1} = 'publicsim.funcs.geometric.frustum.Conical.testConical';
        end
    end
    
    methods (Static)
        function testConical()
            % Test conical methods
            
            % Create an array of points
            x = linspace(-5, 5, 10);
            [x, y, z] = meshgrid(x, x, x);
            x = reshape(x, numel(x), 1);
            y = reshape(y, numel(y), 1);
            z = reshape(z, numel(z), 1);
            
            initState.position = [-4 -5 -3];
            
            % Make a conical
            cone = publicsim.funcs.geometric.frustum.Conical();
            cone.setFieldOfView(20);
            cone.setPosition(initState.position);
            cone.orientFrustum([1, 0.4, 1]);
            inCone = cone.isPointInFrustum([x y z]);
            
            figure;
            hold on;
            for i = 1:numel(inCone)
                if inCone(i)
                    color = 'g';
                else
                    color = 'r';
                end
                plot3(x(i), y(i), z(i), 'Marker', '.', 'Color', color);
            end
        end
    end
    
end

