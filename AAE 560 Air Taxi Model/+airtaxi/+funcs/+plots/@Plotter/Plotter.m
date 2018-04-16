classdef Plotter < handle
    %PLOTTER Summary of this class goes here
    %   Detailed explanation goes here
    properties
        traj
        marker
        plot_interval; % [s]
        plot_handle
        traj_handle
        id_handle
    end
    
    properties (Access = private)
        last_update_time
        convert = airtaxi.util.Convert;
    end
    methods
        function obj = Plotter(marker) 
            obj.marker         = marker;
            obj.traj           = [];
            obj.plot_interval  = 20; % [s]
        end
        
        % Update current location for AC w/marker
        function updatePlot(obj,pos)
            x = pos(1); y = pos(2); z = pos(3);
            if isempty(obj.plot_handle)
                obj.traj(end+1,:) = [x,y,z];
                obj.plot_handle = plot3(x,y,z,'Marker',obj.marker.type,'MarkerSize',obj.marker.size,...
                    'MarkerEdgeColor',obj.marker.edgeColor,'MarkerFaceColor',obj.marker.faceColor);
                obj.traj_handle = plot3(obj.traj(:,1),obj.traj(:,2),obj.traj(:,3),'k-');
                drawnow
            else
                obj.traj(end+1,:) = [x,y,z];
                set(obj.plot_handle,'XData',x,'YData',y,'ZData',z,'Marker',obj.marker.type,'MarkerFaceColor',obj.marker.faceColor)
                set(obj.traj_handle,'XData',obj.traj(:,1),'YData',obj.traj(:,2),'ZData',obj.traj(:,3))
            end
            if isfield(obj.marker,'id_text')
                if isempty(obj.id_handle)
                    obj.id_handle = text(x,y-1,obj.marker.id_text,'Color',[0 0 0]);
                else
                    obj.id_handle.Position = pos - [0 1 0];
                end
            end
        end
    end
    
    methods (Static)
        % Create plot for simulation, assign colors to AC by giving them Plotter objs
        function setup(map,acAgents,portAgents,bounds)
            % Open Figure
            % Close all open figures 
%             delete(findall(0,'Type','figure','Name','Air Taxi Sim'))
            delete(findall(0,'Type','figure'));
            fig = figure('Name', 'Air Taxi Sim');box on; hold on;grid on;
            fig.Units = 'inches';
            fig.Position(3) = 10;
            fig.Position(4) = 7;
            axis equal;
            movegui(fig,'center')
%             xlabel('X [nMi]');ylabel('Y [nMi]')
        
            size_label = 12;
           
            
            nAC   = length(acAgents);
            nPort = length(portAgents);
            
            
            
            % Colors for each AC team
            ac_color = ['r','b','g','y','c','k',...
                'r','b','g','y','c','k'];
            
            % Set plot properties for ports
            port_marker.type      = 'd';
            port_marker.size      =  20;
            port_marker.edgeColor = 'k';
            port_marker.faceColor = 'k';
            for ii = 1:nPort
                port_marker.id_text   = num2str(ii);
                plotter = airtaxi.funcs.plots.Plotter(port_marker);
                portAgents{ii}.setPlotter(plotter);
                loc = portAgents{ii}.getLocation();
                plot(loc(1),loc(2),'Marker',port_marker.type,'MarkerSize',port_marker.size,...
                    'MarkerEdgeColor',port_marker.edgeColor,'MarkerFaceColor',port_marker.faceColor);
                text(loc(1),loc(2),num2str(ii),'Color',[1 1 1]);
            end
            
            % Set color for AC plot
            ac_marker.type = 's';
            ac_marker.size = 9;
            ac_marker.edgeColor = 'k';
            for ii=1:nAC
%                 ac_marker.faceColor = ac_color(acAgents{ii}.parent.team_id);
                ac_marker.faceColor = acAgents{ii}.getColor;
                ac_marker.id_text   = ['AC',num2str(acAgents{ii}.ac_id)];
                plotter = airtaxi.funcs.plots.Plotter(ac_marker);
                acAgents{ii}.setPlotter(plotter);
                loc = acAgents{ii}.getLocation();
                plotter.updatePlot(loc);
%                 plot(loc(1),loc(2),'Marker',ac_marker.type,'MarkerSize',ac_marker.size,...
%                     'MarkerEdgeColor',ac_marker.edgeColor,'MarkerFaceColor',ac_marker.faceColor);
            end
            
            
              xlim(bounds.xLim);
              ylim(bounds.yLim);
              xlabel('X [nMi]'); ylabel('Y [nMi]');
        end
    end
end
