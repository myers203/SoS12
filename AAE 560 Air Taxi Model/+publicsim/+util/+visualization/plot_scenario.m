function plot_scenario(d)

in = inputParser;
in.addRequired('d', @(x) isa(x,'daf.DAF'));
in.parse(d);

import artemis.*;
figure('NumberTitle', 'off', 'Name','Scenario Map')
ax = axes;

hold all
platform_data=artemis.Platform.loadLogFile(strcat(d.log_name,'_platforms.dat'));
missile_handles = [];
missile_names = {};
interceptor_handles = [];
interceptor_names = {};
stage_handles = [];
stage_names = {};
j = 0;
k = 0;
l = 0;

max_x = -inf;
min_x = inf;
max_y = -inf;
min_y = inf;

for i = 1:length(d.groups)
    if(isa(d.groups{i},'artemis.platforms.MissilePlatform'))
        if(d.groups{i}.isThreat || isempty(keys(d.groups{i}.agentMap)))
            j = j+1;
            if isfield(d.groups{i}.trajectory_data,'death_N')
                terminate = d.groups{i}.trajectory_data.death_N;
            elseif d.end_time < d.groups{i}.trajectory_data.time(end)
                [~,terminate] = min((d.groups{i}.trajectory_data.time-d.end_time).^2);
            else
                terminate = d.groups{i}.trajectory_data.N;
            end
            
            missile_handles(j) = plot3(d.groups{i}.trajectory_data.LLA(1:terminate,2),...
                d.groups{i}.trajectory_data.LLA(1:terminate,1),...
                d.groups{i}.trajectory_data.LLA(1:terminate,3)/1000,'r'); %,'MarkerSize',plot_size);
            missile_names{j} = sprintf('Threat %i',j);
            
            % To dynamically assign axes
            max_x = max([d.groups{i}.trajectory_data.LLA(:,2);max_x]);
            max_y = max([d.groups{i}.trajectory_data.LLA(:,1);max_y]);
            min_x = min([min_x;d.groups{i}.trajectory_data.LLA(:,2)]);
            min_y = min([min_y;d.groups{i}.trajectory_data.LLA(:,1)]);
        else % 'Interceptor' missiles contain an 'Interceptor' agent
            k = k+1;
            
            % find intercept time
            int_agent_name = keys(d.groups{i}.agentMap);
            int_agent = d.findAgentByKey(int_agent_name{1});
            
            % This might not be necessary anymore due to trajectory
            % termination, leaving it pending further testing.
            
%             int_agent.missed_threat && d.groups{i}.isDestroyed
            
            if ~d.groups{i}.isDestroyed && d.groups{i}.trajectory_data.time(end)<=d.end_time
                last_plot_point = length(d.groups{i}.trajectory_data.time);
            elseif ~d.groups{i}.isDestroyed && d.groups{i}.trajectory_data.time(end)>d.end_time
                [~,last_plot_point] = min((d.groups{i}.trajectory_data.time-d.end_time).^2);
            else
                last_plot_point = find(d.groups{i}.trajectory_data.time >= int_agent.intercept_time,1,'first')-1;
            end
            interceptor_handles(k) = plot3(d.groups{i}.trajectory_data.LLA(1:last_plot_point,2),...
                d.groups{i}.trajectory_data.LLA(1:last_plot_point,1),...
                d.groups{i}.trajectory_data.LLA(1:last_plot_point,3)/1000,'c');
            interceptor_names{k} = sprintf('Interceptor %i',k);
            
            % Mark intercept points
            if int_agent.missed_threat < 0
                plot3([d.groups{i}.trajectory_data.LLA(last_plot_point,2) d.groups{i}.trajectory_data.LLA(last_plot_point-3,2)],...
                      [d.groups{i}.trajectory_data.LLA(last_plot_point,1) d.groups{i}.trajectory_data.LLA(last_plot_point-3,1)],...
                      [d.groups{i}.trajectory_data.LLA(last_plot_point,3)/1000 d.groups{i}.trajectory_data.LLA(last_plot_point-3,3)/1000],'y','LineWidth',3);
            else
                plot3([d.groups{i}.trajectory_data.LLA(last_plot_point,2) d.groups{i}.trajectory_data.LLA(last_plot_point-3,2)],...
                      [d.groups{i}.trajectory_data.LLA(last_plot_point,1) d.groups{i}.trajectory_data.LLA(last_plot_point-3,1)],...
                      [d.groups{i}.trajectory_data.LLA(last_plot_point,3)/1000 d.groups{i}.trajectory_data.LLA(last_plot_point-3,3)/1000],'k','LineWidth',3);
            end
            
            % To dynamically assign axes
            max_x = max([d.groups{i}.trajectory_data.LLA(:,2);max_x]);
            max_y = max([d.groups{i}.trajectory_data.LLA(:,1);max_y]);
            min_x = min([min_x;d.groups{i}.trajectory_data.LLA(:,2)]);
            min_y = min([min_y;d.groups{i}.trajectory_data.LLA(:,1)]);
        end
    elseif (isa(d.groups{i},'artemis.platforms.Stage'))
        stage_rECEF=platform_data.data{i}.state(:,1:3);
        
        stage_LLA=d.world.convert_ecef2lla(stage_rECEF);
        
        l = l+1;
%         stage_handles(l) = plot3(stage_LLA(:,2),...
%             stage_LLA(:,1),...
%             stage_LLA(:,3)/1000,'m'); %'MarkerSize',plot_size);
        stage_names{l} = sprintf('Stage %i',l);
    end
end
map_buffer = 10;

earth_map(ax,[((min_y) - map_buffer) ((min_x) - map_buffer) ((max_y) + map_buffer) ((max_x) + map_buffer)]);
zLims = get(ax,'ZLim');set(ax,'ZLim',[0,zLims(2)]);view(-17,58);
xlabel('Latitude (deg)'); ylabel('Longitude (deg)'); zlabel('Altitude (km)');
grid on

hold off

hold on
loc_handles = [];
names = {};
j = 0;

for i = 1:length(d.agents)
    if(any(strcmp(superclasses(d.agents{i}),'artemis.Sensor')))
        if(d.implements(d.agents{i},'ABS') || ...
                isa(d.agents{i},'artemis.PhasedArray_Radar'))
            j = j+1;
            location=d.agents{i}.getLocation();
            loc_handles(j) = plot3(location(2),location(1),...
                location(3)/1000,'o','LineWidth',2);
            names{j} = d.agents{i}.getKey;
            hold all
        end
    elseif d.implements(d.agents{i},'BAT')
        j = j+1;
        location=d.agents{i}.getLocation();
        loc_handles(j) = plot3(location(2),location(1),...
            location(3)/1000,'x','LineWidth',2);
        names{j} = d.agents{i}.getKey;
        hold all
    end
end

zLims = get(ax,'ZLim');set(ax,'ZLim',[0,zLims(2)]);view(-17,58);
xlabel(ax,'Longitude (deg)')
ylabel(ax,'Latitude (deg)')
zlabel(ax,'Altitude (km)')
% if(~isempty(loc_handles))
%     legend([loc_handles missile_handles],[names missile_names],'Location',[.7 .7 .3 .2],'Interpreter','none')
% end
drawnow
end